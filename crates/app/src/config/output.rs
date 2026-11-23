//! The `[[mixer.output]]` tables: who is allowed to hear a bus, and on which device.
//!
//! The terminal guide and the settings screen used to carry their own copies of this parsing and
//! writing code; the Flutter shell needs the same answers. Keeping it here means one edit path for
//! every front-end: the file's comments and key order survive (`toml_edit`), a built-in profile is
//! read-only, and a role is always spelled the same way in the mixer file (`cue`, not `precue`).

use std::collections::BTreeSet;
use std::fs;
use std::path::Path;

use protocol::OutputRole;
use toml_edit::{Array, DocumentMut, Item, Table};

use super::profile;

/// One destination, addressed by its position in the file's `[[mixer.output]]` array.
#[derive(Clone, Debug, PartialEq)]
pub struct OutputEntry {
    /// Position in the array, which is how it is addressed when writing.
    pub index: usize,
    pub name: String,
    pub role: OutputRole,
    /// A device name substring or index; `None` means the host default.
    pub device: Option<String>,
    /// `(left, right)` device channels; `None` when the file left it to the default.
    pub channels: Option<(u16, u16)>,
    pub gain: f32,
}

impl OutputEntry {
    /// The mixer file's spelling of the role (`master` / `cue`).
    pub fn role_name(&self) -> &'static str {
        self.role.name()
    }

    /// The same `role:name` label the guide's status line and tests use.
    pub fn label(&self) -> String {
        format!("{}:{}", self.role.name(), self.name)
    }
}

/// Reads every destination from a profile source (built-in marker or a file path).
pub fn read(source: &str) -> Result<Vec<OutputEntry>, String> {
    let text = profile::read_profile_text(source)?;
    read_text(&text)
}

/// Reads every destination from profile text that is already in memory.
pub fn read_text(text: &str) -> Result<Vec<OutputEntry>, String> {
    let doc = text
        .parse::<DocumentMut>()
        .map_err(|err| format!("profile: {err}"))?;
    Ok(entries_of(&doc))
}

/// A `role:name` label for each destination, for status lines.
pub fn labels(entries: &[OutputEntry]) -> Vec<String> {
    entries.iter().map(OutputEntry::label).collect()
}

/// The conventional next free stereo pair, used when a front-end adds a destination without
/// asking for a device: `(0,1)`, `(2,3)`, `(4,5)`, ...
pub fn next_channels(entries: &[OutputEntry]) -> (u16, u16) {
    let mut used = BTreeSet::new();
    for (left, right) in entries.iter().map(|entry| entry.channels.unwrap_or((0, 1))) {
        used.insert(left);
        used.insert(right);
    }
    let mut left = 0u16;
    loop {
        let right = left.saturating_add(1);
        if !used.contains(&left) && !used.contains(&right) {
            return (left, right);
        }
        left = left.saturating_add(2);
        if left >= u16::MAX - 1 {
            return (0, 1);
        }
    }
}

/// Appends a destination. The caller supplies the name because the terminal guide and the Flutter
/// menu name the same role differently (`main`/`phones` vs `Master 1`/`Precue 1`).
pub fn add(
    source: &str,
    name: &str,
    role: OutputRole,
    device: Option<&str>,
    channels: Option<(u16, u16)>,
) -> Result<OutputEntry, String> {
    require_writable(source)?;
    let mut doc = read_doc(source)?;
    let tables = profile::output_tables_mut(&mut doc).map_err(|err| format!("{source}: {err}"))?;

    let mut table = Table::new();
    // A blank line before each `[[mixer.output]]` is what the shipped template does; keeping the
    // same shape stops a hand-written file from turning into a wall of adjacent tables.
    let mut decor = toml_edit::Decor::default();
    decor.set_prefix("\n");
    table.decor_mut().clone_from(&decor);
    table.insert("name", Item::Value(name.trim().into()));
    table.insert("role", Item::Value(role.name().into()));
    if let Some(device) = device.map(str::trim).filter(|device| !device.is_empty()) {
        table.insert("device", Item::Value(device.into()));
    }
    if let Some((left, right)) = channels {
        table.insert(
            "channels",
            Item::Value(toml_edit::Value::Array(pair(left, right))),
        );
    }
    tables.push(table);
    let index = tables.len() - 1;

    write_doc(source, &doc)?;
    Ok(OutputEntry {
        index,
        name: name.trim().to_owned(),
        role,
        device: device
            .map(str::trim)
            .filter(|device| !device.is_empty())
            .map(str::to_owned),
        channels,
        gain: 1.0,
    })
}

/// Drops the destination at `index`, leaving the rest of the file exactly as it was written.
pub fn remove(source: &str, index: usize) -> Result<(), String> {
    require_writable(source)?;
    let mut doc = read_doc(source)?;
    let tables = profile::output_tables_mut(&mut doc).map_err(|err| format!("{source}: {err}"))?;
    if index >= tables.len() {
        return Err(format!("{source}: no [[mixer.output]] #{index}"));
    }
    tables.remove(index);
    write_doc(source, &doc)
}

/// Writes a device and/or channel pair into one destination. `None` means "keep what the file has";
/// the operation is addressed by the file position, not the name, so duplicate names are fine.
pub fn bind(
    source: &str,
    index: usize,
    device: Option<&str>,
    channels: Option<(u16, u16)>,
) -> Result<(), String> {
    require_writable(source)?;
    let mut doc = read_doc(source)?;
    let tables = profile::output_tables_mut(&mut doc).map_err(|err| format!("{source}: {err}"))?;
    let table = tables
        .get_mut(index)
        .ok_or_else(|| format!("{source}: no [[mixer.output]] #{index}"))?;
    if let Some(device) = device.map(str::trim).filter(|device| !device.is_empty()) {
        set_str(table, "device", device);
    }
    if let Some((left, right)) = channels {
        set_array(table, "channels", pair(left, right));
    }
    write_doc(source, &doc)
}

fn entries_of(doc: &DocumentMut) -> Vec<OutputEntry> {
    let Some(tables) = profile::output_tables(doc) else {
        return Vec::new();
    };
    tables
        .iter()
        .enumerate()
        .map(|(index, table)| OutputEntry {
            index,
            name: table
                .get("name")
                .and_then(Item::as_str)
                .unwrap_or("output")
                .to_owned(),
            role: match table.get("role").and_then(Item::as_str) {
                Some("cue") => OutputRole::Cue,
                _ => OutputRole::Master,
            },
            device: table
                .get("device")
                .and_then(Item::as_str)
                .map(str::to_owned),
            channels: channels_of(table),
            gain: table
                .get("gain")
                .and_then(Item::as_float)
                .map(|gain| gain as f32)
                .unwrap_or(1.0),
        })
        .collect()
}

fn channels_of(table: &Table) -> Option<(u16, u16)> {
    let array = table.get("channels")?.as_array()?;
    if array.len() != 2 {
        return None;
    }
    Some((
        u16::try_from(array.get(0)?.as_integer()?).ok()?,
        u16::try_from(array.get(1)?.as_integer()?).ok()?,
    ))
}

fn pair(left: u16, right: u16) -> Array {
    let mut array = Array::new();
    array.push(i64::from(left));
    array.push(i64::from(right));
    array
}

fn read_doc(source: &str) -> Result<DocumentMut, String> {
    let text = profile::read_profile_text(source)?;
    text.parse::<DocumentMut>()
        .map_err(|err| format!("{source}: {err}"))
}

fn write_doc(source: &str, doc: &DocumentMut) -> Result<(), String> {
    if profile::is_builtin(source) {
        return Err("the built-in template is read-only".to_owned());
    }
    fs::write(Path::new(source), doc.to_string()).map_err(|err| format!("{source}: {err}"))
}

fn require_writable(source: &str) -> Result<(), String> {
    if profile::is_builtin(source) {
        return Err("the built-in template is read-only".to_owned());
    }
    Ok(())
}

/// Sets a string key, keeping the decor (comments, spacing) around the value.
fn set_str(table: &mut Table, key: &str, value: &str) {
    match table.get_mut(key) {
        Some(Item::Value(existing)) => {
            let decor = existing.decor().clone();
            *existing = value.into();
            *existing.decor_mut() = decor;
        }
        _ => {
            table.insert(key, Item::Value(value.into()));
        }
    }
}

/// Sets an array key, keeping the decor around the value.
fn set_array(table: &mut Table, key: &str, array: Array) {
    match table.get_mut(key) {
        Some(Item::Value(existing)) => {
            let decor = existing.decor().clone();
            *existing = toml_edit::Value::Array(array);
            *existing.decor_mut() = decor;
        }
        _ => {
            table.insert(key, Item::Value(toml_edit::Value::Array(array)));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp(name: &str) -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "pipefader-output-{}-{}-{}",
            std::process::id(),
            name,
            library::library::db::unix_now()
        ));
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn rig(dir: &Path) -> String {
        let path = dir.join("config.toml");
        fs::write(
            &path,
            concat!(
                "# my rig\n",
                "[mixer]\n",
                "[[mixer.output]]\n",
                "name = \"main\"\n",
                "role = \"master\"\n",
                "channels = [0, 1]\n\n",
                "[[mixer.output]]\n",
                "name = \"phones\"\n",
                "role = \"cue\"\n",
                "channels = [2, 3]\n",
            ),
        )
        .unwrap();
        path.display().to_string()
    }

    #[test]
    fn reads_roles_channels_and_comments_survive_writes() {
        let dir = temp("read");
        let path = rig(&dir);
        let entries = read(&path).unwrap();
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].role, OutputRole::Master);
        assert_eq!(entries[0].channels, Some((0, 1)));
        assert_eq!(entries[1].role, OutputRole::Cue);
        assert_eq!(entries[1].label(), "cue:phones");

        bind(&path, 0, Some("USB Interface"), Some((4, 5))).unwrap();
        let written = fs::read_to_string(&path).unwrap();
        assert!(written.contains("# my rig"), "{written}");
        assert!(written.contains("device = \"USB Interface\""), "{written}");
        assert!(written.contains("channels = [4, 5]"), "{written}");
        assert!(written.contains("channels = [2, 3]"), "second entry intact");
    }

    #[test]
    fn add_appends_for_the_requested_role_and_remove_drops_it() {
        let dir = temp("add");
        let path = rig(&dir);
        let entry = add(&path, "Master 2", OutputRole::Master, None, Some((4, 5))).unwrap();
        assert_eq!(entry.index, 2);
        let entries = read(&path).unwrap();
        assert_eq!(entries.len(), 3);
        assert_eq!(labels(&entries)[2], "master:Master 2");
        assert_eq!(next_channels(&entries), (6, 7));

        remove(&path, 2).unwrap();
        assert_eq!(read(&path).unwrap().len(), 2);
    }

    #[test]
    fn the_builtin_profile_is_read_only() {
        let entries = read(profile::BUILTIN_PROFILE).unwrap();
        assert!(!entries.is_empty());
        let err = remove(profile::BUILTIN_PROFILE, 0).unwrap_err();
        assert!(err.contains("read-only"), "{err}");
    }
}

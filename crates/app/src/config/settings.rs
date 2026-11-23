//! The machine-wide settings the menu exposes, read and written without the engine.
//!
//! The Flutter settings page and the terminal screens need the same values and the same
//! comment-preserving writes, so the mapping from "a row in a menu" to "a key in the profile" lives
//! here. The audio rate is the one value that still needs a restart; everything else is part of the
//! mixer topology and can be reloaded while the engine runs.

use std::fs;
use std::path::Path;

use audio::CrossfaderCurve;
use toml_edit::{DocumentMut, Item, Table};

use super::profile;

/// One row of the menu's settings page, already decoded.
#[derive(Clone, Debug, PartialEq)]
pub struct SettingsSnapshot {
    /// The profile source these values came from (a file path or the built-in marker).
    pub source: String,
    /// A built-in profile is readable but not writable.
    pub builtin: bool,
    pub sample_rate: u32,
    /// `classic`, `constant_power` or `cut`.
    pub crossfader_curve: String,
    /// `-1.0` cue only, `0.0` both, `1.0` master only.
    pub cue_blend: f32,
    pub autogain: bool,
}

impl SettingsSnapshot {
    /// Whether changing this key needs a restart. The menu uses it to mark the row, not to hide it.
    pub fn needs_restart(key: &str) -> bool {
        matches!(key, "sample_rate")
    }
}

/// Reads the settings from a profile source. A built-in source is decoded from the embedded text.
pub fn read(source: &str) -> Result<SettingsSnapshot, String> {
    let config = profile::load_source(source)?;
    Ok(SettingsSnapshot {
        source: source.to_owned(),
        builtin: profile::is_builtin(source),
        sample_rate: config.live.audio.sample_rate,
        crossfader_curve: curve_name(config.mixer.crossfader.curve).to_owned(),
        cue_blend: config.mixer.cue.blend,
        autogain: config.mixer.autogain.enabled,
    })
}

/// Writes one setting and returns the re-read snapshot.
///
/// Keys are deliberately the menu's names, not TOML paths: `sample_rate`, `crossfader_curve`,
/// `cue_blend`, `autogain`. Unknown keys are rejected so a typo cannot silently do nothing.
pub fn set(source: &str, key: &str, value: &str) -> Result<SettingsSnapshot, String> {
    if profile::is_builtin(source) {
        return Err("the built-in profile is read-only".to_owned());
    }
    let text = fs::read_to_string(Path::new(source)).map_err(|err| format!("{source}: {err}"))?;
    let mut doc: DocumentMut = text.parse().map_err(|err| format!("{source}: {err}"))?;

    match key {
        "sample_rate" => {
            let rate: u32 = value
                .trim()
                .parse()
                .map_err(|_| format!("sample_rate: `{value}` is not a number"))?;
            if !(8_000..=384_000).contains(&rate) {
                return Err(format!("sample_rate: {rate} is outside 8000..=384000"));
            }
            let table = table_mut(&mut doc, "live", Some("audio"))?;
            set_int(table, "sample_rate", i64::from(rate));
        }
        "crossfader_curve" => {
            let curve = match value.trim() {
                "classic" => CrossfaderCurve::Classic,
                "constant_power" | "constant-power" => CrossfaderCurve::ConstantPower,
                "cut" => CrossfaderCurve::Cut,
                other => {
                    return Err(format!(
                        "crossfader_curve: `{other}` is not classic | constant_power | cut"
                    ))
                }
            };
            let table = table_mut(&mut doc, "mixer", Some("crossfader"))?;
            set_str(table, "curve", curve_name(curve));
        }
        "cue_blend" => {
            let blend = match value.trim() {
                "cue" => -1.0,
                "both" => 0.0,
                "master" => 1.0,
                other => other
                    .parse::<f32>()
                    .map_err(|_| format!("cue_blend: `{value}` is not cue | both | master"))?,
            };
            if !(-1.0..=1.0).contains(&blend) {
                return Err(format!("cue_blend: {blend} is outside -1..=1"));
            }
            let table = table_mut(&mut doc, "mixer", Some("fader"))?;
            set_float(table, "cue_blend", f64::from(blend));
        }
        "autogain" => {
            let on = match value.trim() {
                "on" | "true" | "1" => true,
                "off" | "false" | "0" => false,
                other => return Err(format!("autogain: `{other}` is not on | off")),
            };
            let table = table_mut(&mut doc, "mixer", Some("autogain"))?;
            set_bool(table, "enabled", on);
        }
        other => return Err(format!("unknown setting `{other}`")),
    }

    fs::write(Path::new(source), doc.to_string()).map_err(|err| format!("{source}: {err}"))?;
    read(source)
}

/// The file spelling of a crossfader curve (`serde`'s `snake_case`).
pub fn curve_name(curve: CrossfaderCurve) -> &'static str {
    match curve {
        CrossfaderCurve::Classic => "classic",
        CrossfaderCurve::ConstantPower => "constant_power",
        CrossfaderCurve::Cut => "cut",
    }
}

fn table_mut<'a>(
    doc: &'a mut DocumentMut,
    outer: &str,
    inner: Option<&str>,
) -> Result<&'a mut Table, String> {
    if !doc.contains_key(outer) {
        doc.insert(outer, Item::Table(Table::new()));
    }
    let table = doc
        .get_mut(outer)
        .and_then(Item::as_table_mut)
        .ok_or_else(|| format!("`{outer}` must be a table"))?;
    let Some(inner) = inner else {
        return Ok(table);
    };
    if !table.contains_key(inner) {
        table.insert(inner, Item::Table(Table::new()));
    }
    table
        .get_mut(inner)
        .and_then(Item::as_table_mut)
        .ok_or_else(|| format!("`{outer}.{inner}` must be a table"))
}

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

fn set_int(table: &mut Table, key: &str, value: i64) {
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

fn set_float(table: &mut Table, key: &str, value: f64) {
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

fn set_bool(table: &mut Table, key: &str, value: bool) {
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

#[cfg(test)]
mod tests {
    use super::*;

    fn temp(name: &str) -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "pipefader-settings-{}-{}-{}",
            std::process::id(),
            name,
            library::library::db::unix_now()
        ));
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn profile_at(dir: &Path) -> String {
        let path = dir.join("config.toml");
        fs::write(
            &path,
            concat!(
                "# comments stay\n",
                "[mixer]\n",
                "[live]\n",
                "[preference]\n",
            ),
        )
        .unwrap();
        path.display().to_string()
    }

    #[test]
    fn reads_the_defaults_and_writes_each_key_without_losing_comments() {
        let dir = temp("write");
        let path = profile_at(&dir);
        let initial = read(&path).unwrap();
        assert_eq!(initial.sample_rate, 44_100);
        assert_eq!(initial.crossfader_curve, "classic");
        assert!(!initial.autogain);

        set(&path, "sample_rate", "48000").unwrap();
        set(&path, "crossfader_curve", "constant_power").unwrap();
        set(&path, "cue_blend", "both").unwrap();
        set(&path, "autogain", "on").unwrap();

        let after = read(&path).unwrap();
        assert_eq!(after.sample_rate, 48_000);
        assert_eq!(after.crossfader_curve, "constant_power");
        assert_eq!(after.cue_blend, 0.0);
        assert!(after.autogain);
        let written = fs::read_to_string(&path).unwrap();
        assert!(written.contains("# comments stay"), "{written}");
        assert!(written.contains("[mixer.crossfader]"), "{written}");
        assert!(written.contains("cue_blend = 0.0"), "{written}");
    }

    #[test]
    fn rejects_bad_values_and_the_builtin_source() {
        let dir = temp("bad");
        let path = profile_at(&dir);
        assert!(set(&path, "sample_rate", "nope").is_err());
        assert!(set(&path, "crossfader_curve", "bouncy").is_err());
        assert!(set(&path, "cue_blend", "2").is_err());
        assert!(set(&path, "autogain", "maybe").is_err());
        assert!(set(&path, "unknown", "1").is_err());
        assert!(set(profile::BUILTIN_PROFILE, "autogain", "on").is_err());
    }
}

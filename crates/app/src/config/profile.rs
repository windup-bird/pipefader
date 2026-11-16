//! The one configuration file: where it lives, how it is created, and how its sections are read.
//!
//! A config is a single TOML file with `[mixer]`, `[live]`, `[preference]` and `[controller]`
//! sections. `--profile <file>` reads exactly that file; without it the platform default is used, and
//! on the first start the shipped template is copied there. An existing file is never overwritten,
//! and a read-only config directory does not stop the engine: the built-in template runs instead.
//!
//! All file IO stays in this front-end crate — the audio engine only ever reads text. In particular
//! the template is the single source of truth for the first-start copy and the
//! engine's built-in topology (`reference_toml()` embeds the same bytes).
//!
//! `[controller].map` is a **file pointer** to a unit map, resolved relative to this config's
//! folder. Leaving it out means no controller input, which is the shipped state.

use std::fs;
use std::path::{Path, PathBuf};

use audio::{reference_toml, MixerConfig};
use controller::map::DeckRoutes;
use protocol::{Backend, LiveConfig};
use toml_edit::{DocumentMut, Item, Table};

/// The shipped template. The first-start copy writes it verbatim.
pub fn template() -> &'static str {
    reference_toml()
}

/// The shipped unit-map template (`crates/controller/mapping.toml`), embedded so `--guide` has a map
/// to edit on a machine with no checkout. It is written only when the guide opens a map that does
/// not exist yet, never at startup — the first start still creates exactly one file, the config.
pub const MAP_TEMPLATE: &str = include_str!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../controller/mapping.toml"
));

/// Reserved source ids for the built-in template of each kind. They are never real files; every
/// reader resolves them to the embedded text. `map_path_for(BUILTIN_PROFILE)` deliberately yields
/// `BUILTIN_MAP`, so a session started on the built-in config defaults to the built-in map too.
pub const BUILTIN_PROFILE: &str = "<built-in>/config.toml";
pub const BUILTIN_MAP: &str = "<built-in>/mapping.toml";

/// True when `source` names the compiled-in template rather than a file on disk.
pub fn is_builtin(source: &str) -> bool {
    source == BUILTIN_PROFILE || source == BUILTIN_MAP
}

/// A short label for a source, used in the settings screen and command reports.
pub fn source_label(source: &str) -> String {
    if is_builtin(source) {
        "built-in".to_owned()
    } else {
        source.to_owned()
    }
}

/// The text of a profile-shaped source: the embedded template for built-in, else the file.
pub fn read_profile_text(source: &str) -> Result<String, String> {
    if source == BUILTIN_PROFILE {
        Ok(template().to_owned())
    } else if is_builtin(source) {
        Err(format!("{source}: not a config source"))
    } else {
        std::fs::read_to_string(source).map_err(|err| format!("{source}: {err}"))
    }
}

/// The text and include base of a controller-map source.
pub fn read_map_text(source: &str) -> Result<(String, PathBuf), String> {
    if source == BUILTIN_MAP {
        // Presets the map names are embedded in the controller crate; a "." base is enough.
        Ok((MAP_TEMPLATE.to_owned(), PathBuf::from(".")))
    } else if is_builtin(source) {
        Err(format!("{source}: not a controller-map source"))
    } else {
        let text = std::fs::read_to_string(source).map_err(|err| format!("{source}: {err}"))?;
        let base = Path::new(source)
            .parent()
            .filter(|parent| !parent.as_os_str().is_empty())
            .unwrap_or_else(|| Path::new("."))
            .to_path_buf();
        Ok((text, base))
    }
}

/// The `[controller]` section: a pointer to one unit-map file, plus an optional port override.
/// Parsed by hand because this crate does not depend on serde; two keys do not warrant one.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct ControllerSection {
    id: Option<String>,
    map: Option<String>,
    device: Option<String>,
}

/// One controller instance. `id` is the label a `[[multideck.deck]] source` refers to; `map` is
/// already resolved to a usable path. `[[controller]]` may declare any number of these.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Controller {
    pub id: String,
    pub map: Option<String>,
    pub device: Option<String>,
}

impl Default for Controller {
    fn default() -> Self {
        Self {
            id: "default".to_owned(),
            map: None,
            device: None,
        }
    }
}

/// One controller ready to attach: its resolved port, unit map and its own slice of the face →
/// deck table. Both front-ends attach these as separate MIDI sessions.
#[derive(Clone, Debug)]
pub struct ControllerSession {
    pub id: String,
    pub port: Option<String>,
    pub map: String,
    pub routes: DeckRoutes,
}

/// The `[preference.analysis]` section: which backend runs which analysis path, and whether a
/// browser load analyses a track that has no imported/cached grid yet.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct AnalysisBackends {
    pub beats: Backend,
    pub key: Backend,
    /// Run the analyser after a browser load when neither the imported library nor the analysis
    /// cache has a grid. Off by default: analysis takes seconds and should be an explicit choice.
    pub auto_analyse: bool,
}

fn analysis_section(value: &toml::Value) -> Result<AnalysisBackends, String> {
    let table = value
        .as_table()
        .ok_or_else(|| "must be a table".to_owned())?;
    let mut section = AnalysisBackends::default();
    for (key, value) in table {
        match key.as_str() {
            "beats" | "key" => {
                let text = value
                    .as_str()
                    .ok_or_else(|| format!("`{key}` must be a string"))?
                    .trim()
                    .to_owned();
                let backend = Backend::parse(&text).ok_or_else(|| {
                    format!("`{key} = \"{text}\"` is not a backend (stratum | timestretch)")
                })?;
                if key == "beats" {
                    section.beats = backend;
                } else {
                    section.key = backend;
                }
            }
            "auto_analyse" => match value.as_bool() {
                Some(auto) => section.auto_analyse = auto,
                None => return Err(format!("`{key}` must be true | false")),
            },
            other => {
                return Err(format!(
                    "unknown key `{other}` (beats | key | auto_analyse)"
                ))
            }
        }
    }
    Ok(section)
}

/// One parsed config, and the path it came from.
#[derive(Debug)]
pub struct Config {
    pub path: PathBuf,
    pub mixer: MixerConfig,
    pub live: LiveConfig,
    /// The first (or only) controller, kept for the front-ends' single-input paths.
    pub controller: Controller,
    /// Every declared controller. `[[controller]]` instances each own a port, a unit map and their
    /// own slice of the face → deck table.
    pub controllers: Vec<Controller>,
    /// Which backend runs the beat and the key analysis path.
    pub analysis: AnalysisBackends,
    /// Notes worth showing at startup (a first-start copy, clamped live values, ...).
    pub notes: Vec<String>,
}

/// Builds the controller-face → physical-deck table from `[[multideck.deck]] source`.
///
/// `source` is `<controller-id>.<face>[.mirror]` (an `Am` spelling also means the mirror). Passing
/// a `controller` id keeps only that controller's sources, so each `[[controller]]` instance gets
/// its own table and two devices cannot address the same deck unless their sources say so.
pub fn deck_routes(mixer: &MixerConfig, controller: Option<&str>) -> DeckRoutes {
    let mut routes = DeckRoutes::default();
    let mut faces: std::collections::HashMap<String, (Option<u8>, Option<u8>)> =
        std::collections::HashMap::new();
    for (index, channel) in mixer.channels.iter().enumerate() {
        let Some(source) = channel.source.as_deref() else {
            continue;
        };
        let Some((owner, face, mirror)) = parse_source(source) else {
            continue;
        };
        if let Some(want) = controller {
            if owner.as_deref().is_some_and(|owner| owner != want) {
                continue;
            }
        }
        let entry = faces.entry(face).or_insert((None, None));
        if mirror {
            entry.1 = Some(index as u8);
        } else {
            entry.0 = Some(index as u8);
        }
    }
    for (face, (normal, mirror)) in faces {
        if let Some(normal) = normal {
            routes.insert(&face, normal, mirror);
        }
    }
    routes
}

/// `<controller>.<face>[.mirror]` — an `Am` spelling also means the mirror variant. The owner is
/// optional so a bare `A` still works on a single-controller rig.
fn parse_source(source: &str) -> Option<(Option<String>, String, bool)> {
    let mut parts: Vec<&str> = source.split('.').filter(|part| !part.is_empty()).collect();
    let explicit = parts.last() == Some(&"mirror");
    if explicit {
        parts.pop();
    }
    let face = parts.pop()?;
    let owner = (!parts.is_empty()).then(|| parts.join("."));
    let (face, mirror) = if let Some(base) = face.strip_suffix('m') {
        (!base.is_empty()).then(|| (base.to_owned(), true))?
    } else {
        (face.to_owned(), explicit)
    };
    Some((owner, face, mirror))
}

/// The platform's config path. `PIPEFADER_CONFIG` wins when set, which is also how a test or a
/// Termux/proot session names its own location.
pub fn default_path() -> Option<PathBuf> {
    // An empty value means "not set" — joining onto it would put the config in the working
    // directory instead of the user's config directory.
    if let Some(path) = std::env::var_os("PIPEFADER_CONFIG").filter(|v| !v.is_empty()) {
        return Some(PathBuf::from(path));
    }
    let dir = if cfg!(windows) {
        std::env::var_os("APPDATA")
            .filter(|v| !v.is_empty())
            .map(|base| PathBuf::from(base).join("Pipefader"))
    } else {
        std::env::var_os("XDG_CONFIG_HOME")
            .filter(|v| !v.is_empty())
            .map(PathBuf::from)
            .or_else(|| {
                std::env::var_os("HOME")
                    .filter(|v| !v.is_empty())
                    .map(|home| PathBuf::from(home).join(".config"))
            })
            .map(|base| base.join("pipefader"))
    }?;
    Some(dir.join("config.toml"))
}

/// Loads `explicit`, or the platform default. Nothing is ever written here: an explicit path must
/// exist (a typo is an error), and when no user config exists the session runs on the built-in
/// template in memory rather than copying a file into the user's directory.
pub fn load_or_create(explicit: Option<&str>) -> Result<Config, String> {
    if let Some(path) = explicit {
        return load_user(PathBuf::from(path));
    }
    match default_path() {
        Some(path) if path.is_file() => load_user(path),
        // Missing (or no platform directory at all) → built-in, entirely in memory.
        _ => load_builtin(),
    }
}

/// Reads a user config; a missing or unreadable file is an error, never a silent fallback.
fn load_user(path: PathBuf) -> Result<Config, String> {
    let text = std::fs::read_to_string(&path).map_err(|err| format!("{}: {err}", path.display()))?;
    parse(&path, &text, Vec::new())
}

/// Parses the compiled-in config as a source in its own right. Its `path` is the built-in marker so
/// every downstream reader resolves it back to the embedded text instead of a file.
fn load_builtin() -> Result<Config, String> {
    let notes = vec!["no user config found; running on the built-in template".to_owned()];
    parse(Path::new(BUILTIN_PROFILE), template(), notes)
}

/// Loads a profile from an arbitrary source id: the built-in marker or a user file path. Unlike
/// `load_or_create` this never picks a default or creates anything; it is what a runtime source
/// switch uses to re-read every section from the source just chosen.
pub fn load_source(source: &str) -> Result<Config, String> {
    if source == BUILTIN_PROFILE {
        parse(Path::new(BUILTIN_PROFILE), template(), Vec::new())
    } else if is_builtin(source) {
        Err(format!("{source}: not a profile source"))
    } else {
        load_user(PathBuf::from(source))
    }
}

/// Builds one attachable session per `[[controller]]` of `config`. `map_device` resolves the device
/// named in `[meta].device` of a map (a closure so this crate does not depend on how the front-end
/// parses a map). Ports declared on the controller entry win; the named map device is the fallback.
pub fn sessions_from(
    config: &Config,
    map_device: impl Fn(&str) -> Option<String>,
) -> Vec<ControllerSession> {
    let map_path = config
        .controller
        .map
        .clone()
        .unwrap_or_else(|| map_path_for(&config.path));
    config
        .controllers
        .iter()
        .map(|entry| {
            let map = entry.map.clone().unwrap_or_else(|| map_path.clone());
            let port = entry
                .device
                .clone()
                .or_else(|| entry.map.as_ref().and_then(|_| map_device(&map)));
            ControllerSession {
                routes: deck_routes(&config.mixer, Some(&entry.id)),
                id: entry.id.clone(),
                port,
                map,
            }
        })
        .collect()
}

/// Writes the controller choice into the config the session runs on.
///
/// This is the missing half of the F9 controller picker: the screen used to reconnect the port
/// without recording it, so the next start forgot it. `port` and `map` are optional so the two
/// entry points (pick a port, then pick a map) can each write only what they know.
///
/// The write keeps the file's comments and key order (`toml_edit`), updates the first
/// `[[controller]]` entry or the single `[controller]` table, and creates `[controller]` when the
/// file has none. A missing `id` is filled from the `[[multideck.deck]] source` owner: without it
/// the next start parses the entry as `default`, `deck_routes` filters the `ctl1` sources out, and
/// the controller is connected but drives nothing.
pub fn write_controller(
    config: &Path,
    port: Option<&str>,
    map: Option<&Path>,
) -> Result<(), String> {
    if port.is_none() && map.is_none() {
        return Ok(());
    }
    let text = fs::read_to_string(config).map_err(|err| format!("{}: {err}", config.display()))?;
    let mut doc: DocumentMut = text
        .parse()
        .map_err(|err| format!("{}: {err}", config.display()))?;
    let derived_id = existing_controller_id(&doc).or_else(|| controller_owner(&doc));
    let map_text = map.map(|map| config_relative(config, map));

    let table = controller_table(&mut doc)?;
    if table.get("id").is_none() {
        if let Some(id) = derived_id {
            set_str(table, "id", &id);
        }
    }
    if let Some(port) = port.map(str::trim).filter(|port| !port.is_empty()) {
        set_str(table, "device", port);
    }
    if let Some(map) = map_text.as_deref() {
        set_str(table, "map", map);
    }
    write_document(config, &doc)
}

/// The first controller table in the document: an existing `[controller]`, the first
/// `[[controller]]`, or a freshly inserted `[controller]`.
fn controller_table(doc: &mut DocumentMut) -> Result<&mut Table, String> {
    if !doc.contains_key("controller") {
        doc.insert("controller", Item::Table(Table::new()));
    }
    match doc.get_mut("controller") {
        Some(Item::Table(table)) => Ok(table),
        Some(Item::ArrayOfTables(entries)) => {
            if entries.is_empty() {
                entries.push(Table::new());
            }
            entries
                .iter_mut()
                .next()
                .ok_or_else(|| "`[[controller]]` could not be created".to_owned())
        }
        Some(_) => Err("`controller` must be a table or an array of tables".to_owned()),
        None => Err("`[controller]` could not be created".to_owned()),
    }
}

/// The id already written on the first controller entry, if any.
fn existing_controller_id(doc: &DocumentMut) -> Option<String> {
    match doc.get("controller")? {
        Item::Table(table) => table
            .get("id")
            .and_then(|item| item.as_str())
            .map(str::to_owned),
        Item::ArrayOfTables(entries) => entries
            .iter()
            .next()?
            .get("id")
            .and_then(|item| item.as_str())
            .map(str::to_owned),
        _ => None,
    }
}

/// The single controller id the `[[multideck.deck]] source` rows name: `ctl1.A` → `ctl1`.
///
/// Only a single owner is unambiguous; with several, the caller keeps whichever id the entry
/// already had. A bare `A` source (no owner) names none.
fn controller_owner(doc: &DocumentMut) -> Option<String> {
    let entries = doc
        .get("multideck")?
        .as_table()?
        .get("deck")?
        .as_array_of_tables()?;
    let mut owners = std::collections::BTreeSet::new();
    for entry in entries.iter() {
        let Some(source) = entry.get("source").and_then(|item| item.as_str()) else {
            continue;
        };
        let owner = source.split('.').next().unwrap_or_default().trim();
        if !owner.is_empty() {
            owners.insert(owner.to_owned());
        }
    }
    (owners.len() == 1)
        .then(|| owners.into_iter().next())
        .flatten()
}

/// A path written inside the config: a file next to it becomes relative, anything else stays
/// absolute (canonicalised so `..` and symlinked temp dirs do not leak into the file).
fn config_relative(config: &Path, path: &Path) -> String {
    let dir = config
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    let (Ok(dir), Ok(path)) = (dir.canonicalize(), path.canonicalize()) else {
        return path.to_string_lossy().into_owned();
    };
    match path.strip_prefix(&dir) {
        Ok(relative) if !relative.as_os_str().is_empty() => {
            relative.to_string_lossy().replace('\\', "/")
        }
        _ => path.to_string_lossy().into_owned(),
    }
}

/// Sets a string key, keeping the decor (`toml_edit` stores comments and spacing there).
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

/// Replaces the config in one step: write a sibling temp file, keep the original permissions,
/// then rename over it. A crash can leave the temp file, never a half-written config.
fn write_document(config: &Path, doc: &DocumentMut) -> Result<(), String> {
    let dir = config
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    let name = config
        .file_name()
        .ok_or_else(|| format!("{}: not a file path", config.display()))?;
    let tmp = dir.join(format!(
        ".{}.tmp-{}",
        name.to_string_lossy(),
        std::process::id()
    ));
    fs::write(&tmp, doc.to_string()).map_err(|err| format!("{}: {err}", tmp.display()))?;
    if let Ok(metadata) = fs::metadata(config) {
        let _ = fs::set_permissions(&tmp, metadata.permissions());
    }
    // Windows refuses to rename over an existing file; POSIX replaces it atomically.
    #[cfg(windows)]
    {
        let _ = fs::remove_file(config);
    }
    fs::rename(&tmp, config).map_err(|err| {
        let _ = fs::remove_file(&tmp);
        format!("{}: {err}", config.display())
    })
}

/// Splits the sections. Each keeps its own schema and validation: the mixer's own parser reads
/// `[mixer]` (or the whole text for a standalone topology), `LiveConfig` deserializes `[live]`,
/// and preferences are read from `[preference]` by `preference::parse`.
fn parse(path: &Path, text: &str, mut notes: Vec<String>) -> Result<Config, String> {
    let value: toml::Value =
        toml::from_str(text).map_err(|err| format!("{}: {err}", path.display()))?;
    let mixer = MixerConfig::from_toml_str(text)
        .map_err(|err| format!("{}: {}", path.display(), err.message()))?;

    let live = match value.get("live") {
        Some(section) => {
            let parsed: LiveConfig = section
                .clone()
                .try_into()
                .map_err(|err| format!("{}: [live]: {err}", path.display()))?;
            let live = parsed.clone().sanitised();
            if live != parsed {
                notes.push(format!("{}: some live values were clamped", path.display()));
            }
            live
        }
        None => LiveConfig::default(),
    };

    let controller_sections: Vec<ControllerSection> = match value.get("controller") {
        Some(toml::Value::Array(entries)) => entries
            .iter()
            .map(controller_section)
            .collect::<Result<Vec<_>, _>>()
            .map_err(|err| format!("{}: [[controller]]: {err}", path.display()))?,
        Some(section) => {
            let section = controller_section(section)
                .map_err(|err| format!("{}: [controller]: {err}", path.display()))?;
            // The shipped template keeps `[controller]` with every key commented out. That is
            // "no controller configured", not one anonymous controller with no port: a phantom
            // entry would make the TUI's F9 picker think a configured list already exists and
            // silently skip the port the user just chose.
            if section.id.is_none() && section.map.is_none() && section.device.is_none() {
                Vec::new()
            } else {
                vec![section]
            }
        }
        None => Vec::new(),
    };
    let dir = path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    let mut controllers = Vec::with_capacity(controller_sections.len());
    let count = controller_sections.len();
    for (index, section) in controller_sections.into_iter().enumerate() {
        let label = section.id.clone().unwrap_or_else(|| {
            if count == 1 {
                "default".to_owned()
            } else {
                format!("controller{}", index + 1)
            }
        });
        let map = section.map.map(|map| resolve_against(dir, &map));
        // A configured but unreadable map is a silent "no controller" otherwise; say exactly why.
        if let Some(map) = &map {
            match std::fs::read_to_string(map) {
                Ok(text) => {
                    let base = Path::new(map)
                        .parent()
                        .filter(|parent| !parent.as_os_str().is_empty())
                        .unwrap_or_else(|| Path::new("."));
                    if let Err(err) = controller::Map::from_toml_str_at(&text, base) {
                        notes.push(format!(
                            "{}: controller `{label}`.map `{map}` does not parse: {err}",
                            path.display()
                        ));
                    }
                }
                Err(err) => notes.push(format!(
                    "{}: controller `{label}`.map `{map}` cannot be read: {err}",
                    path.display()
                )),
            }
        }
        controllers.push(Controller {
            id: section.id.unwrap_or(label),
            map,
            device: section.device,
        });
    }
    let controller = controllers.first().cloned().unwrap_or_default();

    let analysis = match value
        .get("preference")
        .and_then(|preference| preference.get("analysis"))
    {
        Some(section) => analysis_section(section)
            .map_err(|err| format!("{}: [preference.analysis]: {err}", path.display()))?,
        None => AnalysisBackends::default(),
    };

    Ok(Config {
        path: path.to_path_buf(),
        mixer,
        live,
        controller,
        controllers,
        analysis,
        notes,
    })
}

/// The conventional name of a unit-map file, used by the TUI's pickers when no config path is at
/// hand. A real map path always comes from `[controller].map` or `map_path_for`.
pub fn default_map_path() -> &'static str {
    "mapping.toml"
}

/// The unit-map file next to one specific config: the guide's default target and the path a session
/// shows. `[controller].map` overrides it, but a config that names no map simply opens no input.
pub fn map_path_for(config_path: &Path) -> String {
    if config_path == Path::new(BUILTIN_PROFILE) {
        return BUILTIN_MAP.to_owned();
    }
    config_path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."))
        .join("mapping.toml")
        .to_string_lossy()
        .into_owned()
}

/// The `[[mixer.output]]` array of a one-file config. The TUI's device pickers read it; a missing
/// or malformed section means "no outputs declared" rather than an error.
pub fn output_tables(doc: &toml_edit::DocumentMut) -> Option<&toml_edit::ArrayOfTables> {
    doc.get("mixer")?
        .as_table()?
        .get("output")?
        .as_array_of_tables()
}

/// The same array, mutable, creating `[mixer]` and the array when the config omits them. Used by
/// the settings screens, which write a device back into the config the session is running on.
pub fn output_tables_mut(
    doc: &mut toml_edit::DocumentMut,
) -> Result<&mut toml_edit::ArrayOfTables, String> {
    if doc.get("mixer").is_none() {
        doc.insert("mixer", toml_edit::Item::Table(toml_edit::Table::new()));
    }
    let mixer = doc
        .get_mut("mixer")
        .and_then(|item| item.as_table_mut())
        .ok_or_else(|| "`mixer` is not a table".to_owned())?;
    if mixer.get("output").is_none() {
        mixer.insert(
            "output",
            toml_edit::Item::ArrayOfTables(toml_edit::ArrayOfTables::new()),
        );
    }
    mixer
        .get_mut("output")
        .and_then(|item| item.as_array_of_tables_mut())
        .ok_or_else(|| "`[[mixer.output]]` is not an array of tables".to_owned())
}

fn controller_section(value: &toml::Value) -> Result<ControllerSection, String> {
    let table = value
        .as_table()
        .ok_or_else(|| "must be a table".to_owned())?;
    let mut section = ControllerSection::default();
    for (key, value) in table {
        let text = value
            .as_str()
            .ok_or_else(|| format!("`{key}` must be a string"))?
            .trim()
            .to_owned();
        match key.as_str() {
            "id" => section.id = Some(text),
            "map" => section.map = Some(text),
            "device" => section.device = Some(text),
            other => return Err(format!("unknown key `{other}` (id | map | device)")),
        }
    }
    Ok(section)
}

/// A path written inside the config: absolute stays absolute, relative joins the config's folder.
fn resolve_against(dir: &Path, path: &str) -> String {
    let path = Path::new(path.trim());
    if path.is_absolute() {
        return path.to_string_lossy().into_owned();
    }
    dir.join(path).to_string_lossy().into_owned()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!("pipefader-config-{}-{name}", std::process::id()))
    }

    #[test]
    fn the_template_parses_into_a_usable_config() {
        let cfg = parse(Path::new("config.toml"), template(), Vec::new()).expect("parses");
        assert_eq!(
            cfg.mixer.channels.len(),
            2,
            "the reference topology has two decks"
        );
        assert_eq!(cfg.mixer.outputs.len(), 2);
        assert!(
            !cfg.mixer.autogain.enabled,
            "auto-gain is off in the template"
        );
        assert_eq!(cfg.controller, Controller::default());
        assert!(
            cfg.controllers.is_empty(),
            "the template's empty [controller] table means no controller, not a phantom session"
        );
    }

    #[test]
    fn an_empty_controller_table_is_no_controller_but_a_named_one_is_kept() {
        let cfg = parse(
            Path::new("config.toml"),
            "[mixer]\n[[multideck.deck]]\nside = \"center\"\n[controller]\n",
            Vec::new(),
        )
        .expect("parses");
        assert!(cfg.controllers.is_empty());

        let cfg = parse(
            Path::new("config.toml"),
            "[mixer]\n[[multideck.deck]]\nside = \"center\"\n[controller]\nid = \"ctl1\"\n",
            Vec::new(),
        )
        .expect("parses");
        assert_eq!(cfg.controllers.len(), 1);
        assert_eq!(cfg.controllers[0].id, "ctl1");
    }

    #[test]
    fn analysis_settings_include_the_auto_analyse_switch() {
        let cfg = parse(
            Path::new("config.toml"),
            "[mixer]\n[[multideck.deck]]\nside = \"center\"\n[preference.analysis]\nbeats = \"stratum\"\nkey = \"timestretch\"\nauto_analyse = true\n",
            Vec::new(),
        )
        .expect("parses");
        assert_eq!(cfg.analysis.beats, Backend::Stratum);
        assert_eq!(cfg.analysis.key, Backend::Timestretch);
        assert!(cfg.analysis.auto_analyse);

        let err = parse(
            Path::new("config.toml"),
            "[preference.analysis]\nauto_analyse = \"yes\"\n",
            Vec::new(),
        )
        .unwrap_err();
        assert!(err.contains("auto_analyse"), "{err}");
    }

    #[test]
    fn sections_are_read_independently_and_map_is_a_resolved_pointer() {
        let dir = temp("sections");
        let path = dir.join("config.toml");
        let text = r#"
[mixer]
[mixer.autogain]
enabled = true
target_db = -9.0

[[multideck.deck]]
side = "center"

[live]

[preference]
[preference.waveform]
backend = "braille"

[controller]
map = "mapping.toml"
device = "DDJ-400"
"#;
        let cfg = parse(&path, text, Vec::new()).expect("parses");
        assert_eq!(cfg.mixer.channels.len(), 1);
        assert!(cfg.mixer.autogain.enabled);
        assert_eq!(cfg.mixer.autogain.target_db, -9.0);
        assert_eq!(
            cfg.controller.map,
            Some(dir.join("mapping.toml").to_string_lossy().into_owned())
        );
        assert_eq!(cfg.controller.device.as_deref(), Some("DDJ-400"));
    }

    #[test]
    fn an_existing_file_is_read_not_overwritten() {
        let path = temp("existing.toml");
        std::fs::write(&path, "[mixer]\n[[multideck.deck]]\nside = \"center\"\n").unwrap();
        let cfg = load_or_create(Some(path.to_string_lossy().as_ref())).expect("reads");
        assert_eq!(cfg.mixer.channels.len(), 1);
        assert_eq!(
            std::fs::read_to_string(&path).unwrap(),
            "[mixer]\n[[multideck.deck]]\nside = \"center\"\n",
            "loading must not rewrite the user's file"
        );
        std::fs::remove_file(&path).ok();
    }

    #[test]
    fn a_missing_explicit_config_is_an_error() {
        let path = temp("absent.toml");
        std::fs::remove_file(&path).ok();
        assert!(load_or_create(Some(path.to_string_lossy().as_ref())).is_err());
    }

    #[test]
    fn a_missing_default_config_runs_on_builtin_without_writing_a_file() {
        // The old code copied the template to the default path on first start. The new code runs
        // in memory: the built-in source has no file and needs no directory created.
        let cfg = load_builtin().expect("built-in start");

        assert_eq!(cfg.path, Path::new(BUILTIN_PROFILE));
        assert!(cfg.notes.iter().any(|note| note.contains("built-in")));
        // The built-in config still parses into a usable rig.
        assert!(!cfg.mixer.channels.is_empty());
        // Its map source is the built-in too, not a sibling file.
        assert_eq!(map_path_for(&cfg.path), BUILTIN_MAP);
    }

    #[test]
    fn a_user_config_is_read_verbatim_and_never_rewritten() {
        let path = temp("user-config.toml");
        let edited = "[mixer]\n[[multideck.deck]]\nside = \"center\"\n";
        std::fs::write(&path, edited).unwrap();
        let cfg = load_or_create(Some(path.to_string_lossy().as_ref())).expect("reads");
        assert_eq!(cfg.path, path);
        assert_eq!(cfg.mixer.channels.len(), 1);
        assert_eq!(std::fs::read_to_string(&path).unwrap(), edited);
        std::fs::remove_file(&path).ok();
    }

    #[test]
    fn builtin_sources_resolve_to_the_embedded_text() {
        assert_eq!(
            read_profile_text(BUILTIN_PROFILE).unwrap(),
            template(),
            "the built-in config resolves to the embedded template"
        );
        let (map, base) = read_map_text(BUILTIN_MAP).unwrap();
        assert_eq!(map, MAP_TEMPLATE);
        assert_eq!(base, Path::new("."));
        assert!(is_builtin(BUILTIN_PROFILE) && is_builtin(BUILTIN_MAP));
        assert!(!is_builtin("mapping.toml"));
        // A built-in profile's sibling map is the built-in map, not a path next to a real file.
        assert_eq!(map_path_for(Path::new(BUILTIN_PROFILE)), BUILTIN_MAP);
    }

    #[test]
    fn a_broken_controller_map_is_reported_not_silent() {
        let dir = temp("controller-map");
        std::fs::remove_dir_all(&dir).ok();
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("config.toml");
        std::fs::write(
            &path,
            "[mixer]\n[[multideck.deck]]\nside = \"center\"\n[controller]\nmap = \"missing.toml\"\n",
        )
        .unwrap();
        let cfg = load_or_create(Some(path.to_string_lossy().as_ref())).expect("parses");
        assert!(
            cfg.notes
                .iter()
                .any(|note| note.contains("controller") && note.contains("cannot be read")),
            "a missing map must be named: {:?}",
            cfg.notes
        );

        // Once the map is a real file, no note is produced.
        std::fs::write(dir.join("missing.toml"), MAP_TEMPLATE).unwrap();
        let ok = load_or_create(Some(path.to_string_lossy().as_ref())).expect("parses");
        assert!(ok.notes.is_empty(), "{:?}", ok.notes);
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn write_controller_records_the_port_map_and_derived_id() {
        let dir = temp("controller-write");
        std::fs::remove_dir_all(&dir).ok();
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("config.toml");
        std::fs::write(
            &path,
            "[mixer]\n# top\n[[multideck.deck]]\nsource = \"ctl1.A\"\n\n[controller]\n# keep this\n",
        )
        .unwrap();
        let map = dir.join("mapping.toml");
        std::fs::write(&map, MAP_TEMPLATE).unwrap();

        write_controller(&path, Some("Numark Party Mix"), Some(&map)).unwrap();

        let text = std::fs::read_to_string(&path).unwrap();
        assert!(text.contains("# top"), "{text}");
        assert!(text.contains("# keep this"), "{text}");
        assert!(text.contains("id = \"ctl1\""), "{text}");
        assert!(text.contains("device = \"Numark Party Mix\""), "{text}");
        assert!(text.contains("map = \"mapping.toml\""), "{text}");

        let cfg = load_or_create(Some(path.to_string_lossy().as_ref())).expect("parses");
        assert_eq!(cfg.controller.id, "ctl1");
        assert_eq!(cfg.controller.device.as_deref(), Some("Numark Party Mix"));
        assert_eq!(
            cfg.controller.map.as_deref(),
            Some(map.to_string_lossy().as_ref())
        );
        assert!(
            deck_routes(&cfg.mixer, Some("ctl1"))
                .resolve("A", false)
                .is_ok(),
            "the persisted id must keep the source mapping alive"
        );
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn write_controller_updates_only_the_first_array_entry() {
        let dir = temp("controller-array");
        std::fs::remove_dir_all(&dir).ok();
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("config.toml");
        std::fs::write(
            &path,
            "[mixer]\n[[multideck.deck]]\nsource = \"ctl1.A\"\n\n\
             [[controller]]\nid = \"ctl1\"\ndevice = \"Old\"\nmap = \"old.toml\"\n\n\
             [[controller]]\nid = \"ctl2\"\ndevice = \"Second\"\n",
        )
        .unwrap();
        let map = dir.join("new.toml");
        std::fs::write(&map, MAP_TEMPLATE).unwrap();

        write_controller(&path, Some("New"), Some(&map)).unwrap();

        let text = std::fs::read_to_string(&path).unwrap();
        assert!(text.contains("id = \"ctl1\""), "{text}");
        assert!(text.contains("device = \"New\""), "{text}");
        assert!(text.contains("device = \"Second\""), "{text}");
        assert!(!text.contains("device = \"Old\""), "{text}");
        let cfg = load_or_create(Some(path.to_string_lossy().as_ref())).expect("parses");
        assert_eq!(cfg.controllers.len(), 2);
        assert_eq!(cfg.controllers[0].id, "ctl1");
        assert_eq!(cfg.controllers[0].device.as_deref(), Some("New"));
        assert_eq!(cfg.controllers[1].device.as_deref(), Some("Second"));
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn write_controller_inserts_a_section_and_keeps_the_owner_id() {
        let dir = temp("controller-insert");
        std::fs::remove_dir_all(&dir).ok();
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("config.toml");
        std::fs::write(&path, "[mixer]\n[[multideck.deck]]\nsource = \"ctl1.B\"\n").unwrap();

        write_controller(&path, Some("Port"), None).unwrap();

        let text = std::fs::read_to_string(&path).unwrap();
        assert!(text.contains("[controller]"), "{text}");
        assert!(text.contains("id = \"ctl1\""), "{text}");
        assert!(text.contains("device = \"Port\""), "{text}");
        assert!(!text.contains("map ="), "{text}");
        let cfg = load_or_create(Some(path.to_string_lossy().as_ref())).expect("parses");
        assert_eq!(cfg.controller.id, "ctl1");
        assert_eq!(cfg.controller.device.as_deref(), Some("Port"));
        assert_eq!(cfg.controller.map, None);
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn write_controller_keeps_a_map_outside_the_config_dir_absolute() {
        let dir = temp("controller-absolute");
        std::fs::remove_dir_all(&dir).ok();
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("config.toml");
        std::fs::write(&path, "[mixer]\n[[multideck.deck]]\nsource = \"ctl1.A\"\n").unwrap();
        let outside = temp("controller-absolute-map");
        std::fs::create_dir_all(&outside).unwrap();
        let map = outside.join("mapping.toml");
        std::fs::write(&map, MAP_TEMPLATE).unwrap();

        write_controller(&path, None, Some(&map)).unwrap();

        let text = std::fs::read_to_string(&path).unwrap();
        assert!(!text.contains("map = \"mapping.toml\""), "{text}");
        let cfg = load_or_create(Some(path.to_string_lossy().as_ref())).expect("parses");
        assert_eq!(
            cfg.controller.map.as_deref(),
            Some(
                std::fs::canonicalize(&map)
                    .unwrap()
                    .to_string_lossy()
                    .as_ref()
            )
        );
        std::fs::remove_dir_all(&dir).ok();
        std::fs::remove_dir_all(&outside).ok();
    }
}

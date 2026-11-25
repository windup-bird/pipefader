//! The machine-wide settings the menu exposes, read and written without the engine.
//!
//! The Flutter Preferences page renders the same descriptors the terminal screens edit, so a new row
//! is one entry in [`pages`] plus one arm in [`set`]. The mapping from "a row in a menu" to "a key
//! in the profile" lives here; nothing outside this module names a TOML path.
//!
//! Writes use `toml_edit`, so comments and key order survive. The sample rate, keylock block and
//! stem provider are the values that need a new process; everything else is either part of the
//! mixer topology (reloaded live) or read by the session thread on the next request.

use std::fs;
use std::path::Path;

use audio::CrossfaderCurve;
use toml_edit::{DocumentMut, Item, Table};

use super::profile;

/// One selectable value: the label is English (the Flutter layer localises known keys), the value
/// is exactly what [`set`] accepts.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SettingsOption {
    pub label: String,
    pub value: String,
}

/// One editable row.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SettingsRow {
    /// The menu's name for the key, not a TOML path.
    pub key: String,
    pub label: String,
    /// Extra text under the label, usually "restart required".
    pub note: String,
    /// `choice` or `toggle`.
    pub kind: String,
    pub value: String,
    pub options: Vec<SettingsOption>,
    pub needs_restart: bool,
    pub enabled: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SettingsSection {
    pub title: String,
    pub rows: Vec<SettingsRow>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SettingsPage {
    pub id: String,
    pub title: String,
    pub sections: Vec<SettingsSection>,
}

/// Whether changing this key needs a new process.
pub fn needs_restart(key: &str) -> bool {
    matches!(key, "sample_rate" | "keylock_block" | "stems_provider")
}

/// Whether this key changes the mixer topology and therefore needs a live reload.
pub fn is_mixer_key(key: &str) -> bool {
    matches!(
        key,
        "crossfader_curve"
            | "cue_blend"
            | "cue_cut_width"
            | "fader_position"
            | "autogain"
            | "autogain_target_db"
            | "limiter"
            | "limiter_ceiling_db"
            | "eq_lower_hz"
            | "eq_higher_hz"
            | "filter"
    )
}

/// Whether this key is consumed by the session thread rather than the audio engine.
pub fn is_session_key(key: &str) -> bool {
    matches!(
        key,
        "beats_backend"
            | "key_backend"
            | "auto_analyse"
            | "grid_offset_ms"
            | "key_format"
            | "follow"
    )
}

/// Reads every page from a profile source. A built-in source is decoded from the embedded text.
pub fn pages(source: &str) -> Result<Vec<SettingsPage>, String> {
    let text = profile::read_profile_text(source)?;
    let values = Values::parse(&text, source)?;
    let builtin = profile::is_builtin(source);
    Ok(build_pages(&values, builtin))
}

/// Writes one setting and returns the re-read pages.
pub fn set(source: &str, key: &str, value: &str) -> Result<Vec<SettingsPage>, String> {
    if profile::is_builtin(source) {
        return Err("the built-in profile is read-only".to_owned());
    }
    let text = fs::read_to_string(Path::new(source)).map_err(|err| format!("{source}: {err}"))?;
    let mut doc: DocumentMut = text.parse().map_err(|err| format!("{source}: {err}"))?;

    match key {
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
        "cue_cut_width" => {
            let width = parse_f64("cue_cut_width", value)?;
            if !(0.0..=0.5).contains(&width) {
                return Err(format!("cue_cut_width: {width} is outside 0..=0.5"));
            }
            let table = table_mut(&mut doc, "mixer", Some("cue"))?;
            set_float(table, "cut_width", width);
        }
        "fader_position" => {
            let position = match value.trim() {
                "pre" | "post" => value.trim(),
                other => return Err(format!("fader_position: `{other}` is not pre | post")),
            };
            let table = table_mut(&mut doc, "mixer", Some("fader"))?;
            set_str(table, "position", position);
        }
        "autogain" => {
            let on = parse_on_off("autogain", value)?;
            let table = table_mut(&mut doc, "mixer", Some("autogain"))?;
            set_bool(table, "enabled", on);
        }
        "autogain_target_db" => {
            let target = parse_f64("autogain_target_db", value)?;
            if !(-40.0..=0.0).contains(&target) {
                return Err(format!("autogain_target_db: {target} is outside -40..=0"));
            }
            let table = table_mut(&mut doc, "mixer", Some("autogain"))?;
            set_float(table, "target_db", target);
        }
        "limiter" => {
            let on = parse_on_off("limiter", value)?;
            let table = table_mut(&mut doc, "mixer", Some("limiter"))?;
            set_bool(table, "limiter", on);
        }
        "limiter_ceiling_db" => {
            let ceiling = parse_f64("limiter_ceiling_db", value)?;
            if !(-40.0..=12.0).contains(&ceiling) {
                return Err(format!("limiter_ceiling_db: {ceiling} is outside -40..=12"));
            }
            let table = table_mut(&mut doc, "mixer", Some("limiter"))?;
            set_float(table, "ceiling_db", ceiling);
        }
        "eq_lower_hz" => {
            let hz = parse_int("eq_lower_hz", value)?;
            if !(20..=20_000).contains(&hz) {
                return Err(format!("eq_lower_hz: {hz} is outside 20..=20000"));
            }
            let table = table_mut(&mut doc, "mixer", Some("eq"))?;
            set_int(table, "lower_hz", hz);
        }
        "eq_higher_hz" => {
            let hz = parse_int("eq_higher_hz", value)?;
            if !(20..=20_000).contains(&hz) {
                return Err(format!("eq_higher_hz: {hz} is outside 20..=20000"));
            }
            let table = table_mut(&mut doc, "mixer", Some("eq"))?;
            set_int(table, "higher_hz", hz);
        }
        "filter" => {
            let kind = match value.trim() {
                "linear" | "moog" => value.trim(),
                other => return Err(format!("filter: `{other}` is not linear | moog")),
            };
            let table = table_mut(&mut doc, "mixer", Some("fx"))?;
            set_str(table, "filter", kind);
        }
        "sample_rate" => {
            let rate = parse_int("sample_rate", value)?;
            if !(8_000..=384_000).contains(&rate) {
                return Err(format!("sample_rate: {rate} is outside 8000..=384000"));
            }
            let table = table_mut(&mut doc, "live", Some("audio"))?;
            set_int(table, "sample_rate", rate);
        }
        "keylock_block" => {
            let block = parse_int("keylock_block", value)?;
            if !(512..=16_384).contains(&block) {
                return Err(format!("keylock_block: {block} is outside 512..=16384"));
            }
            let table = table_mut(&mut doc, "live", Some("keylock"))?;
            set_int(table, "block", block);
        }
        "stems_provider" => {
            let provider = match value.trim() {
                "cpu" => "cpu",
                "cuda" | "gpu" => "cuda",
                other => return Err(format!("stems_provider: `{other}` is not cpu | cuda")),
            };
            let table = table_mut(&mut doc, "live", Some("stems"))?;
            set_str(table, "provider", provider);
        }
        "beats_backend" => {
            let backend = parse_backend("beats_backend", value)?;
            let table = table_mut(&mut doc, "preference", Some("analysis"))?;
            set_str(table, "beats", backend);
        }
        "key_backend" => {
            let backend = parse_backend("key_backend", value)?;
            let table = table_mut(&mut doc, "preference", Some("analysis"))?;
            set_str(table, "key", backend);
        }
        "auto_analyse" => {
            let on = parse_on_off("auto_analyse", value)?;
            let table = table_mut(&mut doc, "preference", Some("analysis"))?;
            set_bool(table, "auto_analyse", on);
        }
        "grid_offset_ms" => {
            let offset = parse_f64("grid_offset_ms", value)?;
            if !(-1_000.0..=1_000.0).contains(&offset) {
                return Err(format!("grid_offset_ms: {offset} is outside -1000..=1000"));
            }
            let table = table_mut(&mut doc, "preference", None)?;
            set_float(table, "grid_offset_ms", offset);
        }
        "key_format" => {
            let format = match value.trim() {
                "camelot" | "classic" => value.trim(),
                other => return Err(format!("key_format: `{other}` is not camelot | classic")),
            };
            let table = table_mut(&mut doc, "preference", Some("display"))?;
            set_str(table, "key", format);
        }
        "follow" => {
            let on = parse_on_off("follow", value)?;
            let table = table_mut(&mut doc, "preference", Some("display"))?;
            set_bool(table, "follow", on);
        }
        other => return Err(format!("unknown setting `{other}`")),
    }

    fs::write(Path::new(source), doc.to_string()).map_err(|err| format!("{source}: {err}"))?;
    pages(source)
}

/// The file spelling of a crossfader curve (`serde`'s `snake_case`).
pub fn curve_name(curve: CrossfaderCurve) -> &'static str {
    match curve {
        CrossfaderCurve::Classic => "classic",
        CrossfaderCurve::ConstantPower => "constant_power",
        CrossfaderCurve::Cut => "cut",
    }
}

struct Values {
    crossfader_curve: String,
    cue_blend: String,
    cue_cut_width: String,
    fader_position: String,
    autogain: String,
    autogain_target_db: String,
    limiter: String,
    limiter_ceiling_db: String,
    eq_lower_hz: String,
    eq_higher_hz: String,
    filter: String,
    sample_rate: String,
    keylock_block: String,
    stems_provider: String,
    beats_backend: String,
    key_backend: String,
    auto_analyse: String,
    grid_offset_ms: String,
    key_format: String,
    follow: String,
}

impl Values {
    fn parse(text: &str, source: &str) -> Result<Self, String> {
        let value: toml::Value = text
            .parse()
            .map_err(|err| format!("{source}: {err}"))?;
        Ok(Self {
            crossfader_curve: string_at(&value, &["mixer", "crossfader", "curve"])
                .unwrap_or_else(|| "classic".to_owned()),
            cue_blend: number_at(&value, &["mixer", "fader", "cue_blend"])
                .unwrap_or_else(|| "-1".to_owned()),
            cue_cut_width: number_at(&value, &["mixer", "cue", "cut_width"])
                .unwrap_or_else(|| "0.05".to_owned()),
            fader_position: string_at(&value, &["mixer", "fader", "position"])
                .unwrap_or_else(|| "pre".to_owned()),
            autogain: bool_at(&value, &["mixer", "autogain", "enabled"]).unwrap_or_else(|| "off".to_owned()),
            autogain_target_db: number_at(&value, &["mixer", "autogain", "target_db"])
                .unwrap_or_else(|| "-12".to_owned()),
            limiter: bool_at(&value, &["mixer", "limiter", "limiter"]).unwrap_or_else(|| "on".to_owned()),
            limiter_ceiling_db: number_at(&value, &["mixer", "limiter", "ceiling_db"])
                .unwrap_or_else(|| "-1".to_owned()),
            eq_lower_hz: number_at(&value, &["mixer", "eq", "lower_hz"])
                .unwrap_or_else(|| "250".to_owned()),
            eq_higher_hz: number_at(&value, &["mixer", "eq", "higher_hz"])
                .unwrap_or_else(|| "2000".to_owned()),
            filter: string_at(&value, &["mixer", "fx", "filter"])
                .unwrap_or_else(|| "linear".to_owned()),
            sample_rate: number_at(&value, &["live", "audio", "sample_rate"])
                .unwrap_or_else(|| "44100".to_owned()),
            keylock_block: number_at(&value, &["live", "keylock", "block"])
                .unwrap_or_else(|| "2048".to_owned()),
            stems_provider: string_at(&value, &["live", "stems", "provider"])
                .unwrap_or_else(|| "cpu".to_owned()),
            beats_backend: string_at(&value, &["preference", "analysis", "beats"])
                .unwrap_or_else(|| "timestretch".to_owned()),
            key_backend: string_at(&value, &["preference", "analysis", "key"])
                .unwrap_or_else(|| "timestretch".to_owned()),
            auto_analyse: bool_at(&value, &["preference", "analysis", "auto_analyse"])
                .unwrap_or_else(|| "off".to_owned()),
            grid_offset_ms: number_at(&value, &["preference", "grid_offset_ms"])
                .unwrap_or_else(|| "0".to_owned()),
            key_format: string_at(&value, &["preference", "display", "key"])
                .unwrap_or_else(|| "camelot".to_owned()),
            follow: bool_at(&value, &["preference", "display", "follow"]).unwrap_or_else(|| "on".to_owned()),
        })
    }
}

fn build_pages(values: &Values, builtin: bool) -> Vec<SettingsPage> {
    let enabled = !builtin;
    vec![
        SettingsPage {
            id: "mixer".to_owned(),
            title: "Mixer".to_owned(),
            sections: vec![
                section(
                    "Crossfader",
                    vec![
                        choice("crossfader_curve", "Curve", &values.crossfader_curve, &[
                            ("Classic", "classic"),
                            ("Constant Power", "constant_power"),
                            ("Cut", "cut"),
                        ], enabled),
                        choice("cue_blend", "Cue Blend", &cue_blend_label(&values.cue_blend), &[
                            ("Cue", "cue"),
                            ("Both", "both"),
                            ("Master", "master"),
                        ], enabled),
                        choice("cue_cut_width", "Cut Width", &values.cue_cut_width, &[
                            ("0.02", "0.02"),
                            ("0.05", "0.05"),
                            ("0.10", "0.1"),
                        ], enabled),
                    ],
                ),
                section(
                    "Fader",
                    vec![choice("fader_position", "Cue Tap", &values.fader_position, &[
                        ("Pre", "pre"),
                        ("Post", "post"),
                    ], enabled)],
                ),
                section(
                    "Auto Gain",
                    vec![
                        toggle("autogain", "Auto Gain", &values.autogain, enabled),
                        choice("autogain_target_db", "Target", &values.autogain_target_db, &[
                            ("-18 dB", "-18"),
                            ("-15 dB", "-15"),
                            ("-12 dB", "-12"),
                            ("-9 dB", "-9"),
                            ("-6 dB", "-6"),
                        ], enabled),
                    ],
                ),
                section(
                    "Limiter",
                    vec![
                        toggle("limiter", "Limiter", &values.limiter, enabled),
                        choice("limiter_ceiling_db", "Ceiling", &values.limiter_ceiling_db, &[
                            ("-3 dB", "-3"),
                            ("-2 dB", "-2"),
                            ("-1 dB", "-1"),
                            ("0 dB", "0"),
                        ], enabled),
                    ],
                ),
                section(
                    "EQ",
                    vec![
                        choice("eq_lower_hz", "Low / Mid", &values.eq_lower_hz, &[
                            ("100 Hz", "100"),
                            ("150 Hz", "150"),
                            ("250 Hz", "250"),
                            ("400 Hz", "400"),
                        ], enabled),
                        choice("eq_higher_hz", "Mid / High", &values.eq_higher_hz, &[
                            ("1 kHz", "1000"),
                            ("1.5 kHz", "1500"),
                            ("2 kHz", "2000"),
                            ("3 kHz", "3000"),
                        ], enabled),
                    ],
                ),
                section(
                    "Filter",
                    vec![choice("filter", "Kind", &values.filter, &[
                        ("Linear", "linear"),
                        ("Moog", "moog"),
                    ], enabled)],
                ),
            ],
        },
        SettingsPage {
            id: "audio".to_owned(),
            title: "Audio".to_owned(),
            sections: vec![
                section(
                    "Playback",
                    vec![choice("sample_rate", "Sample Rate", &values.sample_rate, &[
                        ("44.1 kHz", "44100"),
                        ("48 kHz", "48000"),
                        ("96 kHz", "96000"),
                    ], enabled).restart()],
                ),
                section(
                    "Keylock",
                    vec![choice("keylock_block", "Block", &values.keylock_block, &[
                        ("1024", "1024"),
                        ("2048", "2048"),
                        ("4096", "4096"),
                    ], enabled).restart()],
                ),
                section(
                    "Stems",
                    vec![choice("stems_provider", "Provider", &values.stems_provider, &[
                        ("CPU", "cpu"),
                        ("CUDA", "cuda"),
                    ], enabled).restart()],
                ),
            ],
        },
        SettingsPage {
            id: "analysis".to_owned(),
            title: "Analysis".to_owned(),
            sections: vec![
                section(
                    "Backends",
                    vec![
                        choice("beats_backend", "Beats", &values.beats_backend, &[
                            ("Stratum", "stratum"),
                            ("Time-stretch", "timestretch"),
                        ], enabled),
                        choice("key_backend", "Key", &values.key_backend, &[
                            ("Stratum", "stratum"),
                            ("Time-stretch", "timestretch"),
                        ], enabled),
                    ],
                ),
                section(
                    "Behaviour",
                    vec![toggle("auto_analyse", "Auto Analyse", &values.auto_analyse, enabled)],
                ),
                section(
                    "Grid",
                    vec![choice("grid_offset_ms", "Offset", &values.grid_offset_ms, &[
                        ("-16 ms", "-16"),
                        ("-8 ms", "-8"),
                        ("0 ms", "0"),
                        ("8 ms", "8"),
                        ("16 ms", "16"),
                    ], enabled)],
                ),
            ],
        },
        SettingsPage {
            id: "display".to_owned(),
            title: "Display".to_owned(),
            sections: vec![
                section(
                    "Keys",
                    vec![choice("key_format", "Notation", &values.key_format, &[
                        ("Camelot", "camelot"),
                        ("Classic", "classic"),
                    ], enabled)],
                ),
                section(
                    "Panel",
                    vec![toggle("follow", "Follow Commands", &values.follow, enabled)],
                ),
            ],
        },
    ]
}

fn cue_blend_label(value: &str) -> String {
    match value {
        "-1" | "-1.0" => "cue".to_owned(),
        "0" | "0.0" => "both".to_owned(),
        "1" | "1.0" => "master".to_owned(),
        other => other.to_owned(),
    }
}

fn section(title: &str, rows: Vec<SettingsRow>) -> SettingsSection {
    SettingsSection {
        title: title.to_owned(),
        rows,
    }
}

fn choice(
    key: &str,
    label: &str,
    value: &str,
    options: &[(&str, &str)],
    enabled: bool,
) -> SettingsRow {
    SettingsRow {
        key: key.to_owned(),
        label: label.to_owned(),
        note: String::new(),
        kind: "choice".to_owned(),
        value: value.to_owned(),
        options: options
            .iter()
            .map(|(label, value)| SettingsOption {
                label: (*label).to_owned(),
                value: (*value).to_owned(),
            })
            .collect(),
        needs_restart: needs_restart(key),
        enabled,
    }
}

fn toggle(key: &str, label: &str, value: &str, enabled: bool) -> SettingsRow {
    SettingsRow {
        key: key.to_owned(),
        label: label.to_owned(),
        note: String::new(),
        kind: "toggle".to_owned(),
        value: value.to_owned(),
        options: vec![
            SettingsOption {
                label: "Off".to_owned(),
                value: "off".to_owned(),
            },
            SettingsOption {
                label: "On".to_owned(),
                value: "on".to_owned(),
            },
        ],
        needs_restart: needs_restart(key),
        enabled,
    }
}

impl SettingsRow {
    fn restart(mut self) -> Self {
        self.needs_restart = true;
        self.note = "restart required".to_owned();
        self
    }
}

fn at<'a>(value: &'a toml::Value, path: &[&str]) -> Option<&'a toml::Value> {
    let mut current = value;
    for key in path {
        current = current.get(*key)?;
    }
    Some(current)
}

fn string_at(value: &toml::Value, path: &[&str]) -> Option<String> {
    match at(value, path)? {
        toml::Value::String(text) => Some(text.clone()),
        other => Some(other.to_string()),
    }
}

fn number_at(value: &toml::Value, path: &[&str]) -> Option<String> {
    match at(value, path)? {
        toml::Value::Integer(number) => Some(number.to_string()),
        toml::Value::Float(number) => Some(format_float(*number)),
        toml::Value::String(text) => Some(text.clone()),
        _ => None,
    }
}

fn bool_at(value: &toml::Value, path: &[&str]) -> Option<String> {
    match at(value, path)? {
        toml::Value::Boolean(true) => Some("on".to_owned()),
        toml::Value::Boolean(false) => Some("off".to_owned()),
        toml::Value::String(text) if text == "true" || text == "on" => Some("on".to_owned()),
        toml::Value::String(text) if text == "false" || text == "off" => Some("off".to_owned()),
        _ => None,
    }
}

fn format_float(number: f64) -> String {
    if number.fract() == 0.0 {
        format!("{}", number as i64)
    } else {
        format!("{number}")
    }
}

fn parse_on_off(key: &str, value: &str) -> Result<bool, String> {
    match value.trim() {
        "on" | "true" | "1" => Ok(true),
        "off" | "false" | "0" => Ok(false),
        other => Err(format!("{key}: `{other}` is not on | off")),
    }
}

fn parse_f64(key: &str, value: &str) -> Result<f64, String> {
    value
        .trim()
        .parse()
        .map_err(|_| format!("{key}: `{value}` is not a number"))
}

fn parse_int(key: &str, value: &str) -> Result<i64, String> {
    value
        .trim()
        .parse()
        .map_err(|_| format!("{key}: `{value}` is not a number"))
}

fn parse_backend<'a>(key: &str, value: &'a str) -> Result<&'a str, String> {
    match value.trim() {
        "stratum" | "timestretch" => Ok(value.trim()),
        other => Err(format!("{key}: `{other}` is not stratum | timestretch")),
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
    fn reads_the_pages_and_writes_each_kind_without_losing_comments() {
        let dir = temp("write");
        let path = profile_at(&dir);
        let initial = pages(&path).unwrap();
        let mixer = initial.iter().find(|page| page.id == "mixer").unwrap();
        assert!(mixer.sections.iter().any(|section| section
            .rows
            .iter()
            .any(|row| row.key == "crossfader_curve" && row.value == "classic")));

        set(&path, "sample_rate", "48000").unwrap();
        set(&path, "crossfader_curve", "constant_power").unwrap();
        set(&path, "cue_blend", "both").unwrap();
        set(&path, "autogain", "on").unwrap();
        set(&path, "beats_backend", "stratum").unwrap();
        set(&path, "key_format", "classic").unwrap();
        set(&path, "follow", "off").unwrap();

        let after = pages(&path).unwrap();
        assert!(value(&after, "sample_rate") == "48000");
        assert!(value(&after, "crossfader_curve") == "constant_power");
        assert!(value(&after, "cue_blend") == "both");
        assert!(value(&after, "autogain") == "on");
        assert!(value(&after, "beats_backend") == "stratum");
        assert!(value(&after, "key_format") == "classic");
        assert!(value(&after, "follow") == "off");
        let written = fs::read_to_string(&path).unwrap();
        assert!(written.contains("# comments stay"), "{written}");
        assert!(written.contains("[mixer.crossfader]"), "{written}");
        assert!(written.contains("cue_blend = 0.0"), "{written}");
    }

    fn value(pages: &[SettingsPage], key: &str) -> String {
        pages
            .iter()
            .flat_map(|page| &page.sections)
            .flat_map(|section| &section.rows)
            .find(|row| row.key == key)
            .map(|row| row.value.clone())
            .unwrap_or_default()
    }

    #[test]
    fn rejects_bad_values_and_the_builtin_source() {
        let dir = temp("bad");
        let path = profile_at(&dir);
        assert!(set(&path, "sample_rate", "nope").is_err());
        assert!(set(&path, "crossfader_curve", "bouncy").is_err());
        assert!(set(&path, "cue_blend", "2").is_err());
        assert!(set(&path, "autogain", "maybe").is_err());
        assert!(set(&path, "beats_backend", "magic").is_err());
        assert!(set(&path, "unknown", "1").is_err());
        assert!(set(profile::BUILTIN_PROFILE, "autogain", "on").is_err());
    }
}

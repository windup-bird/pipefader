//! Map-file candidates for the controller picker.
//!
//! A map is any `.toml` next to the profile, plus the compiled-in map. Keeping the list here means
//! the terminal picker and the Flutter menu agree on what counts as a usable map: the profile itself
//! is excluded, and a file that does not parse as a controller map is not offered.

use std::fs;
use std::path::{Path, PathBuf};

use super::profile;

/// One selectable controller map.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MapFile {
    /// `BUILTIN_MAP` or a real file path.
    pub path: String,
    /// A short name for the menu row.
    pub name: String,
    pub builtin: bool,
}

/// The built-in map plus every parseable map beside a user profile, sorted by name.
pub fn candidates(source: &str) -> Vec<MapFile> {
    let mut out = vec![MapFile {
        path: profile::BUILTIN_MAP.to_owned(),
        name: profile::BUILTIN_MAP_NAME.to_owned(),
        builtin: true,
    }];
    if profile::is_builtin(source) {
        return out;
    }
    let config = Path::new(source);
    let dir = config
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    let Ok(entries) = fs::read_dir(dir) else {
        return out;
    };
    let mut files: Vec<PathBuf> = entries
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| path.extension().is_some_and(|ext| ext == "toml"))
        .filter(|path| path.file_name() != config.file_name())
        .collect();
    files.sort();
    for path in files {
        let path_text = path.to_string_lossy().into_owned();
        if !is_map(&path_text) {
            continue;
        }
        out.push(MapFile {
            name: path
                .file_name()
                .map(|name| name.to_string_lossy().into_owned())
                .unwrap_or_else(|| path_text.clone()),
            path: path_text,
            builtin: false,
        });
    }
    out
}

/// Whether `path` parses as a map. A random TOML file (the profile, live settings, an analysis
/// cache) is not offered as a map.
fn is_map(path: &str) -> bool {
    let Ok((text, base)) = profile::read_map_text(path) else {
        return false;
    };
    controller::Map::from_toml_str_at(&text, &base).is_ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "pipefader-map-{}-{}-{}",
            std::process::id(),
            name,
            library::library::db::unix_now()
        ));
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn the_builtin_map_is_always_first_and_a_profile_is_not_a_map() {
        let dir = temp("candidates");
        fs::write(
            dir.join("mapping.toml"),
            crate::config::profile::MAP_TEMPLATE,
        )
        .unwrap();
        fs::write(dir.join("config.toml"), "[mixer]\n").unwrap();
        fs::write(dir.join("notes.toml"), "not = \"a map\"\n").unwrap();
        let config = dir.join("config.toml").display().to_string();
        let maps = candidates(&config);
        assert!(maps[0].builtin);
        assert_eq!(maps[0].path, profile::BUILTIN_MAP);
        assert!(maps.iter().any(|map| map.name == "mapping.toml"));
        assert!(!maps.iter().any(|map| map.name == "config.toml"));
        assert!(!maps.iter().any(|map| map.name == "notes.toml"));
    }

    #[test]
    fn a_builtin_profile_lists_only_the_builtin_map() {
        let maps = candidates(profile::BUILTIN_PROFILE);
        assert_eq!(maps.len(), 1);
        assert!(maps[0].builtin);
    }
}

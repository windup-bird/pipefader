//! The paths a front-end hands to the session.
//!
//! Desktop front-ends leave this unset and the existing `HOME`/XDG fallbacks apply. The Flutter
//! bridge installs it once from the host (Dart/Kotlin on Android), so `app` and `library` do not
//! need platform branches for the config, cache, media root or log directory.

use std::path::PathBuf;
use std::sync::OnceLock;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct SessionPaths {
    /// The config file the session runs on (and may write).
    pub config: Option<PathBuf>,
    /// The cache/database directory; Android uses the app's files directory, not its cache.
    pub cache: Option<PathBuf>,
    /// What `~` expands to when a config lists folders.
    pub media_home: Option<PathBuf>,
    /// The directory the bridge writes `bridge.log` into.
    pub log_dir: Option<PathBuf>,
}

static PATHS: OnceLock<SessionPaths> = OnceLock::new();

/// Installs the session paths. A hot restart may call this again with the same values; the first
/// installation wins so one session cannot quietly switch databases.
pub fn install(paths: SessionPaths) {
    let _ = PATHS.set(paths);
}

pub fn current() -> Option<&'static SessionPaths> {
    PATHS.get()
}

pub fn config() -> Option<PathBuf> {
    current().and_then(|paths| paths.config.clone())
}

pub fn cache() -> Option<PathBuf> {
    current().and_then(|paths| paths.cache.clone())
}

pub fn media_home() -> Option<PathBuf> {
    current().and_then(|paths| paths.media_home.clone())
}

pub fn log_dir() -> Option<PathBuf> {
    current()
        .and_then(|paths| paths.log_dir.clone())
        .or_else(|| cache().map(|cache| cache.join("logs")))
}

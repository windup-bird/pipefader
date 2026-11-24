//! Minimal file logger for the bridge.
//!
//! Android has no terminal to watch, so boot progress, panics and Flutter-side errors have to end
//! up in a file the user can reach. The path comes from the front-end's `SessionPaths`; desktop
//! sessions may leave it unset and keep writing to stderr only.

use std::fs::{self, File, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, Once, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

struct Sink {
    file: Option<File>,
    path: Option<PathBuf>,
}

static SINK: OnceLock<Mutex<Sink>> = OnceLock::new();
static HOOK: Once = Once::new();

fn sink() -> &'static Mutex<Sink> {
    SINK.get_or_init(|| Mutex::new(Sink { file: None, path: None }))
}

/// Opens `dir/bridge.log` (appending) and installs the panic hook. Safe to call more than once: a
/// hot restart keeps the file it already has.
pub fn init(dir: Option<&Path>) {
    install_hook();
    let Some(dir) = dir else {
        return;
    };
    let Ok(mut guard) = sink().lock() else {
        return;
    };
    if guard.file.is_some() {
        return;
    }
    if let Err(err) = fs::create_dir_all(dir) {
        eprintln!("[log] {}: {err}", dir.display());
        return;
    }
    let path = dir.join("bridge.log");
    match OpenOptions::new().create(true).append(true).open(&path) {
        Ok(file) => {
            // cpal/audio report device problems with eprintln, which Android drops. Point stderr at
            // the same file before those threads start so their messages are not lost.
            #[cfg(unix)]
            {
                use std::os::fd::AsRawFd;
                unsafe {
                    libc::dup2(file.as_raw_fd(), libc::STDERR_FILENO);
                }
            }
            guard.file = Some(file);
            guard.path = Some(path.clone());
            drop(guard);
            info(format!("log: {}", path.display()));
        }
        Err(err) => eprintln!("[log] {}: {err}", path.display()),
    }
}

pub fn info(message: impl AsRef<str>) {
    write("info", message.as_ref());
}

pub fn error(message: impl AsRef<str>) {
    write("error", message.as_ref());
}

fn write(level: &str, message: &str) {
    logcat(level, message);
    let line = format!("{} {level} {message}\n", now_ms());
    if let Ok(mut guard) = sink().lock() {
        if let Some(file) = guard.file.as_mut() {
            let _ = file.write_all(line.as_bytes());
            let _ = file.flush();
            return;
        }
    }
    if level == "error" {
        eprint!("{line}");
    }
}

/// Mirror to logcat so `adb logcat` shows the same boot lines as `bridge.log`. Android only.
fn logcat(level: &str, message: &str) {
    #[cfg(target_os = "android")]
    {
        use std::ffi::CString;
        let Ok(tag) = CString::new("Pipefader") else {
            return;
        };
        let Ok(text) = CString::new(message) else {
            return;
        };
        let priority = if level == "error" {
            android_log_sys::LogPriority::ERROR
        } else {
            android_log_sys::LogPriority::INFO
        };
        unsafe {
            android_log_sys::__android_log_write(priority as i32, tag.as_ptr(), text.as_ptr());
        }
    }
    #[cfg(not(target_os = "android"))]
    let _ = (level, message);
}

fn install_hook() {
    HOOK.call_once(|| {
        let previous = std::panic::take_hook();
        std::panic::set_hook(Box::new(move |info| {
            error(format!("panic: {info}"));
            previous(info);
        }));
    });
}

/// The last `limit` lines of the log, oldest first. Used by the in-app log page when adb is not
/// available; an empty list means the file does not exist yet.
pub fn tail(limit: usize) -> Result<Vec<String>, String> {
    let Some(dir) = app::paths::log_dir() else {
        return Ok(Vec::new());
    };
    let path = dir.join("bridge.log");
    let text = match fs::read_to_string(&path) {
        Ok(text) => text,
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
        Err(err) => return Err(format!("{}: {err}", path.display())),
    };
    let mut lines: Vec<String> = text
        .lines()
        .rev()
        .take(limit.clamp(1, 2000))
        .map(str::to_owned)
        .collect();
    lines.reverse();
    Ok(lines)
}

fn now_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|elapsed| elapsed.as_millis())
        .unwrap_or(0)
}

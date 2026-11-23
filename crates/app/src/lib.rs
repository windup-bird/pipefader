//! Application/session layer for Pipefader.
//!
//! Everything a front-end needs that is not the engine and not a widget: the one config file and
//! its writers, command parsing and dispatch, background workers, MIDI attachment and the session
//! state they feed. Front-ends (the terminal UI, a future Flutter shell) only send user actions and
//! render what this crate exposes.

pub mod browser;
pub mod command;
pub mod completer;
pub mod config;
pub mod intent;
pub mod midi;
pub mod notices;
pub mod response;
pub mod session;
pub mod state;
pub mod waveform;

// `crate::profile` is the path every module already speaks; keep it as a re-export rather than a
// second module.
pub use config::profile;

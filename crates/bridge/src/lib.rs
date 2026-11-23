//! Flutter Rust Bridge facade for Pipefader.
//!
//! This crate is the only place that knows about `flutter_rust_bridge`. The application
//! layer (`app`) and the engine (`audio`) stay free of FFI concerns, and the bridge owns the
//! one session thread that may hold `!Send` objects such as `midir` connections.

pub mod api;
mod frb_generated;
mod session;

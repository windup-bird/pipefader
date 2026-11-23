//! Re-export of the shared device rows.
//!
//! The list a device picker offers is not terminal-specific: the Flutter menu asks the same
//! "hardware or channel pair" question. The model lives in `app::devices` so both front-ends agree.

pub use app::devices::*;

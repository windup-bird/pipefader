//! Terminal rendering of the application's preferences.
//!
//! The parser and the persisted model live in `app::config::preference`; this module only keeps the
//! `ratatui::style::Color` representation the TUI draws with, and converts at load. Keeping the two
//! apart is what lets the application layer stay free of terminal dependencies.

use ratatui::style::Color;

use app::config::preference as source;

pub use app::config::preference::{DisplaySettings, LibrarySettings, WaveformBackend};

/// Where the TUI looks for preferences when no config path was handed to the session.
pub const DEFAULT_PATH: &str = "profile/config.toml";

/// The three waveform band colours, in the terminal's colour type.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct WaveformColors {
    pub low: Color,
    pub mid: Color,
    pub high: Color,
}

impl Default for WaveformColors {
    fn default() -> Self {
        Self {
            low: Color::Blue,
            mid: Color::Green,
            high: Color::White,
        }
    }
}

/// Everything the waveform view needs from preferences.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct WaveformSettings {
    pub backend: WaveformBackend,
    pub refresh_hz: u16,
    pub cell: Option<(u16, u16)>,
    pub low_hz: u16,
    pub high_hz: u16,
    pub colors: WaveformColors,
}

impl Default for WaveformSettings {
    fn default() -> Self {
        Self {
            backend: WaveformBackend::Auto,
            refresh_hz: 60,
            cell: None,
            low_hz: 200,
            high_hz: 4_000,
            colors: WaveformColors::default(),
        }
    }
}

/// The colour slots the whole TUI is drawn from.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Theme {
    pub accent: Color,
    pub dim: Color,
    pub text: Color,
    pub error: Color,
    pub warn: Color,
    pub pad: Color,
}

impl Default for Theme {
    fn default() -> Self {
        Self {
            accent: Color::Cyan,
            dim: Color::DarkGray,
            text: Color::White,
            error: Color::Red,
            warn: Color::Yellow,
            pad: Color::Rgb(64, 96, 128),
        }
    }
}

/// The TUI's preferences, with rendering colours converted once at load.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Preference {
    pub waveform: WaveformSettings,
    pub library: LibrarySettings,
    pub display: DisplaySettings,
    pub theme: Theme,
}

impl From<source::Preference> for Preference {
    fn from(preference: source::Preference) -> Self {
        Self {
            waveform: WaveformSettings {
                backend: preference.waveform.backend,
                refresh_hz: preference.waveform.refresh_hz,
                cell: preference.waveform.cell,
                low_hz: preference.waveform.low_hz,
                high_hz: preference.waveform.high_hz,
                colors: WaveformColors {
                    low: color(preference.waveform.colors.low),
                    mid: color(preference.waveform.colors.mid),
                    high: color(preference.waveform.colors.high),
                },
            },
            library: preference.library,
            display: preference.display,
            theme: Theme {
                accent: color(preference.theme.accent),
                dim: color(preference.theme.dim),
                text: color(preference.theme.text),
                error: color(preference.theme.error),
                warn: color(preference.theme.warn),
                pad: color(preference.theme.pad),
            },
        }
    }
}

fn color(color: source::Color) -> Color {
    match color {
        source::Color::Reset => Color::Reset,
        source::Color::Black => Color::Black,
        source::Color::Red => Color::Red,
        source::Color::Green => Color::Green,
        source::Color::Yellow => Color::Yellow,
        source::Color::Blue => Color::Blue,
        source::Color::Magenta => Color::Magenta,
        source::Color::Cyan => Color::Cyan,
        source::Color::Gray => Color::Gray,
        source::Color::DarkGray => Color::DarkGray,
        source::Color::LightRed => Color::LightRed,
        source::Color::LightGreen => Color::LightGreen,
        source::Color::LightYellow => Color::LightYellow,
        source::Color::LightBlue => Color::LightBlue,
        source::Color::LightMagenta => Color::LightMagenta,
        source::Color::LightCyan => Color::LightCyan,
        source::Color::White => Color::White,
        source::Color::Rgb(red, green, blue) => Color::Rgb(red, green, blue),
    }
}

/// Reads a preference file. A missing file is not an error: the defaults apply.
pub fn load(path: &str) -> Result<(Preference, Vec<String>), String> {
    source::load(path).map(|(preference, notes)| (preference.into(), notes))
}

/// Parses the file body. Unknown keys are notes, not failures.
#[cfg(test)]
pub fn parse(text: &str) -> Result<(Preference, Vec<String>), String> {
    source::parse(text).map(|(preference, notes)| (preference.into(), notes))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_app_parser_converts_to_the_terminal_colours() {
        let (preference, notes) = parse(
            r##"
            [theme]
            accent = "#00e5ff"
            pad = "#204060"
            [waveform]
            low = "#010203"
            "##,
        )
        .unwrap();
        assert!(notes.is_empty(), "{notes:?}");
        assert_eq!(preference.theme.accent, Color::Rgb(0x00, 0xE5, 0xFF));
        assert_eq!(preference.theme.pad, Color::Rgb(0x20, 0x40, 0x60));
        assert_eq!(preference.waveform.colors.low, Color::Rgb(1, 2, 3));
    }
}

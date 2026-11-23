//! Renderer-independent waveform computation shared by the terminal and the GUI.
//!
//! The two front-ends draw very differently (braille cells or a Kitty image in
//! the terminal, a Canvas in Flutter), but they must agree on what a column
//! means, where a cue lands and what colour a band is. This module owns that
//! contract: a viewport in, a frame of peak columns and marker columns out, plus
//! the palette derived from the one config file.

use library::{StereoPeaks, Waveform};
use protocol::{BeatGrid, DeckState, HOT_CUE_SLOTS};

use crate::config::preference::{Color, WaveformColors};

/// Straight RGB. `ratatui::style::Color` and Flutter's `Color` are adapters.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Rgb {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl Rgb {
    pub const fn new(r: u8, g: u8, b: u8) -> Self {
        Self { r, g, b }
    }

    /// `0xRRGGBB`, the compact form the bridge sends to Dart.
    pub const fn argb(self) -> u32 {
        0xFF00_0000 | ((self.r as u32) << 16) | ((self.g as u32) << 8) | self.b as u32
    }

    pub fn from_preference(color: Color) -> Self {
        let (r, g, b) = match color {
            Color::Black => (0, 0, 0),
            Color::Red => (255, 0, 0),
            Color::Green => (0, 255, 0),
            Color::Yellow => (255, 255, 0),
            Color::Blue => (0, 0, 255),
            Color::Magenta => (255, 0, 255),
            Color::Cyan => (0, 255, 255),
            Color::Gray => (128, 128, 128),
            Color::DarkGray => (64, 64, 64),
            Color::LightRed => (255, 128, 128),
            Color::LightGreen => (128, 255, 128),
            Color::LightYellow => (255, 255, 128),
            Color::LightBlue => (128, 128, 255),
            Color::LightMagenta => (255, 128, 255),
            Color::LightCyan => (128, 255, 255),
            Color::White => (255, 255, 255),
            Color::Rgb(r, g, b) => (r, g, b),
            Color::Reset => (255, 255, 255),
        };
        Self::new(r, g, b)
    }
}

/// The exact colours a waveform frame is drawn with. Band colours come from
/// `[preference.waveform]`; the furniture colours are the terminal's fixed set,
/// now shared so the GUI cannot drift.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct WavePalette {
    pub low: Rgb,
    pub mid: Rgb,
    pub high: Rgb,
    pub beat: Rgb,
    pub bar: Rgb,
    pub loop_wash: Rgb,
    pub center: Rgb,
    pub playhead: Rgb,
    pub memory_cue: Rgb,
    pub hot_cues: [Rgb; HOT_CUE_SLOTS],
}

impl Default for WavePalette {
    fn default() -> Self {
        Self::from_band_colors(
            Rgb::new(0, 0, 255),
            Rgb::new(0, 255, 0),
            Rgb::new(255, 255, 255),
        )
    }
}

impl WavePalette {
    pub fn from_band_colors(low: Rgb, mid: Rgb, high: Rgb) -> Self {
        Self {
            low,
            mid,
            high,
            beat: Rgb::new(110, 110, 110),
            bar: Rgb::new(160, 160, 160),
            loop_wash: Rgb::new(76, 76, 76),
            center: Rgb::new(80, 80, 80),
            playhead: Rgb::new(255, 40, 40),
            memory_cue: Rgb::new(245, 245, 245),
            hot_cues: [
                Rgb::new(255, 72, 72),
                Rgb::new(255, 160, 64),
                Rgb::new(255, 232, 64),
                Rgb::new(80, 255, 96),
                Rgb::new(64, 240, 240),
                Rgb::new(80, 160, 255),
                Rgb::new(200, 96, 255),
                Rgb::new(255, 96, 200),
            ],
        }
    }

    pub fn from_preference(colors: &WaveformColors) -> Self {
        Self::from_band_colors(
            Rgb::from_preference(colors.low),
            Rgb::from_preference(colors.mid),
            Rgb::from_preference(colors.high),
        )
    }
}

/// One scrolling viewport. Width is the renderer's column count: braille dots
/// in the TUI, logical pixels in Flutter.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct WaveViewport {
    pub width: u32,
    pub frames_per_pixel: f64,
    pub playhead: u64,
}

impl WaveViewport {
    pub fn start_frame(self) -> f64 {
        self.playhead as f64 - f64::from(self.width) / 2.0 * self.frames_per_pixel.max(1.0)
    }

    fn column(self, frame: f64) -> f64 {
        f64::from(self.width) / 2.0
            + (frame - self.playhead as f64) / self.frames_per_pixel.max(1.0)
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct WaveMarkers {
    pub beats: Vec<u32>,
    pub bars: Vec<u32>,
    pub loop_range: Option<(u32, u32)>,
    pub loop_armed: Option<u32>,
    pub cue: Option<u32>,
    pub hot_cues: Vec<(u8, u32)>,
}

impl WaveMarkers {
    pub fn is_empty(&self) -> bool {
        self.beats.is_empty()
            && self.bars.is_empty()
            && self.loop_range.is_none()
            && self.loop_armed.is_none()
            && self.cue.is_none()
            && self.hot_cues.is_empty()
    }
}

/// The beat grid and transport furniture projected into columns, without the
/// peak columns. The bridge's 60Hz tick uses this when it only needs markers.
pub fn markers(grid: Option<&BeatGrid>, state: &DeckState, viewport: WaveViewport) -> WaveMarkers {
    let mut out = WaveMarkers::default();
    let width = viewport.width;
    let clamp = |x: f64| -> Option<u32> {
        if !x.is_finite() || x < 0.0 || x > f64::from(width) {
            None
        } else {
            Some(x.round() as u32)
        }
    };

    if let Some(grid) = grid.filter(|grid| !grid.is_empty()) {
        let start = viewport.start_frame().max(0.0) as u64;
        let end = viewport.playhead as f64 + f64::from(width) / 2.0 * viewport.frames_per_pixel;
        let first = grid.floor_beat(start);
        for beat in (first..).take(512) {
            let frame = grid.frame_at_beat(beat) as f64;
            if frame > end {
                break;
            }
            let Some(x) = clamp(viewport.column(frame)) else {
                continue;
            };
            if beat.is_multiple_of(4) {
                out.bars.push(x);
            } else {
                out.beats.push(x);
            }
        }
    }

    if let Some((start, end)) = state.loop_range {
        // A loop can cover the whole viewport with both ends off-screen; clip
        // each end instead of dropping the wash when neither endpoint is visible.
        let a = viewport.column(start as f64);
        let b = viewport.column(end as f64);
        let lo = a.min(b).clamp(0.0, width as f64) as u32;
        let hi = a.max(b).clamp(0.0, width as f64) as u32;
        if hi > lo {
            out.loop_range = Some((lo, hi));
        }
    }
    if let Some(frame) = state.loop_in_armed {
        out.loop_armed = clamp(viewport.column(frame as f64));
    }
    // As in the TUI, a memory cue at frame 0 is the implicit origin, not a mark.
    if state.cue_frame > 0 {
        out.cue = clamp(viewport.column(state.cue_frame as f64));
    }
    for (slot, cue) in state.hot_cues.iter().enumerate() {
        if let Some(cue) = cue {
            if let Some(x) = clamp(viewport.column(cue.frame as f64)) {
                out.hot_cues.push((slot as u8, x));
            }
        }
    }
    out
}

/// Peak columns plus markers for one viewport.
#[derive(Clone, Debug, PartialEq)]
pub struct WaveFrame {
    pub start_frame: f64,
    pub frames_per_pixel: f64,
    pub columns: Vec<StereoPeaks>,
    pub markers: WaveMarkers,
}

impl WaveFrame {
    pub fn width(&self) -> u32 {
        self.columns.len() as u32
    }

    pub fn is_empty(&self) -> bool {
        self.columns.is_empty() && self.markers.is_empty()
    }
}

/// Projects the waveform pyramid at the viewport's own resolution. This is the
/// step the GUI used to do itself from a fixed 16384-column copy; doing it here
/// keeps the TUI and Flutter on exactly the same sampling grid.
pub fn frame(
    waveform: Option<&Waveform>,
    grid: Option<&BeatGrid>,
    state: &DeckState,
    viewport: WaveViewport,
) -> WaveFrame {
    let width = viewport.width.max(1) as usize;
    let fpp = viewport.frames_per_pixel.max(1.0);
    let start = viewport.start_frame();
    let columns = waveform
        .map(|waveform| waveform.columns(start, fpp, width).collect())
        .unwrap_or_default();
    WaveFrame {
        start_frame: start,
        frames_per_pixel: fpp,
        columns,
        markers: markers(grid, state, viewport),
    }
}

/// One column of the folded, normalised, S-curved overview.
pub type OverviewProfile = [f64; 3];

/// Folds, normalises and curves the whole track into `columns` profiles. Shared
/// by the TUI overview and the GUI overview so both have the same silhouette.
pub fn overview_profiles(
    waveform: Option<&Waveform>,
    total_frames: u64,
    columns: usize,
) -> Vec<OverviewProfile> {
    let columns = columns.max(1);
    let Some(waveform) = waveform.filter(|_| total_frames > 0) else {
        return Vec::new();
    };
    let frames_per_column = total_frames as f64 / columns as f64;
    let mut raw: Vec<OverviewProfile> = Vec::with_capacity(columns);
    for peaks in waveform.columns(0.0, frames_per_column, columns) {
        let fold = |left: u8, right: u8| f64::from(left.max(right)) / 255.0;
        raw.push([
            fold(peaks.left.low, peaks.right.low),
            fold(peaks.left.mid, peaks.right.mid),
            fold(peaks.left.high, peaks.right.high),
        ]);
    }
    let loudest = raw
        .iter()
        .map(|bands| bands[0] + bands[1] + bands[2])
        .fold(0.0f64, f64::max);
    if loudest <= 0.0 {
        return vec![[0.0; 3]; raw.len()];
    }
    raw.into_iter()
        .map(|bands| {
            let sum = bands[0] + bands[1] + bands[2];
            let height = s_curve((sum / loudest).clamp(0.0, 1.0));
            if sum <= 0.0 {
                [0.0; 3]
            } else {
                [
                    height * bands[0] / sum,
                    height * bands[1] / sum,
                    height * bands[2] / sum,
                ]
            }
        })
        .collect()
}

fn s_curve(value: f64) -> f64 {
    value * value * (3.0 - 2.0 * value)
}

#[cfg(test)]
mod tests {
    use super::*;
    use protocol::{DeckState, HOT_CUE_SLOTS};

    fn deck(total: u64, cue: u64) -> DeckState {
        let mut hot_cues = [None; HOT_CUE_SLOTS];
        hot_cues[0] = Some(protocol::HotCue { slot: 0, frame: cue + 10 });
        DeckState {
            deck_id: 0,
            current_frame: cue,
            playing: false,
            total_frames: total,
            bpm: 0.0,
            bpm_at_frame: 0.0,
            key: None,
            virtual_frame: cue,
            loop_range: Some((cue.saturating_sub(100), cue + 100)),
            loop_in_armed: None,
            jump_beats: 8,
            loop_beats: protocol::BeatLen::beats(8),
            tempo: 1.0,
            tempo_fader: 0.0,
            tempo_range: 0.1,
            nudgerate: 0.0,
            playing_rate: 1.0,
            lock: false,
            align: None,
            nudge: 0.0,
            sync_leader: None,
            sync_mode: "free".to_owned(),
            group_bpm: 0.0,
            cue_frame: cue,
            hot_cues,
            vinyl: false,
            keylock: protocol::KeylockMode::On,
            key_shift: 0,
            stems: protocol::StemStatus::default(),
        }
    }

    #[test]
    fn markers_project_into_the_viewport() {
        let state = deck(10_000, 5_000);
        let viewport = WaveViewport {
            width: 100,
            frames_per_pixel: 10.0,
            playhead: 5_000,
        };
        let markers = markers(None, &state, viewport);
        assert_eq!(markers.cue, Some(50));
        assert_eq!(markers.loop_range, Some((40, 60)));
        assert_eq!(markers.hot_cues, vec![(0, 51)]);
    }

    #[test]
    fn a_loop_that_covers_the_viewport_still_washes() {
        let mut state = deck(10_000, 5_000);
        state.loop_range = Some((0, 10_000));
        let markers = markers(
            None,
            &state,
            WaveViewport {
                width: 100,
                frames_per_pixel: 10.0,
                playhead: 5_000,
            },
        );
        assert_eq!(markers.loop_range, Some((0, 100)));
    }

    #[test]
    fn a_palette_uses_the_configured_bands_and_fixed_furniture() {
        let palette = WavePalette::from_band_colors(Rgb::new(1, 2, 3), Rgb::new(4, 5, 6), Rgb::new(7, 8, 9));
        assert_eq!(palette.low, Rgb::new(1, 2, 3));
        assert_eq!(palette.beat, Rgb::new(110, 110, 110));
        assert_eq!(palette.low.argb(), 0xFF000000 | (1 << 16) | (2 << 8) | 3);
    }

    #[test]
    fn overview_profiles_fold_and_normalise() {
        use library::{BandPeaks, StereoPeaks, Waveform};
        let buckets = vec![
            StereoPeaks {
                left: BandPeaks { low: 255, mid: 0, high: 0 },
                right: BandPeaks { low: 255, mid: 0, high: 0 },
            },
            StereoPeaks {
                left: BandPeaks { low: 0, mid: 0, high: 0 },
                right: BandPeaks { low: 0, mid: 0, high: 0 },
            },
        ];
        let waveform = Waveform::from_buckets(buckets, 256, 512);
        let profiles = overview_profiles(Some(&waveform), 512, 2);
        assert_eq!(profiles.len(), 2);
        assert!(profiles[0][0] > 0.0);
        assert_eq!(profiles[1], [0.0; 3]);
    }
}

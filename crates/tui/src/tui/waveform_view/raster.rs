//! The shared palette-indexed rasteriser for the scrolling waveform.
//!
//! The projection itself lives in `app::waveform`; this module only turns the
//! renderer-independent frame into the small palette buffer the Kitty encoder
//! transmits. Nothing here knows about analysis, beat grids or zoom.

use app::waveform::{WaveFrame, WavePalette};
use library::StereoPeaks;
use protocol::HOT_CUE_SLOTS;

#[cfg(test)]
use crate::preference::WaveformColors;

/// Palette slots. Shared by both encoders so a pixel means the same thing everywhere.
pub const BG: u8 = 0;
pub const LOW: u8 = 1;
pub const MID: u8 = 2;
pub const HIGH: u8 = 3;
pub const CENTER: u8 = 4;
pub const BEAT: u8 = 5;
pub const BAR: u8 = 6;
pub const PLAYHEAD: u8 = 7;
pub const LOOP: u8 = 8;
pub const MEMORY: u8 = 9;
pub const HOT0: u8 = 10;
pub const PALETTE_LEN: usize = 18;

/// The cue/loop furniture drawn over the waveform. Frames are source frames.
/// Kept for the Kitty strip cache key; the raster itself takes the projected
/// columns from [`WaveFrame`].
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Overlay {
    pub loop_range: Option<(u64, u64)>,
    pub memory_cue: Option<u64>,
    pub hot_cues: [Option<u64>; HOT_CUE_SLOTS],
}

/// Palette derived from the application's one waveform palette.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Palette {
    /// RGBA for Kitty; index 0 is transparent.
    pub rgba: [[u8; 4]; PALETTE_LEN],
}

impl Palette {
    pub fn from_palette(palette: &WavePalette) -> Self {
        let mut rgba = [[0u8, 0, 0, 255]; PALETTE_LEN];
        rgba[usize::from(BG)] = [0, 0, 0, 0];
        let mut set = |slot: u8, color: app::waveform::Rgb| {
            rgba[usize::from(slot)] = [color.r, color.g, color.b, 255];
        };
        set(LOW, palette.low);
        set(MID, palette.mid);
        set(HIGH, palette.high);
        set(CENTER, palette.center);
        set(BEAT, palette.beat);
        set(BAR, palette.bar);
        set(PLAYHEAD, palette.playhead);
        set(LOOP, palette.loop_wash);
        set(MEMORY, palette.memory_cue);
        for (slot, color) in palette.hot_cues.iter().enumerate() {
            set(HOT0 + slot as u8, *color);
        }
        Self { rgba }
    }

    /// Compatibility for the existing Kitty tests and callers that still hold
    /// terminal colours. New code should use [`Palette::from_palette`].
    #[cfg(test)]
    pub fn from_colors(colors: WaveformColors) -> Self {
        let bytes = |color: ratatui::style::Color| match color {
            ratatui::style::Color::Rgb(r, g, b) => [r, g, b, 255],
            ratatui::style::Color::Black => [0, 0, 0, 255],
            ratatui::style::Color::Red => [255, 0, 0, 255],
            ratatui::style::Color::Green => [0, 255, 0, 255],
            ratatui::style::Color::Yellow => [255, 255, 0, 255],
            ratatui::style::Color::Blue => [0, 0, 255, 255],
            ratatui::style::Color::Magenta => [255, 0, 255, 255],
            ratatui::style::Color::Cyan => [0, 255, 255, 255],
            ratatui::style::Color::Gray => [128, 128, 128, 255],
            ratatui::style::Color::DarkGray => [64, 64, 64, 255],
            ratatui::style::Color::LightRed => [255, 128, 128, 255],
            ratatui::style::Color::LightGreen => [128, 255, 128, 255],
            ratatui::style::Color::LightYellow => [255, 255, 128, 255],
            ratatui::style::Color::LightBlue => [128, 128, 255, 255],
            ratatui::style::Color::LightMagenta => [255, 128, 255, 255],
            ratatui::style::Color::LightCyan => [128, 255, 255, 255],
            ratatui::style::Color::White => [255, 255, 255, 255],
            _ => [255, 255, 255, 255],
        };
        let palette = WavePalette::from_band_colors(
            rgb(colors.low),
            rgb(colors.mid),
            rgb(colors.high),
        );
        let mut out = Self::from_palette(&palette);
        out.rgba[usize::from(LOW)] = bytes(colors.low);
        out.rgba[usize::from(MID)] = bytes(colors.mid);
        out.rgba[usize::from(HIGH)] = bytes(colors.high);
        out
    }
}

#[cfg(test)]
fn rgb(color: ratatui::style::Color) -> app::waveform::Rgb {
    let (r, g, b) = match color {
        ratatui::style::Color::Rgb(r, g, b) => (r, g, b),
        ratatui::style::Color::Black => (0, 0, 0),
        ratatui::style::Color::Red => (255, 0, 0),
        ratatui::style::Color::Green => (0, 255, 0),
        ratatui::style::Color::Yellow => (255, 255, 0),
        ratatui::style::Color::Blue => (0, 0, 255),
        ratatui::style::Color::Magenta => (255, 0, 255),
        ratatui::style::Color::Cyan => (0, 255, 255),
        ratatui::style::Color::Gray => (128, 128, 128),
        ratatui::style::Color::DarkGray => (64, 64, 64),
        ratatui::style::Color::LightRed => (255, 128, 128),
        ratatui::style::Color::LightGreen => (128, 255, 128),
        ratatui::style::Color::LightYellow => (255, 255, 128),
        ratatui::style::Color::LightBlue => (128, 128, 255),
        ratatui::style::Color::LightMagenta => (255, 128, 255),
        ratatui::style::Color::LightCyan => (128, 255, 255),
        ratatui::style::Color::White => (255, 255, 255),
        _ => (255, 255, 255),
    };
    app::waveform::Rgb::new(r, g, b)
}

/// Palette-indexed pixels, row-major.
pub struct Raster {
    pub width: u32,
    pub height: u32,
    pub indices: Vec<u8>,
}

impl Raster {
    pub fn rgba(&self, palette: &Palette) -> Vec<u8> {
        let mut out = Vec::with_capacity(self.indices.len() * 4);
        for index in &self.indices {
            out.extend_from_slice(&palette.rgba[usize::from(*index)]);
        }
        out
    }
}

/// Draws one shared frame into `width × height` pixels. The frame's columns must
/// already sit on the same `frames_per_pixel` grid as the viewport; width is the
/// frame's column count for the strip being rendered.
pub fn rasterize_frame(
    frame: &WaveFrame,
    width: u32,
    height: u32,
    include_playhead: bool,
) -> Raster {
    let width = width.max(1);
    let height = height.max(1);
    let mut indices = vec![BG; (width as usize) * (height as usize)];
    let center_y = height / 2;
    let center_x = width / 2;

    if let Some((start, end)) = frame.markers.loop_range {
        for x in start..end.min(width) {
            for y in 0..height {
                indices[(y as usize) * (width as usize) + x as usize] = LOOP;
            }
        }
    }
    let mut draw_beat = |x: u32, color: u8| {
        if x < width {
            for y in 0..height {
                indices[(y as usize) * (width as usize) + x as usize] = color;
            }
        }
    };
    for &x in &frame.markers.beats {
        draw_beat(x, BEAT);
    }
    for &x in &frame.markers.bars {
        draw_beat(x, BAR);
    }

    for x in 0..width {
        indices[(center_y as usize) * (width as usize) + x as usize] = CENTER;
    }

    for (index, peaks) in frame.columns.iter().take(width as usize).enumerate() {
        draw_stereo_column(&mut indices, width, height, center_y, index as u32, *peaks);
    }

    if let Some(x) = frame.markers.cue {
        draw_cue(&mut indices, width, height, x, MEMORY, 3);
    }
    for &(slot, x) in &frame.markers.hot_cues {
        draw_cue(&mut indices, width, height, x, HOT0 + slot, 4);
    }

    if include_playhead {
        for y in 0..height {
            indices[(y as usize) * (width as usize) + center_x as usize] = PLAYHEAD;
        }
    }

    Raster {
        width,
        height,
        indices,
    }
}

fn draw_cue(
    indices: &mut [u8],
    width: u32,
    height: u32,
    x: u32,
    color: u8,
    thickness: u32,
) {
    let half = thickness / 2;
    let start = x.saturating_sub(half);
    let end = (x + half + 1).min(width);
    for line_x in start..end {
        for y in 0..height {
            indices[(y as usize) * (width as usize) + line_x as usize] = color;
        }
    }
}

fn draw_stereo_column(
    indices: &mut [u8],
    width: u32,
    height: u32,
    center_y: u32,
    x: u32,
    peaks: StereoPeaks,
) {
    let up = center_y;
    let down = height - center_y;
    for (band, color) in [
        (peaks.left.low, LOW),
        (peaks.left.mid, MID),
        (peaks.left.high, HIGH),
    ] {
        draw_band(indices, width, center_y, x, up, true, band, color);
    }
    for (band, color) in [
        (peaks.right.low, LOW),
        (peaks.right.mid, MID),
        (peaks.right.high, HIGH),
    ] {
        draw_band(indices, width, center_y, x, down, false, band, color);
    }
}

#[allow(clippy::too_many_arguments)]
fn draw_band(
    indices: &mut [u8],
    width: u32,
    center_y: u32,
    x: u32,
    extent: u32,
    upward: bool,
    amplitude: u8,
    color: u8,
) {
    let length = (f64::from(amplitude) / 255.0 * f64::from(extent)).round() as u32;
    for offset in 0..length {
        let y = if upward {
            if offset >= center_y {
                break;
            }
            center_y - 1 - offset
        } else {
            let y = center_y + offset;
            if y >= center_y + extent {
                break;
            }
            y
        };
        indices[(y as usize) * (width as usize) + x as usize] = color;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use app::waveform::{WaveMarkers, WavePalette};
    use library::BandPeaks;

    fn frame(columns: Vec<StereoPeaks>, markers: WaveMarkers) -> WaveFrame {
        WaveFrame {
            start_frame: 0.0,
            frames_per_pixel: 1.0,
            columns,
            markers,
        }
    }

    fn stereo(left: u8, right: u8) -> StereoPeaks {
        StereoPeaks {
            left: BandPeaks {
                low: left,
                mid: left,
                high: left,
            },
            right: BandPeaks {
                low: right,
                mid: right,
                high: right,
            },
        }
    }

    #[test]
    fn loop_and_cues_are_drawn_over_the_waveform() {
        let frame = frame(
            vec![stereo(0, 0); 21],
            WaveMarkers {
                loop_range: Some((4, 8)),
                cue: Some(10),
                hot_cues: vec![(0, 20)],
                ..WaveMarkers::default()
            },
        );
        let image = rasterize_frame(&frame, 21, 13, false);
        assert!((0..21)
            .any(|x| (0..13).any(|y| { image.indices[(y * image.width + x) as usize] == LOOP })));
        assert_eq!(image.indices[(6 * image.width + 10) as usize], MEMORY);
        assert_eq!(image.indices[(6 * image.width + 20) as usize], HOT0);
    }

    #[test]
    fn left_paints_above_and_right_below_the_centre() {
        let image = rasterize_frame(&frame(vec![stereo(255, 0)], WaveMarkers::default()), 21, 12, false);
        let center = image.height / 2;
        let left = (0..center).any(|y| {
            (0..image.width).any(|x| image.indices[(y * image.width + x) as usize] != BG)
        });
        let right = (center + 1..image.height).any(|y| {
            (0..image.width).any(|x| image.indices[(y * image.width + x) as usize] != BG)
        });
        assert!(left, "left channel should paint above the centre");
        assert!(!right, "right channel is empty");
    }

    #[test]
    fn the_palette_uses_the_application_colours() {
        let palette = Palette::from_palette(&WavePalette::default());
        assert_eq!(palette.rgba[usize::from(LOW)], [0, 0, 255, 255]);
        assert_eq!(palette.rgba[usize::from(MID)], [0, 255, 0, 255]);
        assert_eq!(palette.rgba[usize::from(HIGH)], [255, 255, 255, 255]);
    }
}

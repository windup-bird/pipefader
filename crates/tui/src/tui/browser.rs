//! Terminal rendering of the application browser.
//!
//! The model (columns, loaded tracks, selection) lives in `::app::browser`; this module owns the
//! ratatui layout and hit-testing. `Deref` keeps the model's fields and methods readable from the
//! renderer without duplicating them.

use library::TrackRow;
use protocol::KeyFormat;
use ratatui::layout::Rect;
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span, Text};
use ratatui::widgets::{Block, Borders, Paragraph};
use ratatui::Frame;

use crate::tui::text;
use ::app::response::time;

pub use ::app::browser::{Column, Focus};

/// Where the last render put the panes and how far each one is scrolled. Mouse handling reads this
/// instead of duplicating the layout maths.
#[derive(Clone, Debug, Default)]
pub struct BrowserLayout {
    pub left1: Rect,
    pub left2: Rect,
    pub tracks: Rect,
    /// Entry index for each rendered visual line (list names may wrap).
    pub left1_lines: Vec<usize>,
    pub left2_lines: Vec<usize>,
    pub tracks_start: usize,
}

/// Terminal cell to anchor the deck chooser for the selected track.
pub fn track_anchor(browser: &::app::browser::Browser, layout: &BrowserLayout) -> (u16, u16) {
    let row = browser.track_selected.saturating_sub(layout.tracks_start) as u16;
    (
        layout.tracks.x.saturating_add(2),
        layout.tracks.y.saturating_add(1).saturating_add(row),
    )
}

/// The visible list row under a terminal cell, as `(column index, entry index)`.
pub fn hit_column(
    browser: &::app::browser::Browser,
    layout: &BrowserLayout,
    x: u16,
    y: u16,
) -> Option<(usize, usize)> {
    let len = browser.columns.len();
    let candidates = [
        (len.checked_sub(2), layout.left1, &layout.left1_lines),
        (len.checked_sub(1), layout.left2, &layout.left2_lines),
    ];
    for (column, rect, lines) in candidates {
        let Some(column) = column else { continue };
        if !contains(rect, x, y) {
            continue;
        }
        let line = y.saturating_sub(rect.y) as usize;
        if let Some(entry) = lines.get(line) {
            if *entry < browser.columns[column].entries.len() {
                return Some((column, *entry));
            }
        }
    }
    None
}

/// The visible track row under a terminal cell.
pub fn hit_track(
    browser: &::app::browser::Browser,
    layout: &BrowserLayout,
    x: u16,
    y: u16,
) -> Option<usize> {
    let rect = layout.tracks;
    if !contains(rect, x, y) || y <= rect.y {
        return None;
    }
    let row = layout.tracks_start + (y - rect.y - 1) as usize;
    (row < browser.tracks.len()).then_some(row)
}

/// Draws the browser into `area`. `focused` is true while the browser is the command target.
pub fn render(
    frame: &mut Frame,
    area: Rect,
    browser: &mut ::app::browser::Browser,
    layout: &mut BrowserLayout,
    focused: bool,
) {
    if area.width == 0 || area.height == 0 {
        return;
    }
    let border = if focused {
        Color::Cyan
    } else {
        Color::DarkGray
    };
    let block = Block::bordered()
        .border_style(Style::default().fg(border))
        .title(" browser ");
    let inner = block.inner(area);
    frame.render_widget(block, area);
    if inner.width == 0 || inner.height == 0 {
        return;
    }

    let parts = split_panes(inner);
    layout.left1 = parts[0];
    layout.left2 = parts[2];
    layout.tracks = parts[4];
    // The column borrows end inside each block, so the layout fields can be written afterwards.
    let left1_lines = {
        let left1 = browser
            .columns
            .len()
            .checked_sub(2)
            .and_then(|index| browser.columns.get(index));
        render_column(frame, parts[0], left1, false, focused, border)
    };
    render_divider(frame, parts[1], border);
    let left2_lines = {
        let left2 = browser.columns.last();
        render_column(
            frame,
            parts[2],
            left2,
            browser.focus == Focus::Lists,
            focused,
            border,
        )
    };
    layout.left1_lines = left1_lines;
    layout.left2_lines = left2_lines;
    render_divider(frame, parts[3], border);
    layout.tracks_start = render_tracks(
        frame,
        parts[4],
        browser,
        browser.focus == Focus::Tracks,
        focused,
    );
}

/// Two list columns : tracks = 1 : 1 : 2, with one-cell separators. The result always adds up to
/// `inner.width` so a narrow terminal cannot push the right column off screen.
fn split_panes(inner: Rect) -> [Rect; 5] {
    let dividers = inner.width.min(2);
    let usable = inner.width.saturating_sub(dividers);
    if usable == 0 {
        return [
            Rect::new(inner.x, inner.y, 0, inner.height),
            Rect::new(inner.x, inner.y, dividers.min(1), inner.height),
            Rect::new(inner.x + dividers.min(1), inner.y, 0, inner.height),
            Rect::new(
                inner.x + dividers.min(1),
                inner.y,
                dividers.saturating_sub(1),
                inner.height,
            ),
            Rect::new(inner.x + dividers, inner.y, 0, inner.height),
        ];
    }
    let first = usable * 15 / 100;
    let second = usable * 15 / 100;
    let tracks = usable - first - second;
    let x0 = inner.x;
    let x1 = x0 + first;
    let x2 = x1 + 1;
    let x3 = x2 + second;
    let x4 = x3 + 1;
    [
        Rect::new(x0, inner.y, first, inner.height),
        Rect::new(x1, inner.y, 1.min(dividers), inner.height),
        Rect::new(x2, inner.y, second, inner.height),
        Rect::new(x3, inner.y, 1.min(dividers.saturating_sub(1)), inner.height),
        Rect::new(x4, inner.y, tracks, inner.height),
    ]
}

fn render_divider(frame: &mut Frame, area: Rect, colour: Color) {
    if area.width == 0 || area.height == 0 {
        return;
    }
    frame.render_widget(
        Block::default()
            .borders(Borders::LEFT)
            .border_style(Style::default().fg(colour)),
        area,
    );
}

fn render_column(
    frame: &mut Frame,
    area: Rect,
    column: Option<&Column>,
    active: bool,
    browser_focused: bool,
    border: Color,
) -> Vec<usize> {
    let Some(column) = column else {
        return Vec::new();
    };
    if area.width == 0 || area.height == 0 {
        return Vec::new();
    }
    let height = area.height as usize;
    let width = area.width as usize;
    if column.entries.is_empty() {
        frame.render_widget(
            Paragraph::new(Line::styled(
                " (empty)",
                Style::default().fg(Color::DarkGray),
            )),
            area,
        );
        return Vec::new();
    }

    // Build every visual line first: a long playlist name wraps, and a continuation line keeps the
    // icon's indent so the selection still reads as one block.
    let mut blocks: Vec<Vec<(bool, String, String)>> = Vec::with_capacity(column.entries.len());
    for entry in &column.entries {
        let icon = entry.icon();
        let prefix = format!("{icon} ");
        let indent = " ".repeat(text::width(&prefix));
        let budget = width.saturating_sub(text::width(&prefix)).max(1);
        let label = entry.label();
        let wrapped = text::wrap_to_width(&label, budget);
        let mut lines = Vec::with_capacity(wrapped.len());
        for (index, part) in wrapped.into_iter().enumerate() {
            if index == 0 {
                lines.push((true, prefix.clone(), part));
            } else {
                lines.push((false, indent.clone(), part));
            }
        }
        blocks.push(lines);
    }

    let selected = column.selected.min(column.entries.len() - 1);
    let selected_start = blocks.iter().take(selected).map(Vec::len).sum::<usize>();
    let selected_end = selected_start + blocks[selected].len();
    let start_line = selected_end.saturating_sub(height);
    let mut lines = Vec::with_capacity(height);
    let mut visible_entries = Vec::with_capacity(height);
    let mut line_number = 0usize;
    for (entry_index, block) in blocks.iter().enumerate() {
        for (first, prefix, label) in block {
            if line_number < start_line {
                line_number += 1;
                continue;
            }
            if lines.len() >= height {
                break;
            }
            let selected = entry_index == column.selected;
            let style = if selected {
                if active && browser_focused {
                    Style::default()
                        .fg(Color::Black)
                        .bg(Color::Cyan)
                        .add_modifier(Modifier::BOLD)
                } else {
                    Style::default()
                        .fg(Color::White)
                        .bg(Color::DarkGray)
                        .add_modifier(Modifier::BOLD)
                }
            } else {
                Style::default()
            };
            let icon_style = if selected {
                style
            } else if *first {
                Style::default().fg(border)
            } else {
                Style::default()
            };
            lines.push(Line::from(vec![
                Span::styled(prefix.clone(), icon_style),
                Span::styled(label.clone(), style),
            ]));
            visible_entries.push(entry_index);
            line_number += 1;
        }
        if lines.len() >= height {
            break;
        }
    }
    frame.render_widget(Paragraph::new(Text::from(lines)), area);
    visible_entries
}

fn render_tracks(
    frame: &mut Frame,
    area: Rect,
    browser: &::app::browser::Browser,
    active: bool,
    browser_focused: bool,
) -> usize {
    if area.width == 0 || area.height == 0 {
        return 0;
    }
    let widths = track_widths(area.width as usize);
    let start = if browser.tracks.is_empty() {
        0
    } else {
        let height = area.height.saturating_sub(1) as usize;
        window_start(browser.track_selected, browser.tracks.len(), height)
    };
    let header_style = if active {
        Style::default()
            .fg(Color::Cyan)
            .add_modifier(Modifier::BOLD)
    } else {
        Style::default()
            .fg(Color::DarkGray)
            .add_modifier(Modifier::BOLD)
    };
    let mut lines = vec![track_cells(
        &["title", "artist", "bpm", "key", "dur"],
        &widths,
        header_style,
    )];
    if browser.tracks.is_empty() {
        lines.push(Line::styled(
            " (empty)",
            Style::default().fg(Color::DarkGray),
        ));
    } else {
        let height = area.height.saturating_sub(1) as usize;
        for (index, track) in browser.tracks.iter().enumerate().skip(start).take(height) {
            let selected = index == browser.track_selected;
            let style = if selected {
                if active && browser_focused {
                    Style::default()
                        .fg(Color::Black)
                        .bg(Color::Cyan)
                        .add_modifier(Modifier::BOLD)
                } else {
                    Style::default()
                        .fg(Color::White)
                        .bg(Color::DarkGray)
                        .add_modifier(Modifier::BOLD)
                }
            } else {
                Style::default()
            };
            lines.push(track_line(track, &widths, style, browser.key_format));
        }
    }
    frame.render_widget(Paragraph::new(Text::from(lines)), area);
    start
}

/// Title : artist : bpm : key : duration = approximately 55 : 45 of the flexible remainder, with
/// compact fixed-ish fields. The last column takes the remainder so the row never overflows.
fn track_widths(width: usize) -> [usize; 5] {
    const GAP: usize = 2;
    let usable = width.saturating_sub(GAP * 4);
    if usable < 24 {
        return [width, 0, 0, 0, 0];
    }
    let bpm = (usable * 8 / 100).clamp(3, 5);
    let key = (usable * 8 / 100).clamp(3, 5);
    let dur = (usable * 14 / 100).clamp(6, 9);
    let rest = usable.saturating_sub(bpm + key + dur);
    let title = (rest * 55 / 100).max(1);
    let artist = rest.saturating_sub(title);
    [title, artist, bpm, key, dur]
}

fn track_line(
    track: &TrackRow,
    widths: &[usize; 5],
    style: Style,
    key_format: KeyFormat,
) -> Line<'static> {
    let bpm = track
        .bpm
        .map(|bpm| format!("{bpm:.1}"))
        .unwrap_or_else(|| "--".to_owned());
    let key = track
        .key
        .map(|key| key.format(key_format))
        .unwrap_or_else(|| "--".to_owned());
    let duration = if track.duration_frames == 0 {
        "--:--".to_owned()
    } else {
        time(track.duration_frames, track.sample_rate)
    };
    track_cells(
        &[
            &track.title,
            track.artist.as_deref().unwrap_or("--"),
            &bpm,
            &key,
            &duration,
        ],
        widths,
        style,
    )
}

fn track_cells(values: &[&str; 5], widths: &[usize; 5], style: Style) -> Line<'static> {
    let mut spans = Vec::new();
    for (value, width) in values.iter().zip(widths) {
        if *width == 0 {
            continue;
        }
        if !spans.is_empty() {
            spans.push(Span::raw("  "));
        }
        spans.push(Span::styled(text::pad_to_width(value, *width), style));
    }
    Line::from(spans)
}

fn contains(rect: Rect, x: u16, y: u16) -> bool {
    x >= rect.x && x < rect.x + rect.width && y >= rect.y && y < rect.y + rect.height
}

fn window_start(selected: usize, len: usize, height: usize) -> usize {
    if height == 0 || len <= height {
        return 0;
    }
    selected.saturating_sub(height - 1)
}

#[cfg(test)]
mod tests {
    use super::*;
    use ::app::browser::{Browser, Entry};
    use library::{LibraryDb, Playlist, Source, SourceKind};

    #[test]
    fn usb_sources_use_the_usb_icon_and_name_their_format() {
        let source = Source {
            id: 1,
            kind: SourceKind::Rekordbox,
            origin: library::SourceOrigin::Usb,
            name: "stick".to_owned(),
            root: std::path::PathBuf::from("/run/media/stick"),
            last_scan_at: None,
        };
        let entry = Entry::Source(source);
        assert_eq!(entry.icon(), "🔌");
        assert_eq!(entry.label(), "stick (onelibrary)");
    }

    #[test]
    fn local_sources_use_the_computer_icon() {
        let source = Source {
            id: 1,
            kind: SourceKind::Serato,
            origin: library::SourceOrigin::Local,
            name: "Music".to_owned(),
            root: std::path::PathBuf::from("/home/me/Music"),
            last_scan_at: None,
        };
        assert_eq!(Entry::Source(source).icon(), "💻");
    }

    #[test]
    fn playlists_share_the_crate_icon() {
        let playlist = Playlist {
            id: 1,
            source_id: 1,
            parent_id: None,
            name: "list".to_owned(),
            kind: "playlist".to_owned(),
            position: 0,
        };
        assert_eq!(Entry::Playlist(playlist).icon(), "▤");
    }

    #[test]
    fn the_list_columns_get_a_little_more_room() {
        let inner = Rect::new(2, 3, 81, 10);
        let parts = split_panes(inner);
        assert_eq!(parts[0].width, 11);
        assert_eq!(parts[2].width, 11);
        assert_eq!(parts[1].width, 1);
        assert_eq!(parts[3].width, 1);
        assert_eq!(parts[4].width, 57);
        let total: u16 = parts.iter().map(|part| part.width).sum();
        assert_eq!(total, inner.width);
    }

    #[test]
    fn a_tiny_browser_does_not_overflow() {
        let parts = split_panes(Rect::new(0, 0, 1, 1));
        let total: u16 = parts.iter().map(|part| part.width).sum();
        assert!(total <= 1);
    }

    #[test]
    fn a_new_browser_starts_in_the_list_pane() {
        let browser = Browser::new();
        assert_eq!(browser.focus, Focus::Lists);
        assert!(browser.tracks.is_empty());
        assert_eq!(browser.columns.len(), 1);
    }

    #[test]
    fn load_opens_the_first_source_and_back_walks_to_the_root() {
        let dir = std::env::temp_dir().join(format!(
            "pipefader-browser-{}-{}",
            std::process::id(),
            library::library::db::unix_now()
        ));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let db = LibraryDb::open(dir.join("library.sqlite3")).unwrap();
        let source = db.add_folder_source(&dir, Some("Test")).unwrap();
        db.scan_source(source.id, &mut |_| {}).unwrap();

        let mut browser = Browser::load(&db).unwrap();
        assert_eq!(browser.columns.len(), 2, "sources + root list");
        assert_eq!(browser.focus, Focus::Lists);
        browser.back(&db).unwrap();
        assert_eq!(browser.columns.len(), 1, "back to the source column");
        browser.open(&db).unwrap();
        assert_eq!(browser.columns.len(), 2, "open the source again");
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn track_columns_fit_the_available_width() {
        for width in [30usize, 40, 61, 120] {
            let widths = track_widths(width);
            let gaps = widths
                .iter()
                .filter(|width| **width > 0)
                .count()
                .saturating_sub(1)
                * 2;
            assert!(
                widths.iter().sum::<usize>() + gaps <= width,
                "width {width}: {widths:?}"
            );
            assert!(widths[0] > 0, "title must always have room");
        }
    }

    #[test]
    fn the_window_follows_the_selection() {
        assert_eq!(window_start(0, 20, 10), 0);
        assert_eq!(window_start(15, 20, 10), 6);
        assert_eq!(window_start(4, 20, 10), 0);
    }
}

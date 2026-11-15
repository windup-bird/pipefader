//! The track browser: a Miller column stack on the left and the current list's tracks on the right.
//!
//! The browser owns only application state: which columns and tracks are loaded and what is
//! selected. The database is passed to the methods that need it, so the model stays testable
//! without a filesystem, an engine or a terminal.

use std::time::Instant;

use library::{LibraryDb, Playlist, Source, TrackRow};
use protocol::KeyFormat;

/// Which side of the browser owns the arrow keys.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Focus {
    Lists,
    Tracks,
}

/// One row in a left-hand column: a library at the root, or a list below it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Entry {
    Source(Source),
    Playlist(Playlist),
}

impl Entry {
    pub fn label(&self) -> String {
        match self {
            Self::Source(source) => source.display_name(),
            Self::Playlist(playlist) => playlist.name.clone(),
        }
    }

    /// Glyph for the entry's kind. The colour is the panel's theme highlight, so a row is
    /// distinguishable by shape rather than by a per-kind palette.
    pub fn icon(&self) -> &'static str {
        match self {
            Self::Source(source) => match source.origin {
                library::SourceOrigin::Usb => "🔌",
                library::SourceOrigin::Local => "💻",
                library::SourceOrigin::Folder => "📁",
            },
            Self::Playlist(playlist) => match playlist.kind.as_str() {
                "folder" => "📁",
                _ => "▤",
            },
        }
    }
}

/// One visible level of the tree. The last two columns are drawn; the rest are the history that
/// `←` walks back through.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Column {
    pub title: String,
    pub entries: Vec<Entry>,
    pub selected: usize,
}

impl Column {
    fn sources(sources: Vec<Source>) -> Self {
        Self {
            title: "libraries".to_owned(),
            entries: sources.into_iter().map(Entry::Source).collect(),
            selected: 0,
        }
    }

    fn playlists(title: String, playlists: Vec<Playlist>) -> Self {
        Self {
            title,
            entries: playlists.into_iter().map(Entry::Playlist).collect(),
            selected: 0,
        }
    }

    pub fn selected_entry(&self) -> Option<&Entry> {
        self.entries
            .get(self.selected.min(self.entries.len().saturating_sub(1)))
    }

    fn move_selection(&mut self, delta: isize) {
        if self.entries.is_empty() {
            self.selected = 0;
            return;
        }
        let last = self.entries.len() - 1;
        self.selected = (self.selected as isize + delta).clamp(0, last as isize) as usize;
    }
}

/// Browser state. `columns` is the path from the library root to the current list; the two rightmost
/// columns are the ones on screen.
pub struct Browser {
    pub columns: Vec<Column>,
    pub tracks: Vec<TrackRow>,
    pub track_selected: usize,
    pub focus: Focus,
    /// How track keys are rendered in the right-hand list.
    pub key_format: KeyFormat,
    /// Last track row click, for double-click detection.
    pub last_track_click: Option<(usize, Instant)>,
}

impl Default for Browser {
    fn default() -> Self {
        Self::new()
    }
}

impl Browser {
    pub fn new() -> Self {
        Self {
            columns: vec![Column::sources(Vec::new())],
            tracks: Vec::new(),
            track_selected: 0,
            focus: Focus::Lists,
            key_format: KeyFormat::Camelot,
            last_track_click: None,
        }
    }

    /// Loads every source in the cache. Tests use this; the TUI passes its configured subset through
    /// [`Browser::load_sources`].
    #[allow(dead_code)] // Used by the browser tests; the TUI passes a filtered source list.
    pub fn load(db: &LibraryDb) -> library::Result<Self> {
        Self::load_sources(db, db.sources()?)
    }

    /// Loads an explicit source list and opens the first one.
    pub fn load_sources(db: &LibraryDb, sources: Vec<Source>) -> library::Result<Self> {
        let mut browser = Self::new();
        browser.columns = vec![Column::sources(sources.clone())];
        if let Some(source) = sources.first() {
            let lists = db.root_playlists(source.id)?;
            browser
                .columns
                .push(Column::playlists(source.display_name(), lists));
            browser.refresh_tracks(db)?;
        }
        Ok(browser)
    }

    pub fn focus(&self) -> Focus {
        self.focus
    }

    pub fn selected_track(&self) -> Option<&TrackRow> {
        self.tracks.get(self.track_selected)
    }

    /// Selects a row in a visible column. Clicking a parent column truncates the deeper columns.
    pub fn select(&mut self, column: usize, row: usize, db: &LibraryDb) -> library::Result<()> {
        if column >= self.columns.len() {
            return Ok(());
        }
        self.columns[column].selected =
            row.min(self.columns[column].entries.len().saturating_sub(1));
        if column + 1 < self.columns.len() {
            self.columns.truncate(column + 1);
        }
        self.focus = Focus::Lists;
        self.last_track_click = None;
        self.refresh_tracks(db)
    }

    /// Moves inside the focused pane. In the list pane that also refreshes the track preview.
    pub fn move_selection(&mut self, delta: isize, db: &LibraryDb) -> library::Result<()> {
        match self.focus {
            Focus::Tracks => {
                if !self.tracks.is_empty() {
                    let last = self.tracks.len() - 1;
                    self.track_selected =
                        (self.track_selected as isize + delta).clamp(0, last as isize) as usize;
                }
            }
            Focus::Lists => {
                if let Some(column) = self.columns.last_mut() {
                    column.move_selection(delta);
                }
                self.refresh_tracks(db)?;
            }
        }
        Ok(())
    }

    /// `→` / `open`: descend into the selected list, or enter the track pane at the bottom.
    pub fn open(&mut self, db: &LibraryDb) -> library::Result<()> {
        if self.focus == Focus::Tracks {
            return Ok(());
        }
        let Some(entry) = self
            .columns
            .last()
            .and_then(Column::selected_entry)
            .cloned()
        else {
            return Ok(());
        };
        match entry {
            Entry::Source(source) => {
                let lists = db.root_playlists(source.id)?;
                self.columns
                    .push(Column::playlists(source.display_name(), lists));
                self.refresh_tracks(db)?;
            }
            Entry::Playlist(playlist) => {
                let children = db.child_playlists(playlist.source_id, playlist.id)?;
                if children.is_empty() {
                    self.focus = Focus::Tracks;
                } else {
                    self.columns
                        .push(Column::playlists(playlist.name.clone(), children));
                    self.refresh_tracks(db)?;
                }
            }
        }
        Ok(())
    }

    /// `←` / `exit`: leave the track pane, else pop one level. The root is a no-op.
    pub fn back(&mut self, db: &LibraryDb) -> library::Result<()> {
        if self.focus == Focus::Tracks {
            self.focus = Focus::Lists;
            return Ok(());
        }
        if self.columns.len() > 1 {
            self.columns.pop();
            self.refresh_tracks(db)?;
        }
        Ok(())
    }

    /// Refreshes the right-hand preview from the selected list. Sources have no tracks themselves.
    pub fn refresh_tracks(&mut self, db: &LibraryDb) -> library::Result<()> {
        let playlist = self
            .columns
            .last()
            .and_then(Column::selected_entry)
            .and_then(|entry| match entry {
                Entry::Playlist(playlist) => Some(playlist.clone()),
                Entry::Source(_) => None,
            });
        self.tracks = match playlist {
            Some(playlist) => db.tracks_in_playlist(playlist.id)?,
            None => Vec::new(),
        };
        if self.tracks.is_empty() {
            self.track_selected = 0;
        } else {
            self.track_selected = self.track_selected.min(self.tracks.len() - 1);
        }
        Ok(())
    }
}

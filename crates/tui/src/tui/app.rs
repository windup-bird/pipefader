//! The terminal's view state.
//!
//! The application state (decks, browser model, FX values, logs, MIDI selection) lives in
//! `app::state::AppState` and is reached through `Deref`. What remains here is terminal-only: the
//! input buffer and completion popup, the modal stack, image state, draw timing and the last
//! frame's hit rectangles.

use std::ops::{Deref, DerefMut};
use std::sync::{Arc, Mutex};
use std::time::Instant;

use crossbeam_channel::{Receiver, Sender};

use protocol::Command;

use library::{analyser::Backends, ScanService};
#[cfg(test)]
use library::{LibraryDb, Source, SourceKind};
#[cfg(test)]
use std::path::{Path, PathBuf};

use ::app::state::AppState;
pub use ::app::state::{BeatMode, EqPanel, Knob, PadMode, PadPanel, Target, DECKS_PER_PAGE};

use crate::preference::{Theme, WaveformSettings};
use crate::procmon::ProcessMonitor;
use crate::tui::picker::{FilePicker, PortList};
use crate::tui::waveform_view::WaveformView;
use ::app::command::{Slots, UiEvent};
use ::app::completer::{self, Completion, Ctx};
#[cfg(test)]
use ::app::intent::UiIntent;
use ::app::notices::NoticeTx;
use ::app::response::LogLine;

/// Candidates shown in the completion popup.
pub const COMPLETION_ROWS: usize = 8;
/// The open completion popup and which row is highlighted.
pub struct CompletionState {
    pub completion: Completion,
    pub selected: usize,
}

/// A modal picker drawn over the UI. While set, the keyboard belongs to it.
pub enum Overlay {
    /// Choosing a controller (MIDI input) port.
    Ports { list: PortList },
    /// Choosing a file: a track to load, or a controller map.
    Files {
        picker: FilePicker,
        purpose: FilePurpose,
    },
    /// The small deck chooser opened by double-clicking a track.
    LoadTarget { x: u16, y: u16, selected: usize },
    /// The settings screen: one column of files, one of fields.
    Settings(Box<crate::tui::settings::SettingsScreen>),
}

/// What the file picker's choice means.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FilePurpose {
    /// Decode and install into this deck.
    Load { deck: usize },
    /// Use as the controller mapping file (and connect if a port is known).
    MidiMap,
}

/// One clickable region of the drawn interface.
///
/// Rebuilt by the renderer on every frame and consumed by the mouse handler, which is the only way
/// a pointer can reach a control: the command line keeps the keyboard, exactly as before.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Hit {
    /// Pad `index` (0-based) on `deck`.
    Pad {
        deck: usize,
        index: usize,
    },
    PadMode {
        deck: usize,
        mode: PadMode,
    },
    BeatMode {
        deck: usize,
        mode: BeatMode,
    },
    /// Switch the pads slot between the pad grid and the FX panel.
    PadPanel {
        deck: usize,
        panel: PadPanel,
    },
    /// Switch the eq slot between the EQ knobs and the beat controls.
    EqPanel {
        deck: usize,
        panel: EqPanel,
    },
    /// Select one flat FX slot in the deck chain.
    FxSelect {
        deck: usize,
        slot: usize,
    },
    /// Bypass/engage the selected FX slot.
    FxToggle {
        deck: usize,
        slot: usize,
    },
    /// Set one FX parameter to an absolute value (already mapped to its range).
    FxParam {
        deck: usize,
        slot: usize,
        param: usize,
        value: f32,
    },
    /// ×2 (`double = true`) or ÷2 the beat parameter of a slot.
    FxBeats {
        deck: usize,
        slot: usize,
        double: bool,
    },
    /// One step of the tempo fader (`direction` -1 / +1).
    TempoFader {
        deck: usize,
        direction: i8,
    },
    /// A bend press (`direction` -1 / +1) that releases itself.
    Bend {
        deck: usize,
        direction: i8,
    },
    /// Halve (`true`) or double (`false`) the loop length.
    LoopBeats {
        deck: usize,
        halve: bool,
    },
    /// Halve (`true`) or double (`false`) the jump length.
    JumpBeats {
        deck: usize,
        halve: bool,
    },
    /// Manual loop transport.
    Loop {
        deck: usize,
        op: LoopHit,
    },
    /// Beat jump backward / forward.
    Jump {
        deck: usize,
        direction: i8,
    },
    Transport {
        deck: usize,
        action: TransportHit,
    },
    /// A knob set to an absolute position, `-1.0..=1.0`.
    Knob {
        deck: usize,
        knob: Knob,
        value: f32,
    },
    /// The channel fader set to an absolute position, `-1.0..=1.0` (top = 0 dB). The band draws the
    /// channel fader (the one `[channel] fader` places); the per-stem levels a separated track
    /// exposes stay command-only, because one cell cannot mean two things.
    Fader {
        deck: usize,
        value: f32,
    },
    /// The crossfader, `-1.0..=1.0` (centre = 0).
    Crossfader {
        value: f32,
    },
    /// The header button that opens the settings screen.
    Settings,
    /// Cycle the deck one control column drives (`column` 0 = left, 1 = right). `delta` is the
    /// direction; the toggle button always sends `+1`.
    DeckSlot {
        column: usize,
        delta: i8,
    },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LoopHit {
    In,
    Out,
    Toggle,
    Exit,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TransportHit {
    Sync,
    Cue,
    Play,
    Keylock,
}

/// The terminal's view: the shared application state plus the widgets, input buffer and channels
/// that only exist in a terminal.
///
/// `Deref`/`DerefMut` to [`AppState`] keep the existing `app.states` / `app.browser`-style field
/// access working while the state itself lives in the application layer.
pub struct App {
    pub state: AppState,
    /// The last frame's browser geometry; the model itself is in `AppState`.
    pub browser_layout: crate::tui::browser::BrowserLayout,
    /// Whether the deck's images are currently deleted because a modal is open.
    pub images_hidden: bool,
    /// The colour slots every panel draws from.
    pub theme: Theme,
    /// Waveform preferences (renderer, colours, image refresh target).
    pub waveform: WaveformSettings,
    /// The selected waveform transport (braille / kitty) and its per-deck image state.
    pub waveform_view: WaveformView,
    /// The still images (cover, overview) each deck shows through the same image backend.
    pub deck_images: Vec<crate::tui::image_slot::DeckImages>,
    /// The overview playhead column drawn last frame.
    pub overview_playhead: Vec<Option<u16>>,

    pub command: Vec<char>,
    pub cursor: usize,
    pub completion: Option<CompletionState>,
    pub history: Vec<String>,
    pub history_pos: Option<usize>,

    /// Every clickable region of the last frame, in draw order.
    pub hits: Vec<(ratatui::layout::Rect, Hit)>,
    /// Exponential moving averages for the header: UI draw cost and measured frame rate.
    pub ui_draw_ms: f32,
    pub ui_fps: f32,
    /// Start of the previous draw, for the frame-rate average.
    pub last_draw_at: Option<Instant>,
    /// This process's CPU/RSS, sampled once a second.
    pub process: ProcessMonitor,
    pub quit: bool,

    /// The last terminal area, for mouse hit testing of popups.
    pub screen: ratatui::layout::Rect,
    /// A modal picker, if one is open.
    pub overlay: Option<Overlay>,
}

impl Deref for App {
    type Target = AppState;

    fn deref(&self) -> &Self::Target {
        &self.state
    }
}

impl DerefMut for App {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.state
    }
}

impl App {
    pub fn new(
        decks: usize,
        backends: Backends,
        notice_rx: Receiver<LogLine>,
        event_rx: Receiver<UiEvent>,
        fx_slots: Slots,
        scan: Arc<Mutex<ScanService>>,
    ) -> Self {
        let decks = decks.max(1);
        let state = AppState::new(decks, backends, notice_rx, event_rx, fx_slots, scan);
        Self {
            state,
            browser_layout: crate::tui::browser::BrowserLayout::default(),
            images_hidden: false,
            theme: Theme::default(),
            waveform: WaveformSettings::default(),
            waveform_view: WaveformView::new(WaveformSettings::default(), decks),
            deck_images: (0..decks)
                .map(|_| crate::tui::image_slot::DeckImages::new())
                .collect(),
            overview_playhead: vec![None; decks],
            command: Vec::new(),
            cursor: 0,
            completion: None,
            history: Vec::new(),
            history_pos: None,
            hits: Vec::new(),
            ui_draw_ms: 0.0,
            ui_fps: 60.0,
            last_draw_at: None,
            process: ProcessMonitor::new(),
            quit: false,
            screen: ratatui::layout::Rect::default(),
            overlay: None,
        }
    }

    /// Opens the remembered port with the remembered map, replacing any current input.
    ///
    /// The connection itself lives in `AppState`; this wrapper only turns a failed map/port into
    /// the picker the terminal should reopen.
    pub fn connect_midi(
        &mut self,
        command_tx: Sender<Command>,
        notices: &NoticeTx,
        dispatcher: &::app::command::Dispatcher,
    ) {
        if let Some(retry) = self.state.connect_midi(command_tx, notices, dispatcher) {
            self.overlay = Some(match retry {
                ::app::state::MidiRetry::Map(map) => Overlay::Files {
                    picker: FilePicker::new(
                        Some(std::path::Path::new(&map)),
                        &["toml"],
                        "controller map",
                    ),
                    purpose: FilePurpose::MidiMap,
                },
                ::app::state::MidiRetry::Ports => Overlay::Ports {
                    list: PortList::refresh(),
                },
            });
        }
    }

    /// Clears the command line and closes any popup. The input box is always focused, so this is
    /// what `Esc` and a submitted command both do.
    pub fn clear_command(&mut self) {
        self.command.clear();
        self.cursor = 0;
        self.completion = None;
        self.history_pos = None;
    }

    // ---- command-line editing -------------------------------------------------

    pub fn insert_char(&mut self, ch: char) {
        self.command.insert(self.cursor, ch);
        self.cursor += 1;
        self.refresh_completion();
    }

    pub fn backspace(&mut self) {
        if self.cursor > 0 {
            self.command.remove(self.cursor - 1);
            self.cursor -= 1;
        }
        self.refresh_completion();
    }

    pub fn delete(&mut self) {
        if self.cursor < self.command.len() {
            self.command.remove(self.cursor);
        }
        self.refresh_completion();
    }

    pub fn move_cursor(&mut self, delta: isize) {
        let max = self.command.len() as isize;
        self.cursor = (self.cursor as isize + delta).clamp(0, max) as usize;
        self.refresh_completion();
    }

    pub fn command_string(&self) -> String {
        self.command.iter().collect()
    }

    /// Recomputes the popup from the current text and cursor. An empty (or blank) box has nothing
    /// to complete.
    pub fn refresh_completion(&mut self) {
        if self.command.iter().all(|ch| ch.is_whitespace()) {
            self.completion = None;
            return;
        }
        let slots = self.fx_slots.snapshot();
        let ctx = Ctx {
            decks: self.decks,
            // The chain label the engine reports, which is 1-based.
            chain: protocol::deck_label(self.default_deck() as u8),
            slots: &slots,
        };
        self.completion = completer::complete(&self.command, self.cursor, &ctx).map(|completion| {
            CompletionState {
                completion,
                selected: 0,
            }
        });
    }

    pub fn completion_move(&mut self, delta: isize) {
        if let Some(state) = &mut self.completion {
            let len = state.completion.items.len() as isize;
            if len > 0 {
                state.selected = (state.selected as isize + delta).rem_euclid(len) as usize;
            }
        }
    }

    /// Replaces the completed token with the highlighted candidate. A space is appended so the next
    /// argument starts cleanly, unless the candidate is a directory (`foo/`).
    pub fn completion_accept(&mut self) {
        let Some(state) = self.completion.take() else {
            return;
        };
        let Some(candidate) = state.completion.items.get(state.selected) else {
            return;
        };
        let range = state.completion.replace.clone();
        self.command.splice(range.clone(), candidate.text.chars());
        self.cursor = range.start + candidate.text.chars().count();
        if !candidate.text.ends_with('/') {
            self.command.insert(self.cursor, ' ');
            self.cursor += 1;
        }
        self.refresh_completion();
    }

    /// True when the highlighted candidate differs from the typed token, i.e. applying it would
    /// change the buffer. An exact match means `Enter` should submit rather than "complete" to the
    /// same word (which would otherwise need a second keypress).
    pub fn completion_changes_token(&self) -> bool {
        let Some(state) = &self.completion else {
            return false;
        };
        let Some(candidate) = state.completion.items.get(state.selected) else {
            return false;
        };
        let typed: String = self.command[state.completion.replace.clone()]
            .iter()
            .collect();
        candidate.text != typed
    }

    /// Browses submitted commands. Up from the prompt loads the newest.
    pub fn history_prev(&mut self) {
        if self.history.is_empty() {
            return;
        }
        let next = match self.history_pos {
            Some(0) => 0,
            Some(index) => index - 1,
            None => self.history.len() - 1,
        };
        self.history_pos = Some(next);
        self.command = self.history[next].chars().collect();
        self.cursor = self.command.len();
        self.completion = None;
    }

    pub fn history_next(&mut self) {
        let Some(index) = self.history_pos else {
            return;
        };
        if index + 1 >= self.history.len() {
            self.history_pos = None;
            self.command.clear();
            self.cursor = 0;
        } else {
            self.history_pos = Some(index + 1);
            self.command = self.history[index + 1].chars().collect();
            self.cursor = self.command.len();
        }
        self.completion = None;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::preference::LibrarySettings;
    use ::app::state::{connection_specs, expand_tilde, prefer_source};
    use library::SourceOrigin;

    fn session(
        id: &str,
        port: Option<&str>,
        map: &str,
    ) -> ::app::config::profile::ControllerSession {
        ::app::config::profile::ControllerSession {
            id: id.to_owned(),
            port: port.map(str::to_owned),
            map: map.to_owned(),
            routes: Default::default(),
        }
    }

    #[test]
    fn a_runtime_midi_pick_connects_even_with_no_configured_controller() {
        let specs = connection_specs(
            &[],
            Some("Party Mix III MIDI 1"),
            Some("/tmp/mapping.toml"),
            &Default::default(),
        );
        assert_eq!(specs.len(), 1);
        assert_eq!(specs[0].port.as_deref(), Some("Party Mix III MIDI 1"));
        assert_eq!(specs[0].map, "/tmp/mapping.toml");
    }

    #[test]
    fn a_runtime_midi_pick_overrides_a_portless_configured_entry() {
        let configured = [session("default", None, "/old/mapping.toml")];
        let specs = connection_specs(
            &configured,
            Some("Party Mix III MIDI 1"),
            Some("/new/mapping.toml"),
            &Default::default(),
        );
        assert_eq!(specs.len(), 1);
        assert_eq!(specs[0].port.as_deref(), Some("Party Mix III MIDI 1"));
        assert_eq!(specs[0].map, "/new/mapping.toml");
    }

    #[test]
    fn configured_controllers_are_untouched_without_a_runtime_pick() {
        let configured = [
            session("ctl1", Some("port-a"), "/a.toml"),
            session("ctl2", Some("port-b"), "/b.toml"),
        ];
        let specs = connection_specs(&configured, None, None, &Default::default());
        assert_eq!(specs.len(), 2);
        assert_eq!(specs[1].id, "ctl2");
        assert_eq!(specs[1].port.as_deref(), Some("port-b"));
        assert_eq!(specs[1].map, "/b.toml");
    }

    fn temp_dir(label: &str) -> PathBuf {
        std::env::temp_dir().join(format!(
            "app-{}-{}-{}",
            label,
            std::process::id(),
            library::library::db::unix_now()
        ))
    }

    fn wav() -> Vec<u8> {
        let mut bytes = Vec::new();
        bytes.extend_from_slice(b"RIFF");
        bytes.extend_from_slice(&(36u32 + 400).to_le_bytes());
        bytes.extend_from_slice(b"WAVEfmt ");
        bytes.extend_from_slice(&16u32.to_le_bytes());
        bytes.extend_from_slice(&1u16.to_le_bytes());
        bytes.extend_from_slice(&1u16.to_le_bytes());
        bytes.extend_from_slice(&8_000u32.to_le_bytes());
        bytes.extend_from_slice(&16_000u32.to_le_bytes());
        bytes.extend_from_slice(&2u16.to_le_bytes());
        bytes.extend_from_slice(&16u16.to_le_bytes());
        bytes.extend_from_slice(b"data");
        bytes.extend_from_slice(&400u32.to_le_bytes());
        bytes.resize(44 + 400, 0);
        bytes
    }

    fn source(name: &str, root: impl Into<PathBuf>) -> Source {
        Source {
            id: 0,
            kind: SourceKind::Folder,
            origin: SourceOrigin::Folder,
            name: name.to_owned(),
            root: root.into(),
            last_scan_at: None,
        }
    }

    #[test]
    fn the_browser_starts_on_the_music_folder() {
        let music = Path::new("home").join("me").join("Music");
        let sources = vec![
            source("mp3", "mp3"),
            source("Music", &music),
            source("USB", "run/media/stick"),
        ];
        let ordered = prefer_source(sources, Some(&music));
        assert_eq!(ordered[0].name, "Music");

        // Without a Music source the configured order is left alone.
        let ordered = prefer_source(
            vec![source("mp3", "mp3"), source("USB", "run/media/stick")],
            Some(&music),
        );
        assert_eq!(ordered[0].name, "mp3");
    }

    #[test]
    fn a_tilde_folder_resolves_against_the_home_directory() {
        let home = Path::new("home").join("me");
        assert_eq!(
            expand_tilde("~/Music", Some(home.as_path())),
            home.join("Music")
        );
        assert_eq!(
            expand_tilde("~\\Music", Some(home.as_path())),
            home.join("Music")
        );
        assert_eq!(expand_tilde("~", Some(home.as_path())), home);
        assert_eq!(
            expand_tilde("./mp3", Some(home.as_path())),
            PathBuf::from("./mp3")
        );
        assert_eq!(
            expand_tilde("~/Music", None),
            PathBuf::from("~/Music"),
            "no home directory means the literal path is tried"
        );
    }

    #[test]
    fn only_configured_sources_reach_the_browser() {
        let dir = temp_dir("configured");
        let _ = std::fs::remove_dir_all(&dir);
        let configured = dir.join("configured");
        let hidden = dir.join("hidden");
        std::fs::create_dir_all(&configured).unwrap();
        std::fs::create_dir_all(&hidden).unwrap();
        std::fs::write(configured.join("a.wav"), wav()).unwrap();
        std::fs::write(hidden.join("b.wav"), wav()).unwrap();

        let db = Arc::new(LibraryDb::open(dir.join("library.sqlite3")).unwrap());
        db.add_folder_source(&hidden, Some("Hidden")).unwrap();
        let (_notice_tx, notice_rx) = crossbeam_channel::unbounded();
        let (_event_tx, event_rx) = crossbeam_channel::unbounded();
        let mut app = App::new(
            1,
            Backends::default(),
            notice_rx,
            event_rx,
            Default::default(),
            Default::default(),
        );
        app.library = Some(db);
        let settings = LibrarySettings {
            folders: vec![configured.display().to_string()],
            ..Default::default()
        };
        app.sync_library(&settings);
        assert_eq!(app.browser.columns[0].entries.len(), 1);
        assert_eq!(
            app.browser.columns[0].entries[0].label(),
            configured.file_name().unwrap().to_string_lossy()
        );
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn intents_switch_panels_only_while_following() {
        let (_notice_tx, notice_rx) = crossbeam_channel::unbounded();
        let (_event_tx, event_rx) = crossbeam_channel::unbounded();
        let mut app = App::new(
            2,
            Backends::default(),
            notice_rx,
            event_rx,
            Default::default(),
            Default::default(),
        );
        app.apply_intent(UiIntent::Beat {
            deck: 1,
            mode: BeatMode::ManualLoop,
        });
        assert_eq!(app.eq_panel[1], EqPanel::Beat);
        assert_eq!(app.beat_mode[1], BeatMode::ManualLoop);

        app.follow_commands = false;
        app.apply_intent(UiIntent::Pads {
            deck: 0,
            mode: PadMode::BeatJump,
        });
        assert_eq!(app.pad_panel[0], PadPanel::Pads);
        assert_eq!(app.pad_mode[0], PadMode::HotCue);
    }
}

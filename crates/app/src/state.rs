//! The session state a front-end renders: deck snapshots, browser-independent data, FX values,
//! logs and the paths this session runs on.
//!
//! Deliberately plain data. The terminal UI embeds it (`Deref` keeps the old `app.states` field
//! access working) and a future GUI can serialize the same struct without touching ratatui.

use std::collections::{HashSet, VecDeque};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use crossbeam_channel::{Receiver, Sender};

use audio::{AudioPipeline, DeviceInfo, Meters};
use controller::map::DeckRoutes;
use controller::ModeEvent;
use library::analyser::Backends;
use library::{
    detect_source_kinds, ImportCalibration, LibraryDb, ScanProgress, ScanService, Source,
    SourceKind,
};
use protocol::{
    BeatGrid, BrowserAction, Command, CommandResponse, DeckState, FxChainId, FxSlotStatus,
    KeyFormat,
};

use crate::command::{Slots, UiEvent};
use crate::config::profile::ControllerSession;
use crate::intent::UiIntent;
use crate::midi::MidiSession;
use crate::notices::NoticeTx;
use crate::response::{self, LogLine};

/// How many decks one page of the TUI control band drives. Shared by the state model so a GUI can
/// use the same deck pairing.
pub const DECKS_PER_PAGE: usize = 2;
/// Waveform zoom bounds, in frames per cell. 512 frames is ~11.6ms per cell (the finest the peak
/// pyramid resolves), 131072 is ~3s per cell (a very wide overview). The unit is backend-independent,
/// so switching braille ↔ image keeps the same visible span.
pub const MIN_FRAMES_PER_CELL: f64 = 512.0;
pub const MAX_FRAMES_PER_CELL: f64 = 131_072.0;
/// Default visible span: 2048 frames/cell over ~120 cells is roughly five seconds.
pub const DEFAULT_FRAMES_PER_CELL: f64 = 2_048.0;
/// Keep the debug log bounded; this is a terminal, not a log file.
pub const LOG_CAP: usize = 500;

/// Which prefix the command line currently speaks for.
///
/// `Browser` is a target of its own: while it owns the command line a bare deck verb is refused
/// (the front-end passes `None` to `command::dispatch`), because falling back to the last focused
/// deck is how a stray `play` stops a track mid-browse.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Target {
    Deck(usize),
    Browser,
}

impl Target {
    /// The label shown on the command rule: `deck1`, `deck2`, … or `browser`.
    pub fn prefix(self) -> String {
        match self {
            Self::Deck(index) => protocol::deck_label(index as u8),
            Self::Browser => String::new(),
        }
    }

    /// Full tab label used by the command rule.
    pub fn label(self) -> String {
        match self {
            Self::Deck(index) => protocol::deck_label(index as u8),
            Self::Browser => "browser".to_owned(),
        }
    }

    /// Short tab label for a narrow command panel.
    pub fn compact_label(self) -> String {
        match self {
            Self::Deck(index) => format!("d{}", index + 1),
            Self::Browser => "br".to_owned(),
        }
    }
}

/// Which command set the eight pads currently fire. Front-end state: the engine only knows the
/// three commands, and a DJ switches between them per deck.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum PadMode {
    /// Set on an empty pad, trigger on a filled one.
    #[default]
    HotCue,
    /// `1/4 1/2 1 2 4 8 16 32` beats.
    BeatLoop,
    /// `-16 -8 -4 -2 +2 +4 +8 +16` beats.
    BeatJump,
}

impl PadMode {
    pub const ALL: [Self; 3] = [Self::HotCue, Self::BeatLoop, Self::BeatJump];

    pub fn label(self) -> &'static str {
        match self {
            Self::HotCue => "cue",
            Self::BeatLoop => "loop",
            Self::BeatJump => "jump",
        }
    }

    /// The eight pad labels, in pad order.
    pub fn pads(self) -> [&'static str; 8] {
        match self {
            Self::HotCue => ["1", "2", "3", "4", "5", "6", "7", "8"],
            Self::BeatLoop => ["1/4", "1/2", "1", "2", "4", "8", "16", "32"],
            Self::BeatJump => ["-16", "-8", "-4", "-2", "+2", "+4", "+8", "+16"],
        }
    }

    /// Loop length per pad, in beats (only meaningful for [`PadMode::BeatLoop`]). Quarter and half
    /// beats are exact: `BeatLen` is a rational, so `1/4` is not 0.25 of a rounded frame count.
    pub fn loop_beats(self, pad: usize) -> Option<protocol::BeatLen> {
        // Written as exact fractions rather than a float: `1/4` is a rational beat length all the
        // way down, so a quarter-beat loop lands on the grid instead of on a rounded frame count.
        let table: [(u32, u32); 8] = [
            (1, 4),
            (1, 2),
            (1, 1),
            (2, 1),
            (4, 1),
            (8, 1),
            (16, 1),
            (32, 1),
        ];
        table
            .get(pad)
            .and_then(|(num, den)| protocol::BeatLen::fraction(*num, *den))
    }

    /// Jump size per pad, in beats (only meaningful for [`PadMode::BeatJump`]).
    pub fn jump_beats(self, pad: usize) -> Option<i64> {
        [-16, -8, -4, -2, 2, 4, 8, 16].get(pad).copied()
    }
}

/// What the middle of the beat block is showing.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum BeatMode {
    /// Tempo fader and bend.
    #[default]
    Tempo,
    /// Manual loop: in / toggle / out, with the loop length under the pads' `loop` mode.
    ManualLoop,
    /// Beat jump: backward / forward by the current step.
    ManualJump,
}

impl BeatMode {
    pub const ALL: [Self; 3] = [Self::Tempo, Self::ManualLoop, Self::ManualJump];

    pub fn label(self) -> &'static str {
        match self {
            Self::Tempo => "bpm",
            Self::ManualLoop => "loop",
            Self::ManualJump => "jump",
        }
    }
}

/// Which of the two panels the pads slot is showing.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum PadPanel {
    #[default]
    Pads,
    Fx,
}

impl PadPanel {
    pub const ALL: [Self; 2] = [Self::Pads, Self::Fx];

    pub fn label(self) -> &'static str {
        match self {
            Self::Pads => "pads",
            Self::Fx => "fx",
        }
    }
}

/// Which of the two panels the eq slot is showing.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum EqPanel {
    #[default]
    Eq,
    Beat,
}

impl EqPanel {
    pub const ALL: [Self; 2] = [Self::Eq, Self::Beat];

    pub fn label(self) -> &'static str {
        match self {
            Self::Eq => "eq",
            Self::Beat => "beat",
        }
    }
}

/// The five mixer knobs a channel has.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Knob {
    Gain,
    High,
    Mid,
    Low,
    Filter,
}

impl Knob {
    pub const ALL: [Self; 5] = [Self::Gain, Self::High, Self::Mid, Self::Low, Self::Filter];

    pub fn label(self) -> &'static str {
        match self {
            Self::Gain => "gain",
            Self::High => "high",
            Self::Mid => "mid",
            Self::Low => "low",
            Self::Filter => "filt",
        }
    }
}

/// What a failed MIDI connection should reopen in the terminal.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum MidiRetry {
    Map(String),
    Ports,
}

/// Everything a front-end renders that is not a widget or a transport command.
pub struct AppState {
    pub version: &'static str,
    pub backends: Backends,
    pub sample_rate: u32,
    /// Output ring capacity in frames, from the live config (the sliders can change it).
    pub ring_frames: usize,
    pub decks: usize,
    pub focused: usize,
    /// Which deck each control column drives, left then right.
    pub slots: [usize; DECKS_PER_PAGE],
    /// The command-line target: one deck, or the (still prefix-less) browser.
    pub target: Target,
    /// Output devices probed before the terminal was taken over, for the settings screen.
    pub devices: Vec<DeviceInfo>,
    /// The profile file this session was started from.
    pub profile_path: Option<String>,
    /// Where `preference.toml` lives.
    pub preference_path: String,
    /// Where the live settings came from.
    pub live_path: Option<String>,
    /// Where the mixer topology came from.
    pub mixer_path: Option<String>,
    /// How keys are rendered across the front-end.
    pub key_format: KeyFormat,
    /// The library cache. `None` when startup could not open it.
    pub library: Option<Arc<LibraryDb>>,
    /// Sources the configured preference categories allow.
    pub allowed_sources: HashSet<i64>,
    /// The shared scan worker.
    pub scan: Arc<Mutex<ScanService>>,
    /// `None` probes each file; a fixed value overrides the decoder start trim.
    pub decoder_start_ms: Option<f64>,
    /// Extra imported-grid/cue correction, positive = later.
    pub grid_offset_ms: f64,

    pub states: Vec<DeckState>,
    /// File name per deck (from the load tap), for the deck header.
    pub titles: Vec<Option<String>>,
    /// Embedded artwork per deck, read off the UI thread when a track loads.
    pub covers: Vec<Option<Arc<media::Cover>>>,
    /// Which command set each deck's pads show.
    pub pad_mode: Vec<PadMode>,
    /// Which panel each deck's pads slot shows.
    pub pad_panel: Vec<PadPanel>,
    /// What each deck's beat block is showing.
    pub beat_mode: Vec<BeatMode>,
    /// Which panel each deck's eq slot is showing.
    pub eq_panel: Vec<EqPanel>,
    /// The selected flat FX slot per deck.
    pub fx_slot: Vec<usize>,
    /// The Miller-column browser model (the terminal layout lives in the front-end).
    pub browser: crate::browser::Browser,
    /// Whether CLI/MIDI commands and mode triggers may switch panels on their own.
    pub follow_commands: bool,
    /// Whether a browser load should analyse a track with no imported/cached grid.
    pub auto_analyse: bool,
    /// The latest intent produced by the command fan-out.
    pub intent: Arc<Mutex<Option<UiIntent>>>,
    /// Live FX slot state per deck.
    pub deck_fx: Vec<Vec<FxSlotStatus>>,
    /// Outstanding `GetFxState` requests.
    pub fx_pending: usize,
    /// Slot kinds per chain label, shared with the dispatcher.
    pub fx_slots: Slots,
    pub waveforms: Vec<Option<Arc<library::Waveform>>>,
    pub grids: Vec<Option<BeatGrid>>,

    /// Shared zoom, in frames per terminal cell.
    pub frames_per_cell: f64,
    /// Last waveform width in cells, so `fit` knows the viewport.
    pub wave_width_cells: usize,
    /// Band crossovers used when a waveform is built off the UI thread.
    pub waveform_low_hz: u16,
    pub waveform_high_hz: u16,

    pub log: VecDeque<LogLine>,
    /// Lines scrolled up from the bottom (0 = following).
    pub log_offset: usize,
    pub pending_states: usize,
    pub meters: Option<Meters>,

    pub midi: Vec<MidiSession>,
    /// The chosen (or flag-supplied) port, remembered across reconnects.
    pub midi_port: Option<String>,
    /// The chosen (or flag-supplied) map path.
    pub midi_map: Option<String>,
    /// Controller face → physical deck table.
    pub deck_routes: DeckRoutes,
    /// One entry per `[[controller]]` instance.
    pub controller_sessions: Vec<ControllerSession>,

    pub notice_rx: Receiver<LogLine>,
    pub event_rx: Receiver<UiEvent>,
    pub mode_tx: Sender<ModeEvent>,
    pub mode_rx: Receiver<ModeEvent>,
    pub browser_tx: Sender<BrowserAction>,
    pub browser_rx: Receiver<BrowserAction>,
    pub waveform_tx: Sender<(usize, Arc<library::Waveform>)>,
    pub waveform_rx: Receiver<(usize, Arc<library::Waveform>)>,
    pub cover_tx: Sender<(usize, Option<Arc<media::Cover>>)>,
    pub cover_rx: Receiver<(usize, Option<Arc<media::Cover>>)>,
}

impl AppState {
    pub fn new(
        decks: usize,
        backends: Backends,
        notice_rx: Receiver<LogLine>,
        event_rx: Receiver<UiEvent>,
        fx_slots: Slots,
        scan: Arc<Mutex<ScanService>>,
    ) -> Self {
        let decks = decks.max(1);
        let (waveform_tx, waveform_rx) = crossbeam_channel::unbounded();
        let (cover_tx, cover_rx) = crossbeam_channel::unbounded();
        let (browser_tx, browser_rx) = crossbeam_channel::unbounded();
        let (mode_tx, mode_rx) = crossbeam_channel::unbounded();
        Self {
            version: env!("CARGO_PKG_VERSION"),
            backends,
            sample_rate: protocol::SAMPLE_RATE,
            ring_frames: audio::OUTPUT_RING_CAPACITY,
            decks,
            focused: 0,
            slots: std::array::from_fn(|column| column.min(decks - 1)),
            target: Target::Browser,
            devices: Vec::new(),
            profile_path: None,
            preference_path: crate::config::preference::DEFAULT_PATH.to_owned(),
            live_path: None,
            mixer_path: None,
            key_format: KeyFormat::Camelot,
            library: None,
            allowed_sources: HashSet::new(),
            scan,
            decoder_start_ms: None,
            grid_offset_ms: 0.0,
            states: (0..decks)
                .map(|index| DeckState {
                    deck_id: index as u8,
                    current_frame: 0,
                    playing: false,
                    total_frames: 0,
                    bpm: 0.0,
                    bpm_at_frame: 0.0,
                    key: None,
                    virtual_frame: 0,
                    loop_range: None,
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
                    cue_frame: 0,
                    hot_cues: [None; protocol::HOT_CUE_SLOTS],
                    vinyl: false,
                    keylock: protocol::KeylockMode::On,
                    key_shift: 0,
                    stems: protocol::StemStatus::default(),
                })
                .collect(),
            titles: vec![None; decks],
            covers: vec![None; decks],
            pad_mode: vec![PadMode::default(); decks],
            pad_panel: vec![PadPanel::default(); decks],
            beat_mode: vec![BeatMode::default(); decks],
            eq_panel: vec![EqPanel::default(); decks],
            fx_slot: vec![0; decks],
            browser: crate::browser::Browser::new(),
            follow_commands: true,
            auto_analyse: false,
            intent: Arc::new(Mutex::new(None)),
            deck_fx: vec![Vec::new(); decks],
            fx_pending: 0,
            fx_slots,
            waveforms: vec![None; decks],
            grids: vec![None; decks],
            frames_per_cell: DEFAULT_FRAMES_PER_CELL,
            wave_width_cells: 200,
            waveform_low_hz: 200,
            waveform_high_hz: 4_000,
            log: VecDeque::new(),
            log_offset: 0,
            pending_states: 0,
            meters: None,
            midi: Vec::new(),
            midi_port: None,
            midi_map: None,
            deck_routes: DeckRoutes::default(),
            controller_sessions: Vec::new(),
            notice_rx,
            event_rx,
            mode_tx,
            mode_rx,
            browser_tx,
            browser_rx,
            waveform_tx,
            waveform_rx,
            cover_tx,
            cover_rx,
        }
    }
}

impl AppState {
    /// The shared slot the command fan-out writes intents into.
    pub fn intent_slot(&self) -> Arc<Mutex<Option<UiIntent>>> {
        self.intent.clone()
    }

    /// A sender for selector presses from the MIDI router.
    pub fn mode_sender(&self) -> Sender<ModeEvent> {
        self.mode_tx.clone()
    }

    /// Every FX slot the panel may show: the deck chain minus the fixed `eq`/`filter` stages.
    pub fn fx_panel_slots(&self, deck: usize) -> Vec<&FxSlotStatus> {
        self.deck_fx
            .get(deck)
            .into_iter()
            .flatten()
            .filter(|slot| !matches!(slot.role.as_str(), "eq" | "filter"))
            .collect()
    }

    /// The selected FX slot, falling back to the first one when the saved index disappeared.
    pub fn selected_fx(&self, deck: usize) -> Option<&FxSlotStatus> {
        let slots = self.fx_panel_slots(deck);
        let wanted = self.fx_slot.get(deck).copied().unwrap_or(0);
        slots
            .iter()
            .copied()
            .find(|slot| slot.index == wanted)
            .or_else(|| slots.first().copied())
    }

    /// Keeps `fx_slot` pointing at a mounted slot after a `fx remove`/`mixer reload`.
    pub fn clamp_fx_slot(&mut self, deck: usize) {
        let indices: Vec<usize> = self
            .fx_panel_slots(deck)
            .iter()
            .map(|slot| slot.index)
            .collect();
        if let Some(selected) = self.fx_slot.get_mut(deck) {
            if !indices.contains(&*selected) {
                *selected = indices.first().copied().unwrap_or(0);
            }
        }
    }

    /// Applies a command/mode intent. The preference gate lives here so both sources agree.
    pub fn apply_intent(&mut self, intent: UiIntent) {
        if !self.follow_commands {
            return;
        }
        match intent {
            UiIntent::Pads { deck, mode } => {
                if let Some(panel) = self.pad_panel.get_mut(deck) {
                    *panel = PadPanel::Pads;
                }
                if let Some(slot) = self.pad_mode.get_mut(deck) {
                    *slot = mode;
                }
            }
            UiIntent::Beat { deck, mode } => {
                if let Some(panel) = self.eq_panel.get_mut(deck) {
                    *panel = EqPanel::Beat;
                }
                if let Some(slot) = self.beat_mode.get_mut(deck) {
                    *slot = mode;
                }
            }
            UiIntent::Eq { deck } => {
                if let Some(panel) = self.eq_panel.get_mut(deck) {
                    *panel = EqPanel::Eq;
                }
            }
            UiIntent::FxPanel { deck } => {
                if let Some(panel) = self.pad_panel.get_mut(deck) {
                    *panel = PadPanel::Fx;
                }
            }
            UiIntent::FxSlot { deck, slot } => {
                if let Some(panel) = self.pad_panel.get_mut(deck) {
                    *panel = PadPanel::Fx;
                }
                if let Some(selected) = self.fx_slot.get_mut(deck) {
                    *selected = slot;
                }
                self.clamp_fx_slot(deck);
            }
            UiIntent::FxOrdinal { deck, ordinal } => {
                if let Some(panel) = self.pad_panel.get_mut(deck) {
                    *panel = PadPanel::Fx;
                }
                let index = self
                    .fx_panel_slots(deck)
                    .get(ordinal.saturating_sub(1))
                    .map(|slot| slot.index);
                if let (Some(index), Some(selected)) = (index, self.fx_slot.get_mut(deck)) {
                    *selected = index;
                }
            }
        }
    }

    /// Appends one line and re-follows the tail.
    pub fn push_log(&mut self, line: LogLine) {
        self.log.push_back(line);
        while self.log.len() > LOG_CAP {
            self.log.pop_front();
        }
        self.log_offset = 0;
    }

    pub fn push_lines(&mut self, lines: impl IntoIterator<Item = LogLine>) {
        for line in lines {
            self.push_log(line);
        }
    }

    /// Rebuilds the browser from the cache after a scan or a source change.
    pub fn reload_browser(&mut self) {
        let Some(db) = self.library.clone() else {
            self.browser = crate::browser::Browser::new();
            return;
        };
        match db.sources() {
            Ok(sources) => {
                let visible: Vec<Source> = sources
                    .into_iter()
                    .filter(|source| {
                        self.allowed_sources.contains(&source.id) && source.root.is_dir()
                    })
                    .collect();
                // The browser opens its first source, so put ~/Music there when it is configured.
                let preferred = music_dir().and_then(|path| std::fs::canonicalize(path).ok());
                let visible = prefer_source(visible, preferred.as_deref());
                match crate::browser::Browser::load_sources(&db, visible) {
                    Ok(mut browser) => {
                        browser.key_format = self.key_format;
                        self.browser = browser;
                    }
                    Err(err) => self.push_log(LogLine::error(format!("library: {err}"))),
                }
            }
            Err(err) => self.push_log(LogLine::error(format!("library: {err}"))),
        }
    }

    /// Drains browser actions queued by MIDI. The caller executes them with the dispatcher.
    pub fn drain_browser_actions(&mut self) -> Vec<BrowserAction> {
        let mut actions = Vec::new();
        while let Ok(action) = self.browser_rx.try_recv() {
            actions.push(action);
        }
        actions
    }

    /// Applies the configured source categories: explicit folders, local user libraries, and the
    /// watcher for USB media. Sources outside these categories are neither scanned nor displayed.
    pub fn sync_library(&mut self, settings: &crate::config::preference::LibrarySettings) {
        let Some(db) = self.library.clone() else {
            return;
        };
        self.allowed_sources.clear();
        self.decoder_start_ms = settings.decoder_start_ms;
        self.grid_offset_ms = settings.grid_offset_ms;
        db.set_import_calibration(ImportCalibration {
            rkb_mp3_offset_ms: settings.rkb_mp3_offset_ms,
            serato_offset_ms: settings.serato_offset_ms,
            vdj_offset_ms: settings.vdj_offset_ms,
        });

        let mut pending = Vec::new();
        for folder in &settings.folders {
            let root = expand_home(folder);
            match db.add_folder_source(&root, None) {
                Ok(source) => {
                    self.allowed_sources.insert(source.id);
                    pending.push(source);
                }
                Err(err) => self.push_log(LogLine::error(format!("[library] {folder}: {err}"))),
            }
        }
        for kind in settings.local_kinds() {
            for root in local_roots(kind) {
                if !detect_source_kinds(&root).contains(&kind) {
                    continue;
                }
                match db.add_source(kind, &root, None) {
                    Ok(source) => {
                        self.allowed_sources.insert(source.id);
                        pending.push(source);
                    }
                    Err(err) => self.push_log(LogLine::error(format!(
                        "[library] {}: {err}",
                        root.display()
                    ))),
                }
            }
        }
        // The library owns the removable-media watcher and the scan worker; this front-end only
        // configures them and enqueues the configured sources. Nothing here touches the disk.
        let mut scan = self.scan.lock().expect("scan service lock");
        scan.configure(&db, settings.usb_kinds());
        let count = pending.len();
        let queued = scan.enqueue(pending);
        drop(scan);
        // Show the cached tree before the worker fills it in: the first scan of a large folder can
        // take a while, and blocking here would keep the terminal on the normal screen.
        self.reload_browser();
        if queued {
            self.push_log(LogLine::info(format!(
                "[library] scanning {count} source(s) in background"
            )));
        }
    }

    /// Applies an engine response. Deck states update silently (they are on every poll); everything
    /// else is echoed to the log, exactly as the REPL would print it.
    pub fn on_response(&mut self, response: &CommandResponse, pipeline: &AudioPipeline) {
        let sample_rate = self.sample_rate;
        if matches!(response, CommandResponse::Error(_)) {
            // An engine error may be the answer to a knob poll (an FX chain that does not exist on
            // a custom topology). Drop the in-flight count so the poll keeps going instead of
            // stalling behind a response that will never come.
            self.fx_pending = 0;
        }
        match response {
            CommandResponse::States(states) => {
                for state in states {
                    self.set_state(state);
                }
                self.pending_states = self.pending_states.saturating_sub(1);
            }
            CommandResponse::State(state) => self.set_state(state),
            CommandResponse::Loaded {
                deck_id,
                total_frames,
            } => {
                if let Some(state) = self.states.get_mut(*deck_id as usize) {
                    state.total_frames = *total_frames;
                }
                self.spawn_waveform(*deck_id, pipeline);
                self.push_lines(response::format_response(response, sample_rate));
            }
            CommandResponse::FxState { chain, slots } => {
                // A poll, not a command: record it silently, or a 10Hz knob read would flood the
                // response log.
                if let FxChainId::Deck(deck_id) = chain {
                    if let Some(slot) = self.deck_fx.get_mut(*deck_id as usize) {
                        *slot = slots.clone();
                    }
                    self.clamp_fx_slot(*deck_id as usize);
                }
                self.fx_pending = self.fx_pending.saturating_sub(1);
            }
            CommandResponse::FxListed { .. } => {
                self.fx_slots.record(response);
                self.push_lines(response::format_response(response, sample_rate));
            }
            CommandResponse::FxAdded { .. } => {
                self.fx_slots.record(response);
                self.push_lines(response::format_response(response, sample_rate));
            }
            _ => self.push_lines(response::format_response(response, sample_rate)),
        }
    }

    fn set_state(&mut self, state: &DeckState) {
        if let Some(slot) = self.states.get_mut(state.deck_id as usize) {
            *slot = state.clone();
        }
    }

    /// Builds the peak pyramid off the UI thread. `deck_source` is a cheap producer query, so the
    /// brief round-trip happens here; the O(track) scan does not.
    fn spawn_waveform(&self, deck_id: u8, pipeline: &AudioPipeline) {
        let Some(source) = pipeline.deck_source(deck_id) else {
            return;
        };
        let tx = self.waveform_tx.clone();
        let index = deck_id as usize;
        let low_hz = f32::from(self.waveform_low_hz);
        let high_hz = f32::from(self.waveform_high_hz);
        let sample_rate = self.sample_rate;
        std::thread::Builder::new()
            .name(format!("pipefader-waveform-{deck_id}"))
            .spawn(move || {
                let waveform = Arc::new(library::Waveform::build_with_crossovers_at(
                    source.as_ref(),
                    low_hz,
                    high_hz,
                    sample_rate,
                ));
                let _ = tx.send((index, waveform));
            })
            .ok();
    }

    /// Reads the embedded cover off the UI thread. Missing artwork is a normal answer (`None`), not
    /// an error: most WAV files have none, and the header falls back to a colour block.
    fn spawn_cover(&mut self, deck: usize, path: String) {
        if let Some(slot) = self.covers.get_mut(deck) {
            *slot = None;
        }
        let tx = self.cover_tx.clone();
        std::thread::Builder::new()
            .name(format!("pipefader-cover-{deck}"))
            .spawn(move || {
                let cover = media::read_cover(&path).map(Arc::new);
                let _ = tx.send((deck, cover));
            })
            .ok();
    }

    /// The value a knob currently shows, or `None` when the deck's chain has no such slot (a custom
    /// topologies may omit `eq`/`filter` entirely).
    pub fn knob_value(&self, deck: usize, knob: Knob) -> Option<f32> {
        if knob == Knob::Gain {
            return self
                .meters
                .as_ref()
                .and_then(|meters| meters.channels.get(deck))
                .map(|levels| levels.gain);
        }
        let (role, param) = match knob {
            Knob::Gain => unreachable!("handled above"),
            Knob::High => ("eq", "high"),
            Knob::Mid => ("eq", "mid"),
            Knob::Low => ("eq", "low"),
            // Matched by **role**, not kind: the filter slot can hold `moog` instead of `filter`
            // without the knob losing its home.
            Knob::Filter => ("filter", "value"),
        };
        self.deck_fx
            .get(deck)?
            .iter()
            .find(|slot| slot.role.eq_ignore_ascii_case(role))
            .and_then(|slot| {
                slot.params
                    .iter()
                    .find(|param_status| param_status.name == param)
                    .map(|param_status| param_status.value)
            })
    }

    /// The slot index of a knob's effect in the deck chain, for [`Command::SetFxParam`].
    ///
    /// Addressed by role so a swapped effect (`filter` → `moog`) stays under the same knob.
    pub fn knob_slot(&self, deck: usize, knob: Knob) -> Option<usize> {
        let role = match knob {
            Knob::Gain => return None,
            Knob::High | Knob::Mid | Knob::Low => "eq",
            Knob::Filter => "filter",
        };
        self.deck_fx
            .get(deck)?
            .iter()
            .find(|slot| slot.role.eq_ignore_ascii_case(role))
            .map(|slot| slot.index)
    }

    /// The mixer's position for a deck's channel fader.
    pub fn fader_value(&self, deck: usize) -> Option<f32> {
        self.meters
            .as_ref()?
            .channels
            .get(deck)
            .map(|levels| levels.deck)
    }

    /// Master peak and cue peak, linear.
    pub fn peaks(&self) -> (f32, f32, Vec<f32>) {
        match self.meters.as_ref() {
            Some(meters) => (
                meters.master_peak,
                meters.cue_peak,
                meters.deck_peaks.clone(),
            ),
            None => (0.0, 0.0, Vec::new()),
        }
    }

    /// Drains every side channel without blocking. Returns true if anything changed.
    pub fn drain(&mut self) -> bool {
        let mut changed = false;
        while let Ok(line) = self.notice_rx.try_recv() {
            self.push_log(line);
            changed = true;
        }
        while let Ok(event) = self.event_rx.try_recv() {
            match event {
                UiEvent::Loaded { deck_id, path } => {
                    if let Some(title) = self.titles.get_mut(deck_id as usize) {
                        *title = std::path::Path::new(&path)
                            .file_name()
                            .map(|name| name.to_string_lossy().into_owned());
                    }
                    self.spawn_cover(deck_id as usize, path);
                }
                UiEvent::Grid { deck_id, analysis } => {
                    if let Some(grid) = self.grids.get_mut(deck_id as usize) {
                        *grid = Some(analysis.beatgrid);
                    }
                }
            }
            changed = true;
        }
        while let Ok((index, cover)) = self.cover_rx.try_recv() {
            if let Some(slot) = self.covers.get_mut(index) {
                *slot = cover;
            }
            changed = true;
        }
        while let Ok((index, waveform)) = self.waveform_rx.try_recv() {
            if let Some(slot) = self.waveforms.get_mut(index) {
                *slot = Some(waveform);
            }
            changed = true;
        }
        // Scan progress comes from the library's own worker. The front-end only maps it onto the
        // browser and the log; it never scans, watches removable media, or owns a db write here.
        // Pull the events under the lock, then drop it before touching `self`: the dispatcher may
        // be waiting to enqueue a `browser refresh`, and `reload_browser` reads the db itself.
        let events = {
            let scan = self.scan.lock().expect("scan service lock");
            let mut events = Vec::new();
            while let Some(event) = scan.poll_next() {
                events.push(event);
            }
            events
        };
        let scan_changed = !events.is_empty();
        // Reload only when what the browser *shows* can have changed. A rebuild resets navigation
        // state, so a refresh on every event would make the browser flicker after each scan.
        let mut reload = false;
        for event in events {
            match event {
                ScanProgress::SourceRegistered { source_id, .. } => {
                    self.allowed_sources.insert(source_id);
                    // Redraw now so a freshly mounted device shows all of its sources together,
                    // each still carrying its cached tracks until its own pass reports.
                    reload = true;
                }
                ScanProgress::SourcesRemoved { source_ids } => {
                    for id in source_ids {
                        self.allowed_sources.remove(&id);
                    }
                    reload = true;
                }
                ScanProgress::ListsReady { name, .. } => {
                    reload = true;
                    self.push_log(LogLine::info(format!(
                        "[library] {name}: lists ready, reading track metadata"
                    )));
                }
                ScanProgress::SourceDone {
                    name, kind, stats, ..
                } => {
                    // A scan that only re-confirmed what the cache already had produces the very
                    // same rows; rebuilding the browser for it is what made it flash.
                    if stats.files_added > 0 || stats.files_removed > 0 {
                        reload = true;
                    }
                    self.push_log(LogLine::info(format!(
                        "[library] {name} [{kind}]: {}",
                        stats.summary()
                    )));
                }
                ScanProgress::Failed { name, error, .. } => {
                    self.push_log(LogLine::error(format!("[library] {name}: {error}")))
                }
            }
        }
        if scan_changed {
            changed = true;
        }
        if reload {
            self.reload_browser();
        }
        // The command fan-out and the MIDI router both leave one lightweight intent; apply the
        // newest one after the other side channels so a mode/panel change wins over stale data.
        let intent = self.intent.lock().ok().and_then(|mut slot| slot.take());
        if let Some(intent) = intent {
            self.apply_intent(intent);
            changed = true;
        }
        while let Ok(event) = self.mode_rx.try_recv() {
            if let Some(intent) = crate::intent::from_mode_event(&event, self.decks) {
                self.apply_intent(intent);
                changed = true;
            }
        }
        changed
    }

    /// The deck a *UI affordance* acts on when it needs one (the bare-`load` picker, a browser
    /// load): the targeted deck, or the last focused one while the browser is the target. Deck
    /// commands do not use this — they need a real deck target (`command::Target::Unset`).
    pub fn default_deck(&self) -> usize {
        match self.target {
            Target::Deck(index) => index,
            Target::Browser => self.focused,
        }
    }

    /// Cycles the command target: deck0 → deck1 → … → browser → deck0. The browser has no CLI
    /// prefix yet, but it is already a stop on the ring.
    pub fn cycle_target(&mut self, delta: isize) {
        let slots = self.decks as isize + 1;
        let current = match self.target {
            Target::Deck(index) => index as isize,
            Target::Browser => self.decks as isize,
        };
        let next = (current + delta).rem_euclid(slots) as usize;
        self.target = if next == self.decks {
            Target::Browser
        } else {
            Target::Deck(next)
        };
        if let Target::Deck(index) = self.target {
            self.focused = index;
            self.show_deck(index);
        }
    }

    /// The decks the control band draws, in column order (one per column, never more, never twice).
    pub fn page_decks(&self) -> impl Iterator<Item = usize> + '_ {
        self.slots
            .iter()
            .copied()
            .enumerate()
            .filter(|(column, deck)| *deck < self.decks && (*column == 0 || *deck != self.slots[0]))
            .map(|(_, deck)| deck)
    }

    /// Brings `deck` under the control band: what `Tab` does when it picks a deck, so the columns
    /// below always describe a deck the command line can reach. A deck always lands on its own
    /// column (index 0 is the left half, 1 the right), which is the column its toggle cycles.
    pub fn show_deck(&mut self, deck: usize) {
        if deck < self.decks {
            self.slots[deck % DECKS_PER_PAGE] = deck;
        }
    }

    /// The decks one column toggles through: deck1 ⇄ deck3 on the left, deck2 ⇄ deck4 on the right
    /// for a four-deck rig. One column per parity keeps the two halves off the same deck.
    pub fn column_decks(&self, column: usize) -> impl Iterator<Item = usize> + '_ {
        (column % DECKS_PER_PAGE..self.decks).step_by(DECKS_PER_PAGE)
    }

    /// Cycles one column's deck, wrapping. It touches that column only: the other half keeps the
    /// deck it was driving, which is what makes "flip the left side to deck 3" a single click.
    pub fn cycle_slot(&mut self, column: usize, delta: isize) {
        let column = column % DECKS_PER_PAGE;
        let decks: Vec<usize> = self.column_decks(column).collect();
        if decks.is_empty() {
            return;
        }
        let at = decks
            .iter()
            .position(|deck| *deck == self.slots[column])
            .unwrap_or(0) as isize;
        self.slots[column] = decks[(at + delta).rem_euclid(decks.len() as isize) as usize];
    }

    pub fn zoom_in(&mut self) {
        self.frames_per_cell = (self.frames_per_cell / 2.0).max(MIN_FRAMES_PER_CELL);
    }

    pub fn zoom_out(&mut self) {
        self.frames_per_cell = (self.frames_per_cell * 2.0).min(MAX_FRAMES_PER_CELL);
    }

    /// Fits the longest loaded track into the current viewport. A no-op until a track is loaded.
    pub fn fit(&mut self) {
        let longest = self
            .states
            .iter()
            .map(|state| state.total_frames)
            .max()
            .unwrap_or(0);
        if longest == 0 || self.wave_width_cells == 0 {
            return;
        }
        self.frames_per_cell = (longest as f64 / self.wave_width_cells as f64)
            .clamp(MIN_FRAMES_PER_CELL, MAX_FRAMES_PER_CELL);
    }

    pub fn log_scroll(&mut self, delta: isize) {
        // The response pane wraps lines, so its real height is known only at render time. Keep the
        // requested visual-line offset here; the renderer clamps it to the wrapped total.
        self.log_offset = (self.log_offset as isize + delta).max(0) as usize;
    }
}

pub fn home_dir() -> Option<PathBuf> {
    // Which variable wins is a platform question, not a matter of taste: on Windows `HOME` is
    // whatever the *shell* thinks (MSYS/Git Bash write `/c/Users/me`, WSL `/mnt/c/...`), and a native
    // process cannot open those spellings, while `USERPROFILE` is the real profile directory.
    let names: &[&str] = if cfg!(windows) {
        &["USERPROFILE", "HOME"]
    } else {
        &["HOME", "USERPROFILE"]
    };
    names
        .iter()
        .find_map(|name| {
            std::env::var_os(name)
                .filter(|value| !value.is_empty())
                .map(PathBuf::from)
        })
        // The last resort on a Windows session that has been stripped down to a login shell.
        .or_else(|| {
            let drive = std::env::var_os("HOMEDRIVE")?;
            let path = std::env::var_os("HOMEPATH")?;
            let mut home = PathBuf::from(drive);
            home.push(path);
            Some(home)
        })
}

pub fn music_dir() -> Option<PathBuf> {
    home_dir().map(|home| home.join("Music"))
}

pub fn expand_tilde(path: &str, home: Option<&Path>) -> PathBuf {
    if let Some(home) = home {
        if let Some(rest) = path.strip_prefix("~/").or_else(|| path.strip_prefix("~\\")) {
            return home.join(rest);
        }
        if path == "~" {
            return home.to_path_buf();
        }
    }
    PathBuf::from(path)
}

pub fn expand_home(path: &str) -> PathBuf {
    expand_tilde(path, home_dir().as_deref())
}

/// Moves the preferred root to the front, so `Browser::load_sources` opens it first.
pub fn prefer_source(mut sources: Vec<Source>, preferred: Option<&Path>) -> Vec<Source> {
    if let Some(index) =
        preferred.and_then(|root| sources.iter().position(|source| source.root == root))
    {
        sources.rotate_left(index);
    }
    sources
}

pub fn local_roots(kind: SourceKind) -> Vec<PathBuf> {
    let Some(home) = home_dir() else {
        return Vec::new();
    };
    let mut roots = match kind {
        SourceKind::Rekordbox => vec![
            home.join(".config/rekordbox"),
            home.join("rekordbox"),
            home.join("Music"),
        ],
        SourceKind::Serato => vec![home.join("Music"), home.clone()],
        _ => vec![
            home.join(".VirtualDJ"),
            home.join("VirtualDJ"),
            home.join("Music"),
            home.clone(),
        ],
    };
    roots.dedup();
    roots
}

/// The sessions [`AppState::connect_midi`] should open.
///
/// The configured `[[controller]]` list is the normal source, but the F9 picker is a *runtime*
/// choice: when it names a port, that port (and the picked map) must win over the first entry even
/// if the config left every controller key commented out. Without this, the template's empty
/// `[controller]` section would look like a configured-but-portless controller and silently swallow
/// the user's pick.
pub fn connection_specs(
    sessions: &[crate::config::profile::ControllerSession],
    midi_port: Option<&str>,
    midi_map: Option<&str>,
    routes: &controller::map::DeckRoutes,
) -> Vec<crate::config::profile::ControllerSession> {
    let mut specs = sessions.to_vec();
    let Some(port) = midi_port else {
        return specs;
    };
    match specs.first_mut() {
        Some(first) => {
            first.port = Some(port.to_owned());
            if let Some(map) = midi_map {
                first.map = map.to_owned();
            }
        }
        None => specs.push(crate::config::profile::ControllerSession {
            id: "default".to_owned(),
            port: Some(port.to_owned()),
            map: midi_map
                .map(str::to_owned)
                .unwrap_or_else(|| crate::config::profile::default_map_path().to_owned()),
            routes: routes.clone(),
        }),
    }
    specs
}

impl AppState {
    /// Opens the remembered port with the remembered map, replacing any current input.
    ///
    /// FX names are resolved from the **already-primed slot book**, not by asking the engine: it
    /// runs inside the UI thread, and reading the shared response channel here would swallow a
    /// `Loaded`/`States`/`Error` answer meant for the UI. A failure is logged and returned as a
    /// [`MidiRetry`] so the front-end can reopen the matching picker.
    pub fn connect_midi(
        &mut self,
        command_tx: Sender<Command>,
        notices: &NoticeTx,
        dispatcher: &crate::command::Dispatcher,
    ) -> Option<MidiRetry> {
        let mut retry = None;
        let specs = connection_specs(
            &self.controller_sessions,
            self.midi_port.as_deref(),
            self.midi_map.as_deref(),
            &self.deck_routes,
        );
        if specs.is_empty() {
            return None;
        }
        // Dropping the old sessions closes their ports before the new ones open.
        self.midi.clear();
        let slots = self.fx_slots.clone();
        let mode_tx = self.mode_sender();
        let mut first = true;
        for spec in specs {
            let Some(port) = spec.port.clone() else {
                continue;
            };
            let (mut map, mut mirror_map) =
                match crate::midi::read_map_pair(&spec.map, &spec.routes) {
                    Ok(pair) => pair,
                    Err(err) => {
                        self.push_log(LogLine::error(format!("controller `{}`: {err}", spec.id)));
                        retry.get_or_insert(MidiRetry::Map(spec.map.clone()));
                        continue;
                    }
                };
            let unresolved = crate::midi::resolve_with(&mut map, |chain, fx| {
                slots.resolve(&chain.label(), fx).ok()
            });
            crate::midi::report_unresolved(notices, unresolved);
            mirror_map.copy_fx_slots(&map);
            match crate::midi::attach(
                &port,
                map,
                mirror_map,
                command_tx.clone(),
                Some(self.browser_tx.clone()),
                Some(mode_tx.clone()),
            ) {
                Ok(session) => {
                    // The dispatcher's single control/state pair follows the first controller.
                    if first {
                        dispatcher.set_midi(session.control(), session.state());
                        first = false;
                    }
                    self.push_log(LogLine::info(format!(
                        "[controller] `{}` connected `{port}` ({})",
                        spec.id, spec.map
                    )));
                    self.midi.push(session);
                }
                Err(err) => {
                    self.push_log(LogLine::error(format!("controller `{}`: {err}", spec.id)));
                    retry.get_or_insert(MidiRetry::Ports);
                }
            }
        }
        retry
    }
}

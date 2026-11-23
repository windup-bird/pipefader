//! The Flutter-facing surface. Every function here runs on an FRB worker thread; the
//! engine's real-time producer thread is never touched directly.
//!
//! Deliberately not a mirror of [`protocol::Command`]. Actions are grouped by what the UI
//! actually does, state is pushed as a tick, and the query functions return plain data.

use crate::frb_generated::StreamSink;

use crate::session;

// ---------------------------------------------------------------------------
// Data returned to Dart
// ---------------------------------------------------------------------------

/// One deck's transport/performance state, sampled on the producer thread.
pub struct DeckTick {
    pub deck: u8,
    pub frame: u64,
    pub total_frames: u64,
    pub sample_rate: u32,
    pub playing: bool,
    pub tempo: f32,
    pub tempo_range: f32,
    /// The track grid's local BPM at the audible position (`0` without a grid).
    pub bpm_at_frame: f32,
    /// `bpm_at_frame * playing_rate`: what the BPM readout shows.
    pub bpm: f32,
    pub playing_rate: f32,
    pub key: String,
    pub sync_mode: String,
    /// `None` when this deck is not following another one.
    pub sync_leader: Option<u8>,
    pub keylock: bool,
    pub loop_active: bool,
    pub loop_in: u64,
    pub loop_out: u64,
    pub loop_armed: bool,
    pub loop_beats_num: u32,
    pub loop_beats_den: u32,
    pub jump_beats: i64,
    pub cue_frame: u64,
    /// The lit hot-cue slots (0-based). Frames are available in [`Self::hot_cue_frames`].
    pub hot_cues: Vec<u8>,
    pub hot_cue_frames: Vec<u64>,
    pub vinyl: bool,
    pub nudge: f32,
    /// Rust-computed overlay columns for the current viewport.
    pub wave: WaveHints,
    pub stems_ready: bool,
    pub stems_separated: f32,
}

/// One mixer channel's performance positions, straight from the engine's meters query.
pub struct ChannelTick {
    pub flow: f32,
    pub deck: f32,
    pub crossfader: f32,
    pub cue_send: f32,
    pub gain: f32,
}

/// Cue/loop/grid furniture for one deck's scrolling waveform. Columns are
/// screen pixels from the left edge, computed against the last view the UI sent.
pub struct WaveHotCue {
    pub slot: u8,
    pub column: f32,
    pub frame: u64,
}

pub struct WaveHints {
    pub width: f32,
    pub frames_per_pixel: f64,
    /// Left edge of the viewport, so the waveform and its markers share one
    /// projection even when Flutter interpolates the playhead between ticks.
    pub start_frame: f64,
    pub beats: Vec<f32>,
    pub bars: Vec<f32>,
    pub loop_start: Option<f32>,
    pub loop_end: Option<f32>,
    pub loop_armed: Option<f32>,
    pub cue: Option<f32>,
    pub hot_cues: Vec<WaveHotCue>,
}

pub struct Tick {
    pub decks: Vec<DeckTick>,
    pub channels: Vec<ChannelTick>,
    pub master_peak: f32,
    pub cue_peak: f32,
    pub deck_peaks: Vec<f32>,
    pub fx: Vec<DeckFxTick>,
}

pub struct DeckFxTick {
    pub deck: u8,
    pub slots: Vec<FxSlotDto>,
}

pub struct FxSlotDto {
    pub index: u32,
    pub role: String,
    pub kind: String,
    pub enabled: bool,
    pub params: Vec<FxParamDto>,
}

pub struct FxParamDto {
    pub name: String,
    pub value: f32,
    /// `None` means "display as text, not a bar".
    pub min: Option<f32>,
    pub max: Option<f32>,
    /// `0` = not a beat division; positive = whole beats; negative = 1 / -beats.
    pub beats: i32,
}

/// Static deck identity, sent when a track is installed and available on demand.
#[derive(Clone)]
pub struct DeckMeta {
    pub deck: u8,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub key: String,
    pub bpm: f32,
    pub sample_rate: u32,
    pub total_frames: u64,
    pub first_beat: u64,
    pub location_id: i32,
}

pub struct WaveformData {
    /// Number of columns in each band.
    pub columns: u32,
    pub total_frames: u64,
    pub left_low: Vec<u8>,
    pub left_mid: Vec<u8>,
    pub left_high: Vec<u8>,
    pub right_low: Vec<u8>,
    pub right_mid: Vec<u8>,
    pub right_high: Vec<u8>,
}

/// A viewport-sized slice of the waveform pyramid, sent with one screen of
/// overscan on each side so Flutter only re-reads it when the playhead leaves
/// the safe middle. Bands are 0..255, one value per column.
pub struct WaveStrip {
    pub start_frame: f64,
    pub frames_per_pixel: f64,
    pub columns: u32,
    pub left_low: Vec<u8>,
    pub left_mid: Vec<u8>,
    pub left_high: Vec<u8>,
    pub right_low: Vec<u8>,
    pub right_mid: Vec<u8>,
    pub right_high: Vec<u8>,
}

/// The one palette both front-ends draw with. `0x00000000`-style ARGB values;
/// hot cues are indexed 0..8.
pub struct WavePaletteDto {
    pub low: u32,
    pub mid: u32,
    pub high: u32,
    pub beat: u32,
    pub bar: u32,
    pub loop_wash: u32,
    pub center: u32,
    pub playhead: u32,
    pub memory_cue: u32,
    pub hot_cues: Vec<u32>,
}

pub struct CoverData {
    pub width: u32,
    pub height: u32,
    /// Row-major RGBA.
    pub rgba: Vec<u8>,
}

pub struct LibraryRoot {
    pub id: i32,
    pub name: String,
    pub kind: String,
}

pub struct LibraryList {
    pub id: i32,
    pub source_id: i32,
    pub name: String,
    pub kind: String,
}

pub struct TrackDto {
    pub track_id: i32,
    pub location_id: i32,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub bpm: f32,
    pub key: String,
    pub seconds: u32,
    pub sample_rate: u32,
}

pub struct LogDto {
    pub error: bool,
    pub text: String,
}

pub enum EventKind {
    Tick,
    Loaded,
    WaveformReady,
    CoverReady,
    Log,
    LibraryChanged,
    Stopped,
}

/// Events pushed from the session thread. The fields not used by a particular [`EventKind`]
/// stay at their defaults; a flat struct avoids pulling `freezed` into the Flutter package for
/// one Rust enum with payloads.
pub struct SessionEvent {
    pub kind: EventKind,
    pub tick: Option<Tick>,
    pub deck: u8,
    pub meta: Option<DeckMeta>,
    pub error: bool,
    pub text: String,
}

// ---------------------------------------------------------------------------
// Actions. These map onto `protocol::Command`, but the FFI never exposes that enum.
// ---------------------------------------------------------------------------

pub enum TransportAction {
    Toggle,
    Play,
    Pause,
}

pub enum CueAction {
    /// The clicking-UI cue button: press then release is resolved by the deck.
    Button,
    Play,
    Back,
    Set,
    Smart,
}

pub enum HotCueAction {
    Set,
    Trigger,
    Clear,
}

pub enum VinylAction {
    Touch,
    Release,
    Slip,
}

pub enum SyncAction {
    /// One-shot tempo match.
    Tempo,
    /// One-shot tempo match plus an instant phase jump.
    Phase,
    TempoLock,
    PhaseLock,
    SetLeader,
    Unlock,
    /// Flip between a tempo lock and free, resolved by the engine.
    Toggle,
}

pub enum NudgeAction {
    /// Hold the bend in the negative direction.
    Left,
    /// Hold the bend in the positive direction.
    Right,
    Stop,
}

pub enum LoopAction {
    In,
    Out,
    Cancel,
    Exit,
    Toggle,
    SlipIn,
    SlipOut,
    Halve,
    Double,
}

pub enum LevelKind {
    Flow,
    Stem,
    Deck,
    Gain,
    CueSend,
    /// The two-deck default crossfader.
    Crossfader,
    Master,
    Cue,
}

pub struct LevelTarget {
    pub kind: LevelKind,
    /// Deck for the deck-scoped kinds; ignored for master/cue/crossfader.
    pub deck: u8,
    /// Stem index for [`LevelKind::Stem`]: 0 drums, 1 bass, 2 other, 3 vocals.
    pub stem: u8,
}

pub enum EqBand {
    High,
    Mid,
    Low,
    Filter,
}

pub enum FxOp {
    SetParam,
    Enable,
    Disable,
    Trigger,
    MomentaryDown,
    MomentaryUp,
}

// ---------------------------------------------------------------------------
// Lifecycle and state stream
// ---------------------------------------------------------------------------

/// Boots the engine, config, library and state pump. Idempotent: a second call while a
/// session is alive is a no-op, which is what Flutter hot restart needs.
pub fn start(config_path: Option<String>) -> Result<(), String> {
    session::start(config_path)
}

/// Releases the engine and joins its threads. Safe to call when nothing is running.
pub fn shutdown() -> Result<(), String> {
    session::shutdown()
}

/// Replaces the event sink. The pump also sends a full tick as soon as the next frame runs.
pub fn subscribe(sink: StreamSink<SessionEvent>) -> Result<(), String> {
    session::subscribe(sink)
}

/// Tells Rust the current scrolling-waveform geometry. Called when the widget
/// is laid out or zoomed, not every frame; the tick then carries the marker
/// columns computed from it.
pub fn set_wave_view(width: f64, frames_per_pixel: f64) -> Result<(), String> {
    session::set_wave_view(width, frames_per_pixel)
}

pub fn waveform(deck: u8) -> Result<Option<WaveformData>, String> {
    session::waveform(deck)
}

/// The scrolling waveform's actual peaks at the requested sampling grid.
pub fn waveform_strip(
    deck: u8,
    center_frame: u64,
    frames_per_pixel: f64,
    columns: u32,
) -> Result<Option<WaveStrip>, String> {
    session::waveform_strip(deck, center_frame, frames_per_pixel, columns)
}

pub fn wave_palette() -> Result<WavePaletteDto, String> {
    session::wave_palette()
}

pub fn cover(deck: u8) -> Result<Option<CoverData>, String> {
    session::cover(deck)
}

pub fn deck_meta(deck: u8) -> Result<Option<DeckMeta>, String> {
    session::deck_meta(deck)
}

pub fn logs() -> Result<Vec<LogDto>, String> {
    session::logs()
}

// ---------------------------------------------------------------------------
// Transport and performance
// ---------------------------------------------------------------------------

pub fn transport(deck: u8, action: TransportAction) -> Result<(), String> {
    session::transport(deck, action)
}

pub fn cue(deck: u8, action: CueAction) -> Result<(), String> {
    session::cue(deck, action)
}

pub fn hot_cue(deck: u8, slot: u8, action: HotCueAction) -> Result<(), String> {
    session::hot_cue(deck, slot, action)
}

pub fn vinyl(deck: u8, action: VinylAction) -> Result<(), String> {
    session::vinyl(deck, action)
}

pub fn vinyl_turn(deck: u8, ticks: i32, frames_per_tick: f32) -> Result<(), String> {
    session::vinyl_turn(deck, ticks, frames_per_tick)
}

pub fn seek(deck: u8, frame: u64) -> Result<(), String> {
    session::seek(deck, frame)
}

pub fn beat_jump(deck: u8, beats: i32) -> Result<(), String> {
    session::beat_jump(deck, beats)
}

pub fn jump_step(deck: u8, direction: i32) -> Result<(), String> {
    session::jump_step(deck, direction)
}

pub fn scale_jump(deck: u8, halve: bool) -> Result<(), String> {
    session::scale_jump(deck, halve)
}

pub fn set_tempo(deck: u8, tempo: f32) -> Result<(), String> {
    session::set_tempo(deck, tempo)
}

pub fn set_tempo_fader(deck: u8, position: f32) -> Result<(), String> {
    session::set_tempo_fader(deck, position)
}

pub fn set_tempo_range(deck: u8, range: f32) -> Result<(), String> {
    session::set_tempo_range(deck, range)
}

pub fn sync(deck: u8, action: SyncAction) -> Result<(), String> {
    session::sync(deck, action)
}

pub fn nudge(deck: u8, action: NudgeAction) -> Result<(), String> {
    session::nudge(deck, action)
}

pub fn bend(deck: u8, delta: f32) -> Result<(), String> {
    session::bend(deck, delta)
}

pub fn set_keylock(deck: u8, on: bool) -> Result<(), String> {
    session::set_keylock(deck, on)
}

pub fn set_key(deck: u8, semitones: i32) -> Result<(), String> {
    session::set_key(deck, semitones)
}

pub fn loop_action(deck: u8, action: LoopAction) -> Result<(), String> {
    session::loop_action(deck, action)
}

pub fn loop_beats(deck: u8, num: u32, den: u32) -> Result<(), String> {
    session::loop_beats(deck, num, den)
}

pub fn set_level(target: LevelTarget, value: f32) -> Result<(), String> {
    session::set_level(target, value)
}

pub fn set_crossfader(value: f32) -> Result<(), String> {
    session::set_crossfader(value)
}

pub fn toggle_cue_send(deck: u8) -> Result<(), String> {
    session::toggle_cue_send(deck)
}

pub fn set_eq(deck: u8, band: EqBand, value: f32) -> Result<(), String> {
    session::set_eq(deck, band, value)
}

pub fn fx(deck: u8, slot: u32, op: FxOp, param: u32, value: f32) -> Result<(), String> {
    session::fx(deck, slot, op, param, value)
}

pub fn fx_add(deck: u8, kind: String) -> Result<(), String> {
    session::fx_add(deck, kind)
}

pub fn fx_remove(deck: u8, slot: u32) -> Result<(), String> {
    session::fx_remove(deck, slot)
}

pub fn fx_select(deck: u8, slot: u32, kind: String) -> Result<(), String> {
    session::fx_select(deck, slot, kind)
}

// ---------------------------------------------------------------------------
// Loading and library
// ---------------------------------------------------------------------------

pub fn load_path(deck: u8, path: String, bpm: Option<f32>) -> Result<(), String> {
    session::load_path(deck, path, bpm)
}

pub fn load_track(deck: u8, location_id: i32) -> Result<(), String> {
    session::load_track(deck, location_id)
}

pub fn analyse_track(location_id: i32) -> Result<(), String> {
    session::analyse_track(location_id)
}

pub fn library_roots() -> Result<Vec<LibraryRoot>, String> {
    session::library_roots()
}

pub fn library_lists(source_id: i32) -> Result<Vec<LibraryList>, String> {
    session::library_lists(source_id)
}

pub fn library_tracks(playlist_id: i32) -> Result<Vec<TrackDto>, String> {
    session::library_tracks(playlist_id)
}

pub fn library_search(query: String, limit: u32) -> Result<Vec<TrackDto>, String> {
    session::library_search(query, limit)
}

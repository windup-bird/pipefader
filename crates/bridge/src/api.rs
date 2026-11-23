//! The Flutter-facing surface. Every function here runs on an FRB worker thread; the
//! engine's real-time producer thread is never touched directly.
//!
//! Deliberately not a mirror of [`protocol::Command`]. Actions are grouped by what the UI
//! actually does, state is pushed as a tick, and the query functions return plain data.

use crate::frb_generated::StreamSink;

use crate::session;
use app::config::{map, output, profile, settings};
use protocol::OutputRole;

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

/// One mixer destination, as the logo menu's Output page shows it.
pub struct OutputDto {
    /// Position in the profile's `[[mixer.output]]` array.
    pub index: u32,
    pub name: String,
    /// `master` or `cue` (the menu spells the latter "precue").
    pub role: String,
    /// Empty when the destination uses the host's default device.
    pub device: String,
    /// Empty when the file did not name a channel pair.
    pub channels: Vec<u16>,
    pub gain: f32,
}

/// One MIDI input the host currently offers.
pub struct MidiPortDto {
    pub index: u32,
    pub name: String,
}

/// One controller-map file the profile can point at.
pub struct MapFileDto {
    pub path: String,
    pub name: String,
    pub builtin: bool,
}

/// Everything the logo menu needs from the session's profile.
pub struct MenuStateDto {
    pub profile: String,
    pub builtin: bool,
    pub midi_port: String,
    pub midi_map: String,
    pub outputs: Vec<OutputDto>,
    pub sample_rate: u32,
    pub crossfader_curve: String,
    pub cue_blend: f32,
    pub autogain: bool,
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
// The logo menu: profile, outputs, MIDI and a few machine settings
// ---------------------------------------------------------------------------

/// The menu's whole readable state. Outputs and settings come from the same `app` readers the TUI
/// uses, so a hand-written profile is interpreted identically by both front-ends.
pub fn menu_state() -> Result<MenuStateDto, String> {
    read_menu_state()
}

fn read_menu_state() -> Result<MenuStateDto, String> {
    let profile_path = session::config_path()?;
    let config = profile::load_source(&profile_path)?;
    let outputs = output::read(&profile_path)?
        .into_iter()
        .map(|entry| OutputDto {
            index: entry.index as u32,
            role: entry.role_name().to_owned(),
            name: entry.name,
            device: entry.device.unwrap_or_default(),
            channels: entry
                .channels
                .map(|(left, right)| vec![left, right])
                .unwrap_or_default(),
            gain: entry.gain,
        })
        .collect();
    let decoded = settings::read(&profile_path)?;
    let (midi_port, midi_map) = midi_pair(&config, &profile_path);
    Ok(MenuStateDto {
        profile: profile_path.clone(),
        builtin: profile::is_builtin(&profile_path),
        midi_port,
        midi_map,
        outputs,
        sample_rate: decoded.sample_rate,
        crossfader_curve: decoded.crossfader_curve,
        cue_blend: decoded.cue_blend,
        autogain: decoded.autogain,
    })
}

/// Adds a destination for a role. The GUI starts from one master and can add either role; the
/// channel pair is the first free stereo pair so two destinations never share a socket by accident.
pub fn output_add(role: String) -> Result<MenuStateDto, String> {
    let profile_path = session::config_path()?;
    let role = parse_role(&role)?;
    let entries = output::read(&profile_path).unwrap_or_default();
    let label = match role {
        OutputRole::Master => "Master",
        OutputRole::Cue => "Precue",
    };
    // Removing a middle destination must not make the next name collide with a survivor.
    let mut number = 1;
    while entries
        .iter()
        .any(|entry| entry.role == role && entry.name == format!("{label} {number}"))
    {
        number += 1;
    }
    let name = format!("{label} {number}");
    let channels = output::next_channels(&entries);
    output::add(&profile_path, &name, role, None, Some(channels))?;
    session::reload_mixer()?;
    read_menu_state()
}

/// Removes a destination. A mixer with no master output is not a useful state, so the last master is
/// kept; precue may be emptied.
pub fn output_remove(index: u32) -> Result<MenuStateDto, String> {
    let profile_path = session::config_path()?;
    let entries = output::read(&profile_path)?;
    let entry = entries
        .get(index as usize)
        .ok_or_else(|| format!("no output #{index}"))?;
    let masters = entries
        .iter()
        .filter(|entry| entry.role == OutputRole::Master)
        .count();
    if entry.role == OutputRole::Master && masters <= 1 {
        return Err("the last master output cannot be removed".to_owned());
    }
    output::remove(&profile_path, index as usize)?;
    session::reload_mixer()?;
    read_menu_state()
}

/// Re-probes every destination and returns the configured list. The live/missing state is not
/// reported yet; the engine logs it and a later tick can carry it if the UI needs it.
pub fn output_refresh() -> Result<MenuStateDto, String> {
    session::refresh_outputs()?;
    read_menu_state()
}

/// Every MIDI input the host currently reports. The menu compares the names with `midi_port`.
pub fn midi_ports() -> Result<Vec<MidiPortDto>, String> {
    controller::list_ports()
        .map(|ports| {
            ports
                .into_iter()
                .map(|port| MidiPortDto {
                    index: port.index as u32,
                    name: port.name,
                })
                .collect()
        })
        .map_err(|err| format!("midi: {err}"))
}

/// Records a new input in the profile and opens it live. A built-in profile is read-only, so the
/// menu shows the current input but disables switching there.
pub fn set_midi_port(port: String) -> Result<MenuStateDto, String> {
    let profile_path = session::config_path()?;
    if profile::is_builtin(&profile_path) {
        return Err("the built-in profile is read-only".to_owned());
    }
    profile::write_controller(std::path::Path::new(&profile_path), Some(&port), None)?;
    session::reconnect_midi(Some(port), None)?;
    read_menu_state()
}

/// The map choices: the built-in map plus every parseable `.toml` beside the profile. The current
/// map is always included, even when it lives outside that folder.
pub fn midi_maps() -> Result<Vec<MapFileDto>, String> {
    let profile_path = session::config_path()?;
    let config = profile::load_source(&profile_path)?;
    let (_, current) = midi_pair(&config, &profile_path);
    let mut maps: Vec<MapFileDto> = map::candidates(&profile_path)
        .into_iter()
        .map(|entry| MapFileDto {
            path: entry.path,
            name: entry.name,
            builtin: entry.builtin,
        })
        .collect();
    if !maps.iter().any(|entry| entry.path == current) {
        let name = std::path::Path::new(&current)
            .file_name()
            .map(|name| name.to_string_lossy().into_owned())
            .unwrap_or_else(|| current.clone());
        maps.insert(
            0,
            MapFileDto {
                path: current.clone(),
                name,
                builtin: profile::is_builtin(&current),
            },
        );
    }
    Ok(maps)
}

/// Points the controller at another map and reconnects with it. The built-in sentinel is preserved
/// in the profile rather than being treated as a relative path.
pub fn set_midi_map(map_path: String) -> Result<MenuStateDto, String> {
    let profile_path = session::config_path()?;
    if profile::is_builtin(&profile_path) {
        return Err("the built-in profile is read-only".to_owned());
    }
    // Reject a bad file before it becomes the profile's remembered map.
    let (text, base) = profile::read_map_text(&map_path)?;
    controller::Map::from_toml_str_at(&text, &base)
        .map_err(|err| format!("{map_path}: {err}"))?;
    profile::write_controller(
        std::path::Path::new(&profile_path),
        None,
        Some(std::path::Path::new(&map_path)),
    )?;
    session::reconnect_midi(None, Some(map_path))?;
    read_menu_state()
}

fn midi_pair(config: &profile::Config, profile_path: &str) -> (String, String) {
    let port = config
        .controller
        .device
        .clone()
        .or_else(|| {
            config
                .controllers
                .first()
                .and_then(|controller| controller.device.clone())
        })
        .unwrap_or_default();
    let map = config
        .controller
        .map
        .clone()
        .or_else(|| {
            config
                .controllers
                .first()
                .and_then(|controller| controller.map.clone())
        })
        .unwrap_or_else(|| profile::map_path_for(std::path::Path::new(profile_path)));
    (port, map)
}

/// Changes one machine setting and, when the engine can take it live, reloads the topology. The
/// sample rate is written but needs a restart, which the menu marks separately.
pub fn set_setting(key: String, value: String) -> Result<MenuStateDto, String> {
    let profile_path = session::config_path()?;
    settings::set(&profile_path, &key, &value)?;
    if !settings::SettingsSnapshot::needs_restart(&key) {
        session::reload_mixer()?;
    }
    read_menu_state()
}

fn parse_role(role: &str) -> Result<OutputRole, String> {
    match role.trim().to_ascii_lowercase().as_str() {
        "master" => Ok(OutputRole::Master),
        "cue" | "precue" => Ok(OutputRole::Cue),
        other => Err(format!("unknown output role `{other}` (master | precue)")),
    }
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

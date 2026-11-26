//! The one thread that owns the engine, the non-`Send` MIDI connections and the
//! response → view conversion. FFI functions only send it requests or push actions
//! straight into the engine's command queue.

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU8, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use app::command::{self, AutoAnalysis, Dispatcher};
use app::config::{preference, profile};
use app::state::AppState;
use app::waveform::{self as wave, WavePalette, WaveViewport};
use audio::{AudioPipeline, AudioTuning};
use crossbeam_channel::{bounded, unbounded, Receiver, Sender};
use library::analyser::Backends;
use library::LibraryDb;
use protocol::{
    Backend, BeatLen, BrowserAction, Command, CueOp, FaderTarget, FxChainId, FxSlotRef, HotCueOp, KeyFormat,
    KeylockMode, LoopOp, NudgeOp, OutputOp, Stem, SyncOp, VinylOp,
};

use crate::api::{
    BrowserCommand, ChannelTick, CoverData, CueAction, DeckFxTick, DeckMeta, DeckTick, EqBand, FxOp, FxParamDto,
    FxSlotDto, HotCueAction, LevelKind, LevelTarget, LibraryList, LibraryRoot, LibrarySourceDto,
    LogDto, LoopAction,
    NudgeAction, SessionEvent, SessionPathsDto, SyncAction, Tick, TrackDto, TransportAction,
    VinylAction, WaveHints, WaveHotCue, WavePaletteDto, WaveStrip, WaveformData,
};
use crate::logging;

/// How often the state pump pushes a tick. 60 Hz matches the display and the TUI's tick.
const TICK: Duration = Duration::from_millis(16);
/// Poll meters and FX at ~10 Hz, the same cadence as the TUI.
const SLOW_EVERY: u64 = 6;

pub(crate) enum StateRequest {
    Waveform {
        deck: u8,
        reply: Sender<Option<WaveformData>>,
    },
    Cover {
        deck: u8,
        reply: Sender<Option<CoverData>>,
    },
    Meta {
        deck: u8,
        reply: Sender<Option<DeckMeta>>,
    },
    SetMeta {
        deck: u8,
        meta: DeckMeta,
    },
    SetWaveView {
        width: f64,
        frames_per_pixel: f64,
    },
    WaveStrip {
        deck: u8,
        center_frame: u64,
        frames_per_pixel: f64,
        columns: u32,
        reply: Sender<Option<WaveStrip>>,
    },
    Logs {
        reply: Sender<Vec<LogDto>>,
    },
    /// Replace the MIDI input, and optionally the map, then re-read the pair.
    ReconnectMidi {
        port: Option<String>,
        map: Option<String>,
        reply: Sender<Result<(), String>>,
    },
    /// Clear the controller's device and close the open input.
    DisableMidi {
        reply: Sender<Result<(), String>>,
    },
    /// A preference the session thread owns (analysis backends, display, ...).
    ApplyPreference {
        key: String,
        value: String,
        reply: Sender<Result<(), String>>,
    },
    /// Re-read the library section and rescan/refresh the browser.
    SyncLibrary {
        path: String,
        reply: Sender<Result<(), String>>,
    },
    Shutdown {
        reply: Sender<()>,
    },
}

#[derive(Clone)]
pub(crate) struct BootData {
    pub dispatcher: Arc<Dispatcher>,
    pub browser_tx: Sender<BrowserAction>,
    pub library: Option<Arc<LibraryDb>>,
    pub sample_rate: u32,
    pub wave_palette: WavePalette,
    pub backends: Arc<Mutex<Backends>>,
    pub decoder_start_ms: Option<f64>,
    /// The profile source this session runs on, for the menu's config pages.
    pub config_path: String,
}

pub(crate) struct Handle {
    pub dispatcher: Arc<Dispatcher>,
    pub library: Option<Arc<LibraryDb>>,
    pub state_tx: Sender<StateRequest>,
    pub browser_tx: Sender<BrowserAction>,
    pub sink: Arc<Mutex<Option<crate::frb_generated::StreamSink<SessionEvent>>>>,
    pub alive: Arc<AtomicBool>,
    pub sample_rate: u32,
    pub wave_palette: WavePalette,
    pub backends: Arc<Mutex<Backends>>,
    pub decoder_start_ms: Option<f64>,
    pub config_path: String,
}

impl Handle {
    fn is_alive(&self) -> bool {
        self.alive.load(Ordering::SeqCst)
    }
}

static GLOBAL: Mutex<Option<Arc<Handle>>> = Mutex::new(None);

/// A value was written but not applied; the next start picks it up.
static RESTART_REQUIRED: AtomicBool = AtomicBool::new(false);

/// Display/key-format choices read by worker calls that do not hold `AppState`.
static KEY_FORMAT: AtomicU8 = AtomicU8::new(0);
static AUTO_ANALYSE: AtomicBool = AtomicBool::new(false);
static GRID_OFFSET_MS: Mutex<f64> = Mutex::new(0.0);

pub(crate) fn global() -> Result<Arc<Handle>, String> {
    let guard = GLOBAL
        .lock()
        .map_err(|_| "bridge lock poisoned".to_owned())?;
    match guard.as_ref() {
        Some(handle) if handle.is_alive() => Ok(Arc::clone(handle)),
        Some(_) => Err("the engine session has stopped".to_owned()),
        None => Err("the engine session has not been started".to_owned()),
    }
}

fn send_command(command: Command) -> Result<(), String> {
    let handle = global()?;
    handle
        .dispatcher
        .command_tx
        .send(command)
        .map_err(|_| "the engine is gone".to_owned())
}

fn ask<T>(request: impl FnOnce(Sender<T>) -> StateRequest) -> Result<T, String> {
    let handle = global()?;
    let (reply, answer) = bounded(1);
    handle
        .state_tx
        .send(request(reply))
        .map_err(|_| "the session thread is gone".to_owned())?;
    answer
        .recv_timeout(Duration::from_secs(5))
        .map_err(|_| "the session thread did not answer".to_owned())
}

/// Installs the host paths and returns the config file the session should load, plus whether the
/// built-in template may be copied there. A missing config falls back next to the cache dir so the
/// database and config stay together on Android.
fn install_paths(paths: Option<SessionPathsDto>) -> (Option<String>, bool) {
    let Some(paths) = paths else {
        return (None, false);
    };
    let config = match (paths.config.clone(), paths.cache.as_deref()) {
        (Some(config), _) => Some(config),
        (None, Some(cache)) => Some(
            Path::new(cache)
                .join("config.toml")
                .to_string_lossy()
                .into_owned(),
        ),
        (None, None) => None,
    };
    app::paths::install(app::paths::SessionPaths {
        config: config.clone().map(PathBuf::from),
        cache: paths.cache.map(PathBuf::from),
        media_home: paths.media_home.map(PathBuf::from),
        log_dir: paths.log.map(PathBuf::from),
    });
    (config, paths.seed)
}

pub(crate) fn start(paths: Option<SessionPathsDto>) -> Result<(), String> {
    let (config_path, seed) = install_paths(paths);
    logging::init(app::paths::log_dir().as_deref());
    logging::info("start: requested");
    if seed {
        if let Some(config) = app::paths::config() {
            let seeded = if cfg!(target_os = "android") {
                profile::seed_android(&config)
            } else {
                profile::seed(&config)
            };
            match seeded {
                Ok(map) => logging::info(format!(
                    "seed: {} (map {})",
                    config.display(),
                    map.display()
                )),
                Err(err) => {
                    logging::error(format!("seed: {err}"));
                    return Err(err);
                }
            }
        }
    }

    let mut guard = GLOBAL
        .lock()
        .map_err(|_| "bridge lock poisoned".to_owned())?;
    if let Some(handle) = guard.as_ref() {
        if handle.is_alive() {
            logging::info("start: session already alive");
            return Ok(());
        }
    }
    *guard = None;

    let (state_tx, state_rx) = unbounded();
    let (boot_tx, boot_rx) = bounded(1);
    let alive = Arc::new(AtomicBool::new(true));
    let sink: Arc<Mutex<Option<crate::frb_generated::StreamSink<SessionEvent>>>> =
        Arc::new(Mutex::new(None));

    let thread_alive = Arc::clone(&alive);
    let thread_sink = Arc::clone(&sink);
    thread::Builder::new()
        .name("pipefader-bridge".to_owned())
        .spawn(move || run(config_path, state_rx, thread_sink, thread_alive, boot_tx))
        .map_err(|err| format!("could not start the bridge thread: {err}"))?;

    match boot_rx.recv_timeout(Duration::from_secs(30)) {
        Ok(Ok(boot)) => {
            logging::info(format!("start: ready on {}", boot.config_path));
            *guard = Some(Arc::new(Handle {
                dispatcher: boot.dispatcher,
                browser_tx: boot.browser_tx,
                library: boot.library,
                state_tx,
                sink,
                alive,
                sample_rate: boot.sample_rate,
                wave_palette: boot.wave_palette,
                backends: boot.backends,
                decoder_start_ms: boot.decoder_start_ms,
                config_path: boot.config_path,
            }));
            Ok(())
        }
        Ok(Err(err)) => {
            logging::error(format!("start: failed: {err}"));
            alive.store(false, Ordering::SeqCst);
            Err(err)
        }
        Err(_) => {
            logging::error("start: timed out after 30 s");
            alive.store(false, Ordering::SeqCst);
            Err("the engine did not start in 30 s".to_owned())
        }
    }
}

pub(crate) fn shutdown() -> Result<(), String> {
    let Some(handle) = GLOBAL
        .lock()
        .map_err(|_| "bridge lock poisoned".to_owned())?
        .take()
    else {
        return Ok(());
    };
    let (reply, answer) = bounded(1);
    if handle
        .state_tx
        .send(StateRequest::Shutdown { reply })
        .is_ok()
    {
        let _ = answer.recv_timeout(Duration::from_secs(5));
    }
    handle.alive.store(false, Ordering::SeqCst);
    Ok(())
}

pub(crate) fn subscribe(
    sink: crate::frb_generated::StreamSink<SessionEvent>,
) -> Result<(), String> {
    let handle = global()?;
    // A sink is installed after `start`; a scan may have completed in between, so
    // ask the UI to re-read the library once it is listening.
    sink.add(SessionEvent {
        kind: crate::api::EventKind::LibraryChanged,
        tick: None,
        deck: 0,
        meta: None,
        error: false,
        text: String::new(),
        browser: None,
    })
    .map_err(|_| "could not prime the event stream".to_owned())?;
    *handle
        .sink
        .lock()
        .map_err(|_| "event sink lock poisoned".to_owned())? = Some(sink);
    Ok(())
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

pub(crate) fn set_wave_view(width: f64, frames_per_pixel: f64) -> Result<(), String> {
    let handle = global()?;
    handle
        .state_tx
        .send(StateRequest::SetWaveView {
            width,
            frames_per_pixel,
        })
        .map_err(|_| "the session thread is gone".to_owned())
}

pub(crate) fn waveform(deck: u8) -> Result<Option<WaveformData>, String> {
    ask(|reply| StateRequest::Waveform { deck, reply })
}

pub(crate) fn waveform_strip(
    deck: u8,
    center_frame: u64,
    frames_per_pixel: f64,
    columns: u32,
) -> Result<Option<WaveStrip>, String> {
    ask(|reply| StateRequest::WaveStrip {
        deck,
        center_frame,
        frames_per_pixel,
        columns,
        reply,
    })
}

pub(crate) fn wave_palette() -> Result<WavePaletteDto, String> {
    let handle = global()?;
    let palette = handle.wave_palette;
    Ok(WavePaletteDto {
        low: palette.low.argb(),
        mid: palette.mid.argb(),
        high: palette.high.argb(),
        beat: palette.beat.argb(),
        bar: palette.bar.argb(),
        loop_wash: palette.loop_wash.argb(),
        center: palette.center.argb(),
        playhead: palette.playhead.argb(),
        memory_cue: palette.memory_cue.argb(),
        hot_cues: palette.hot_cues.iter().map(|c| c.argb()).collect(),
    })
}

pub(crate) fn cover(deck: u8) -> Result<Option<CoverData>, String> {
    ask(|reply| StateRequest::Cover { deck, reply })
}

pub(crate) fn deck_meta(deck: u8) -> Result<Option<DeckMeta>, String> {
    ask(|reply| StateRequest::Meta { deck, reply })
}

pub(crate) fn mark_restart() {
    RESTART_REQUIRED.store(true, Ordering::SeqCst);
}

pub(crate) fn restart_required() -> bool {
    RESTART_REQUIRED.load(Ordering::SeqCst)
}

pub(crate) fn sample_rate() -> Result<u32, String> {
    Ok(global()?.sample_rate)
}

pub(crate) fn logs() -> Result<Vec<LogDto>, String> {
    ask(|reply| StateRequest::Logs { reply })
}

pub(crate) fn volume_mounted(root: String) -> Result<(), String> {
    volume_event(root, true)
}

pub(crate) fn volume_unmounted(root: String) -> Result<(), String> {
    volume_event(root, false)
}

fn volume_event(root: String, mounted: bool) -> Result<(), String> {
    let scan = global()?.dispatcher.scan();
    let mut scan = scan
        .lock()
        .map_err(|_| "the scan service lock is poisoned".to_owned())?;
    let root = PathBuf::from(root);
    let accepted = if mounted {
        scan.volume_mounted(root)
    } else {
        scan.volume_unmounted(root)
    };
    if accepted {
        Ok(())
    } else {
        Err("the scan service is not configured".to_owned())
    }
}

/// The profile source this session runs on, for the menu's config pages.
pub(crate) fn config_path() -> Result<String, String> {
    Ok(global()?.config_path.clone())
}

/// Re-reads the profile's text and asks the engine to rebuild its topology from it. File IO stays
/// in `app`; the engine only receives the text.
pub(crate) fn reload_mixer() -> Result<(), String> {
    let handle = global()?;
    let text = profile::read_profile_text(&handle.config_path)?;
    handle
        .dispatcher
        .command_tx
        .send(Command::MixerReload { text })
        .map_err(|_| "the engine is gone".to_owned())
}

/// Re-probes every configured destination. A device plugged in after startup only appears after
/// this (or a restart), which is what the menu's refresh key is for.
pub(crate) fn refresh_outputs() -> Result<(), String> {
    send_command(Command::Output {
        op: OutputOp::Refresh,
    })
}

/// Opens a different MIDI input on the session thread. The map stays the one the session already
/// resolved; picking a different map is a separate (file-picker) action.
pub(crate) fn reconnect_midi(port: Option<String>, map: Option<String>) -> Result<(), String> {
    let handle = global()?;
    let (reply, answer) = bounded(1);
    handle
        .state_tx
        .send(StateRequest::ReconnectMidi { port, map, reply })
        .map_err(|_| "the session thread is gone".to_owned())?;
    answer
        .recv_timeout(Duration::from_secs(5))
        .map_err(|_| "the session thread did not answer".to_owned())?
}

/// Closes the controller input and forgets the device in the running session. The profile is
/// edited by the caller; this only applies it to the live session.
pub(crate) fn disable_midi() -> Result<(), String> {
    let handle = global()?;
    let (reply, answer) = bounded(1);
    handle
        .state_tx
        .send(StateRequest::DisableMidi { reply })
        .map_err(|_| "the session thread is gone".to_owned())?;
    answer
        .recv_timeout(Duration::from_secs(5))
        .map_err(|_| "the session thread did not answer".to_owned())?
}

/// Re-reads `[preference.library]` from the profile and refreshes the browser/scan service.
pub(crate) fn sync_library(path: &str) -> Result<(), String> {
    let handle = global()?;
    let (reply, answer) = bounded(1);
    handle
        .state_tx
        .send(StateRequest::SyncLibrary {
            path: path.to_owned(),
            reply,
        })
        .map_err(|_| "the session thread is gone".to_owned())?;
    answer
        .recv_timeout(Duration::from_secs(10))
        .map_err(|_| "the session thread did not answer".to_owned())?
}

/// Every source the library cache knows about, for the Preferences page.
pub(crate) fn library_sources() -> Result<Vec<LibrarySourceDto>, String> {
    let handle = global()?;
    let db = handle
        .library
        .clone()
        .ok_or_else(|| "the library is not available".to_owned())?;
    let sources = db.sources().map_err(|err| err.to_string())?;
    Ok(sources
        .into_iter()
        .map(|source| LibrarySourceDto {
            id: source.id as i32,
            name: source.display_name(),
            path: source.root.to_string_lossy().into_owned(),
            origin: format!("{:?}", source.origin),
        })
        .collect())
}

/// Applies a preference the session thread owns (analysis backends, display behaviour). The
/// profile was written by the caller.
pub(crate) fn apply_preference(key: &str, value: &str) -> Result<(), String> {
    let handle = global()?;
    let (reply, answer) = bounded(1);
    handle
        .state_tx
        .send(StateRequest::ApplyPreference {
            key: key.to_owned(),
            value: value.to_owned(),
            reply,
        })
        .map_err(|_| "the session thread is gone".to_owned())?;
    answer
        .recv_timeout(Duration::from_secs(5))
        .map_err(|_| "the session thread did not answer".to_owned())?
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

pub(crate) fn transport(deck: u8, action: TransportAction) -> Result<(), String> {
    let command = match action {
        TransportAction::Toggle => Command::TogglePlay { deck_id: deck },
        TransportAction::Play => Command::Play { deck_id: deck },
        TransportAction::Pause => Command::Pause { deck_id: deck },
    };
    send_command(command)
}

pub(crate) fn cue(deck: u8, action: CueAction) -> Result<(), String> {
    let op = match action {
        CueAction::Button => CueOp::Button,
        CueAction::Play => CueOp::Play,
        CueAction::Back => CueOp::Back,
        CueAction::Set => CueOp::Set,
        CueAction::Smart => CueOp::Smart,
    };
    send_command(Command::Cue { deck_id: deck, op })
}

pub(crate) fn hot_cue(deck: u8, slot: u8, action: HotCueAction) -> Result<(), String> {
    let op = match action {
        HotCueAction::Set => HotCueOp::Set(slot),
        HotCueAction::Trigger => HotCueOp::Trigger(slot),
        HotCueAction::Clear => HotCueOp::Clear(slot),
    };
    send_command(Command::HotCue { deck_id: deck, op })
}

pub(crate) fn vinyl(deck: u8, action: VinylAction) -> Result<(), String> {
    let op = match action {
        VinylAction::Touch => VinylOp::Touch,
        VinylAction::Release => VinylOp::Release,
        VinylAction::Slip => VinylOp::Slip,
    };
    send_command(Command::Vinyl { deck_id: deck, op })
}

pub(crate) fn vinyl_turn(deck: u8, ticks: i32, frames_per_tick: f32) -> Result<(), String> {
    send_command(Command::Vinyl {
        deck_id: deck,
        op: VinylOp::Turn {
            ticks,
            frames_per_tick,
            bend: None,
        },
    })
}

pub(crate) fn seek(deck: u8, frame: u64) -> Result<(), String> {
    send_command(Command::Jump {
        deck_id: deck,
        target_frame: frame,
    })
}

pub(crate) fn beat_jump(deck: u8, beats: i32) -> Result<(), String> {
    send_command(Command::BeatJump {
        deck_id: deck,
        beats: i64::from(beats),
    })
}

pub(crate) fn jump_step(deck: u8, direction: i32) -> Result<(), String> {
    send_command(Command::BeatJumpStep {
        deck_id: deck,
        direction: direction.signum() as i8,
    })
}

pub(crate) fn scale_jump(deck: u8, halve: bool) -> Result<(), String> {
    send_command(Command::ScaleJumpBeats {
        deck_id: deck,
        halve,
    })
}

pub(crate) fn set_tempo(deck: u8, tempo: f32) -> Result<(), String> {
    send_command(Command::SetTempo {
        deck_id: deck,
        tempo,
    })
}

pub(crate) fn set_tempo_fader(deck: u8, position: f32) -> Result<(), String> {
    send_command(Command::SetTempoFader {
        deck_id: deck,
        position,
    })
}

pub(crate) fn set_tempo_range(deck: u8, range: f32) -> Result<(), String> {
    send_command(Command::SetTempoRange {
        deck_id: deck,
        range,
    })
}

pub(crate) fn sync(deck: u8, action: SyncAction) -> Result<(), String> {
    let op = match action {
        SyncAction::Tempo => SyncOp::Tempo,
        SyncAction::Phase => SyncOp::Phase {
            mode: protocol::PhaseMode::Instant,
            t_seconds: None,
        },
        SyncAction::TempoLock => SyncOp::TempoLock,
        SyncAction::PhaseLock => SyncOp::PhaseLock {
            mode: protocol::PhaseMode::Pid,
            t_seconds: None,
        },
        SyncAction::SetLeader => SyncOp::SetLeader,
        SyncAction::Unlock => SyncOp::Unlock,
        SyncAction::Toggle => {
            return Err("sync toggle needs current state; use TempoLock or Unlock".to_owned());
        }
    };
    send_command(Command::Sync { deck_id: deck, op })
}

pub(crate) fn nudge(deck: u8, action: NudgeAction) -> Result<(), String> {
    let op = match action {
        NudgeAction::Left => NudgeOp::Start {
            delta: -0.06,
            seconds: None,
        },
        NudgeAction::Right => NudgeOp::Start {
            delta: 0.06,
            seconds: None,
        },
        NudgeAction::Stop => NudgeOp::Stop,
    };
    send_command(Command::Nudge { deck_id: deck, op })
}

pub(crate) fn bend(deck: u8, delta: f32) -> Result<(), String> {
    send_command(Command::Nudge {
        deck_id: deck,
        op: NudgeOp::Bend {
            delta,
            seconds: 0.2,
        },
    })
}

pub(crate) fn set_keylock(deck: u8, on: bool) -> Result<(), String> {
    send_command(Command::SetKeylock {
        deck_id: deck,
        mode: if on {
            KeylockMode::On
        } else {
            KeylockMode::Off
        },
    })
}

pub(crate) fn set_key(deck: u8, semitones: i32) -> Result<(), String> {
    send_command(Command::SetKey {
        deck_id: deck,
        semitones,
    })
}

pub(crate) fn loop_action(deck: u8, action: LoopAction) -> Result<(), String> {
    let op = match action {
        LoopAction::In => LoopOp::In,
        LoopAction::Out => LoopOp::Out,
        LoopAction::Cancel => LoopOp::Cancel,
        LoopAction::Exit => LoopOp::Exit,
        LoopAction::Toggle => LoopOp::Toggle,
        LoopAction::SlipIn => LoopOp::SlipIn,
        LoopAction::SlipOut => LoopOp::SlipOut,
        LoopAction::Halve => LoopOp::Edit(protocol::LoopEditOp::Halve),
        LoopAction::Double => LoopOp::Edit(protocol::LoopEditOp::Double),
    };
    send_command(Command::Loop { deck_id: deck, op })
}

pub(crate) fn loop_beats(deck: u8, num: u32, den: u32) -> Result<(), String> {
    let beats =
        BeatLen::fraction(num, den).ok_or_else(|| format!("invalid loop length {num}/{den}"))?;
    send_command(Command::Loop {
        deck_id: deck,
        op: LoopOp::Beats(beats),
    })
}

pub(crate) fn set_level(target: LevelTarget, value: f32) -> Result<(), String> {
    let target = match target.kind {
        LevelKind::Flow => FaderTarget::Flow(target.deck),
        LevelKind::Stem => FaderTarget::Stem {
            deck: target.deck,
            stem: Stem::from_index(target.stem as usize)
                .ok_or_else(|| format!("unknown stem {}", target.stem))?,
        },
        LevelKind::Deck => FaderTarget::Deck(target.deck),
        LevelKind::Gain => FaderTarget::Gain(target.deck),
        LevelKind::CueSend => FaderTarget::CueSend(target.deck),
        LevelKind::Crossfader => FaderTarget::default_crossfader(),
        LevelKind::Master => FaderTarget::Master,
        LevelKind::Cue => FaderTarget::Cue,
    };
    send_command(Command::SetFader { target, value })
}

pub(crate) fn set_crossfader(value: f32) -> Result<(), String> {
    send_command(Command::SetFader {
        target: FaderTarget::default_crossfader(),
        value,
    })
}

pub(crate) fn toggle_cue_send(deck: u8) -> Result<(), String> {
    send_command(Command::ToggleCueSend { deck_id: deck })
}

pub(crate) fn set_eq(deck: u8, band: EqBand, value: f32) -> Result<(), String> {
    let (role, param) = match band {
        EqBand::High => ("eq", "high"),
        EqBand::Mid => ("eq", "mid"),
        EqBand::Low => ("eq", "low"),
        EqBand::Filter => ("filter", "value"),
    };
    let handle = global()?;
    let index = handle
        .dispatcher
        .slots()
        .resolve(&protocol::deck_label(deck), role)?;
    send_command(Command::SetFxParam {
        slot: FxSlotRef {
            chain: FxChainId::Deck(deck),
            index,
        },
        name: param.to_owned(),
        value,
    })
}

pub(crate) fn fx(deck: u8, slot: u32, op: FxOp, param: u32, value: f32) -> Result<(), String> {
    let slot = FxSlotRef {
        chain: FxChainId::Deck(deck),
        index: slot as usize,
    };
    let command = match op {
        FxOp::SetParam => Command::SetFxParamIndex {
            slot,
            index: param as usize,
            value,
        },
        FxOp::Enable => Command::SetFxEnabled {
            slot,
            enabled: true,
        },
        FxOp::Disable => Command::SetFxEnabled {
            slot,
            enabled: false,
        },
        FxOp::Trigger => Command::FxTrigger { slot },
        FxOp::MomentaryDown => Command::PadPress { slot },
        FxOp::MomentaryUp => Command::PadRelease { slot },
    };
    send_command(command)
}

pub(crate) fn fx_add(deck: u8, kind: String) -> Result<(), String> {
    send_command(Command::AddFx {
        chain: FxChainId::Deck(deck),
        kind,
    })
}

pub(crate) fn fx_remove(deck: u8, slot: u32) -> Result<(), String> {
    send_command(Command::RemoveFx {
        chain: FxChainId::Deck(deck),
        index: slot as usize,
    })
}

pub(crate) fn fx_select(deck: u8, slot: u32, kind: String) -> Result<(), String> {
    send_command(Command::SetFxKind {
        slot: FxSlotRef {
            chain: FxChainId::Deck(deck),
            index: slot as usize,
        },
        kind,
    })
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------

pub(crate) fn load_path(deck: u8, path: String, bpm: Option<f32>) -> Result<(), String> {
    let handle = global()?;
    let tags = library::library::tags::read_tags(Path::new(&path)).ok();
    let sample_rate = handle.sample_rate;
    let total_frames = tags
        .as_ref()
        .map(|tags| {
            (u128::from(tags.duration_frames) * u128::from(sample_rate)
                / u128::from(tags.sample_rate.max(1))) as u64
        })
        .unwrap_or(0);
    let meta = DeckMeta {
        deck,
        title: tags
            .as_ref()
            .and_then(|tags| tags.title.clone())
            .or_else(|| {
                Path::new(&path)
                    .file_stem()
                    .map(|name| name.to_string_lossy().into_owned())
            })
            .unwrap_or_default(),
        artist: tags
            .as_ref()
            .and_then(|tags| tags.artist.clone())
            .unwrap_or_default(),
        album: tags
            .as_ref()
            .and_then(|tags| tags.album.clone())
            .unwrap_or_default(),
        key: tags
            .as_ref()
            .and_then(|tags| tags.key)
            .map(|key| key.camelot())
            .unwrap_or_default(),
        bpm: tags
            .as_ref()
            .and_then(|tags| tags.bpm)
            .or(bpm)
            .unwrap_or(0.0),
        sample_rate,
        total_frames,
        first_beat: 0,
        location_id: -1,
    };
    let _ = handle.state_tx.send(StateRequest::SetMeta { deck, meta });
    command::spawn_load(deck, path, bpm, &handle.dispatcher);
    Ok(())
}

pub(crate) fn load_track(deck: u8, location_id: i32) -> Result<(), String> {
    let handle = global()?;
    let location_id = i64::from(location_id);
    let db = handle
        .library
        .clone()
        .ok_or_else(|| "the library is not available".to_owned())?;
    let track = db
        .track_load(location_id)
        .map_err(|err| err.to_string())?
        .ok_or_else(|| format!("no location {location_id}"))?;
    let path = track.path.display().to_string();
    let sample_rate = handle.sample_rate;
    let decoder_start_ms = handle
        .decoder_start_ms
        .unwrap_or_else(|| media::decoder_start_ms(&path).unwrap_or(0.0));
    let grid_offset_ms = *GRID_OFFSET_MS
        .lock()
        .map_err(|_| "the grid offset lock is poisoned".to_owned())?;
    let (analysis, cues) = (
        db.imported_analysis(location_id, sample_rate, decoder_start_ms, grid_offset_ms)
            .ok()
            .flatten()
            .or_else(|| db.load_analysis(track.track_id).ok().flatten()),
        db.loaded_cues(location_id, sample_rate, decoder_start_ms, grid_offset_ms)
            .ok(),
    );
    let total_frames = (u128::from(track.duration_frames) * u128::from(sample_rate)
        / u128::from(track.sample_rate.max(1))) as u64;
    let first_beat = 0; // published by the grid/analyse path; 0 is a valid fallback
    let meta = DeckMeta {
        deck,
        title: track.title.clone(),
        artist: track.artist.clone().unwrap_or_default(),
        album: track.album.clone().unwrap_or_default(),
        key: track
            .key
            .map(|key| {
                if KEY_FORMAT.load(Ordering::Relaxed) == 1 {
                    key.traditional()
                } else {
                    key.camelot()
                }
            })
            .unwrap_or_default(),
        bpm: track.bpm.unwrap_or(0.0),
        sample_rate,
        total_frames,
        first_beat,
        location_id: location_id as i32,
    };
    let _ = handle.state_tx.send(StateRequest::SetMeta { deck, meta });
    // The sketch has no analyse button; a GUI load with no imported or cached
    // grid runs the configured analyser in the background so BPM/key arrive.
    let analysis_backends = *handle
        .backends
        .lock()
        .map_err(|_| "the analysis backend lock is poisoned".to_owned())?;
    let auto = (analysis.is_none() && AUTO_ANALYSE.load(Ordering::Relaxed)).then(|| AutoAnalysis {
        backends: analysis_backends,
        cache: Some((Arc::clone(&db), track.track_id)),
    });
    command::spawn_load_with(
        deck,
        path,
        track.bpm,
        analysis,
        cues,
        auto,
        &handle.dispatcher,
    );
    Ok(())
}

pub(crate) fn send_browser_action(action: BrowserAction) -> Result<(), String> {
    global()?.browser_tx.send(action).map_err(|err| err.to_string())
}

pub(crate) fn analyse_track(location_id: i32) -> Result<(), String> {
    let handle = global()?;
    let location_id = i64::from(location_id);
    let db = handle
        .library
        .clone()
        .ok_or_else(|| "the library is not available".to_owned())?;
    let track = db
        .track_load(location_id)
        .map_err(|err| err.to_string())?
        .ok_or_else(|| format!("no location {location_id}"))?;
    let backends = *handle
        .backends
        .lock()
        .map_err(|_| "the analysis backend lock is poisoned".to_owned())?;
    command::spawn_analyse_track(track, db, backends, &handle.dispatcher);
    Ok(())
}

/// Analyses every track in one playlist on a single worker. The session emits `AnalysisListFinished`
/// when the cache is complete.
pub(crate) fn analyse_list(playlist_id: i32) -> Result<(), String> {
    let handle = global()?;
    let db = handle
        .library
        .clone()
        .ok_or_else(|| "the library is not available".to_owned())?;
    let rows = db
        .tracks_in_playlist(i64::from(playlist_id))
        .map_err(|err| err.to_string())?;
    let mut tracks = Vec::with_capacity(rows.len());
    for row in rows {
        if let Some(track) = db
            .track_load(row.location_id)
            .map_err(|err| err.to_string())?
        {
            tracks.push(track);
        }
    }
    let backends = *handle
        .backends
        .lock()
        .map_err(|_| "the analysis backend lock is poisoned".to_owned())?;
    command::spawn_analyse_list(tracks, db, backends, &handle.dispatcher);
    Ok(())
}

// ---------------------------------------------------------------------------
// Library
// ---------------------------------------------------------------------------

fn track_dto(track: &library::TrackRow) -> TrackDto {
    let seconds = if track.sample_rate == 0 {
        0
    } else {
        (track.duration_frames / u64::from(track.sample_rate.max(1))) as u32
    };
    TrackDto {
        track_id: track.track_id as i32,
        location_id: track.location_id as i32,
        title: track.title.clone(),
        artist: track.artist.clone().unwrap_or_default(),
        album: track.album.clone().unwrap_or_default(),
        bpm: track.bpm.unwrap_or(0.0),
        key: track.key.map(|key| key.camelot()).unwrap_or_default(),
        seconds,
        sample_rate: track.sample_rate,
    }
}

pub(crate) fn library_roots() -> Result<Vec<LibraryRoot>, String> {
    let handle = global()?;
    let db = handle
        .library
        .clone()
        .ok_or_else(|| "the library is not available".to_owned())?;
    let sources = db.sources().map_err(|err| err.to_string())?;
    Ok(sources
        .into_iter()
        .filter(|source| source.root.is_dir())
        .map(|source| LibraryRoot {
            id: source.id as i32,
            name: source.display_name(),
            kind: format!("{:?}", source.kind),
        })
        .collect())
}

pub(crate) fn library_lists(source_id: i32) -> Result<Vec<LibraryList>, String> {
    let handle = global()?;
    let source_id = i64::from(source_id);
    let db = handle
        .library
        .clone()
        .ok_or_else(|| "the library is not available".to_owned())?;
    let rows = app::browser::playlist_tree(&db, source_id).map_err(|err| err.to_string())?;
    Ok(rows
        .into_iter()
        .map(|row| LibraryList {
            id: row.playlist.id as i32,
            source_id: source_id as i32,
            parent_id: row.parent_id.map(|id| id as i32),
            name: row.playlist.name,
            kind: row.playlist.kind,
            has_children: row.has_children,
        })
        .collect())
}

pub(crate) fn library_tracks(playlist_id: i32) -> Result<Vec<TrackDto>, String> {
    let handle = global()?;
    let playlist_id = i64::from(playlist_id);
    let db = handle
        .library
        .clone()
        .ok_or_else(|| "the library is not available".to_owned())?;
    db.tracks_in_playlist(playlist_id)
        .map(|tracks| tracks.iter().map(track_dto).collect())
        .map_err(|err| err.to_string())
}

pub(crate) fn library_search(query: String, limit: u32) -> Result<Vec<TrackDto>, String> {
    let handle = global()?;
    let db = handle
        .library
        .clone()
        .ok_or_else(|| "the library is not available".to_owned())?;
    db.search_tracks(&query, limit.min(500) as usize)
        .map(|tracks| tracks.iter().map(track_dto).collect())
        .map_err(|err| err.to_string())
}

// ---------------------------------------------------------------------------
// The session thread
// ---------------------------------------------------------------------------

/// Applies a preference that the session, not the audio engine, owns. The profile has already been
/// written by the caller; this keeps the live session consistent with it.
fn apply_preference_to_app(app: &mut AppState, key: &str, value: &str) -> Result<(), String> {
    match key {
        "beats_backend" | "key_backend" => {
            let backend = Backend::parse(value)
                .ok_or_else(|| format!("{key}: `{value}` is not stratum | timestretch"))?;
            if key == "beats_backend" {
                app.backends.beats = backend;
            } else {
                app.backends.key = backend;
            }
            if let Some(shared) = &app.shared_backends {
                if let Ok(mut guard) = shared.lock() {
                    *guard = app.backends;
                }
            }
        }
        "auto_analyse" => {
            app.auto_analyse = parse_on_off(key, value)?;
            AUTO_ANALYSE.store(app.auto_analyse, Ordering::Relaxed);
        }
        "grid_offset_ms" => {
            app.grid_offset_ms = value
                .trim()
                .parse()
                .map_err(|_| format!("grid_offset_ms: `{value}` is not a number"))?;
            if let Ok(mut offset) = GRID_OFFSET_MS.lock() {
                *offset = app.grid_offset_ms;
            }
        }
        "key_format" => {
            app.key_format = match value.trim() {
                "camelot" => KeyFormat::Camelot,
                "classic" | "traditional" => KeyFormat::Traditional,
                other => {
                    return Err(format!("key_format: `{other}` is not camelot | classic"));
                }
            };
            KEY_FORMAT.store(
                if app.key_format == KeyFormat::Camelot {
                    0
                } else {
                    1
                },
                Ordering::Relaxed,
            );
            app.reload_browser();
            app.library_dirty = true;
        }
        "follow" => app.follow_commands = parse_on_off(key, value)?,
        other => return Err(format!("unknown preference `{other}`")),
    }
    Ok(())
}

fn parse_on_off(key: &str, value: &str) -> Result<bool, String> {
    match value.trim() {
        "on" | "true" | "1" => Ok(true),
        "off" | "false" | "0" => Ok(false),
        other => Err(format!("{key}: `{other}` is not on | off")),
    }
}

fn run(
    config_path: Option<String>,
    state_rx: Receiver<StateRequest>,
    sink: Arc<Mutex<Option<crate::frb_generated::StreamSink<SessionEvent>>>>,
    alive: Arc<AtomicBool>,
    boot_tx: Sender<Result<BootData, String>>,
) {
    let booted = boot(config_path);
    let (pipeline, dispatcher, library, mut app, boot) = match booted {
        Ok(booted) => booted,
        Err(err) => {
            logging::error(format!("boot: failed: {err}"));
            alive.store(false, Ordering::SeqCst);
            let _ = boot_tx.send(Err(err));
            return;
        }
    };
    let _ = boot_tx.send(Ok(boot.clone()));
    pump(
        pipeline, dispatcher, library, &mut app, &state_rx, &sink, &alive,
    );
}

type Booted = (
    AudioPipeline,
    Arc<Dispatcher>,
    Option<Arc<LibraryDb>>,
    AppState,
    BootData,
);

fn boot(config_path: Option<String>) -> Result<Booted, String> {
    logging::info(format!("boot: config {config_path:?}"));
    let mut config = profile::load_or_create(config_path.as_deref()).map_err(|err| {
        logging::error(format!("boot: config: {err}"));
        err
    })?;
    // The Flutter shell offers two- and four-deck rigs; start four so a deck
    // picker change never points at a channel the engine does not own.
    let decks = 4;
    config.mixer.set_channel_count(decks);
    let config_path = config.path.to_string_lossy().into_owned();
    logging::info(format!("boot: config loaded from {config_path}"));
    let live = config.live.clone();
    let midi_controllers = config.controllers.clone();
    let midi_legacy_map = config.controller.map.clone();
    let midi_config_path = config.path.clone();
    let midi_mixer = config.mixer.clone();
    let backends = Arc::new(Mutex::new(Backends {
        beats: config.analysis.beats,
        key: config.analysis.key,
    }));
    let initial_backends = *backends
        .lock()
        .map_err(|_| "the analysis backend lock is poisoned".to_owned())?;
    let auto_analyse = config.analysis.auto_analyse;

    logging::info(format!("boot: audio @ {} Hz", live.audio.sample_rate));
    let tuning = AudioTuning {
        ring_frames: live.audio.ring_frames,
        prefill_frames: live.audio.prefill_frames,
        device_buffer_frames: live.audio.device_buffer_frames,
        keylock: live.keylock,
    };
    let pipeline =
        match AudioPipeline::start_with(config.mixer.clone(), live.audio.sample_rate, tuning) {
            Ok(pipeline) => pipeline,
            Err(err) => {
                // A phone with no usable output must still get menus, the browser and MIDI. Retry
                // with no destinations: the mixer and command loop stay alive, just silent.
                logging::error(format!(
                    "boot: audio: {err}; retrying without outputs (the session will be silent)"
                ));
                let mut silent = config.mixer.clone();
                silent.outputs.clear();
                AudioPipeline::start_with(silent, live.audio.sample_rate, tuning).map_err(
                    |err| {
                        logging::error(format!("boot: audio retry: {err}"));
                        err.to_string()
                    },
                )?
            }
        };
    let decks = pipeline.channel_count().unwrap_or(decks).max(1);
    logging::info(format!("boot: audio ready ({decks} decks)"));

    // The GUI starts from a bundle, so a relative `.cache` (the TUI's default) would land
    // inside the app directory. Use the platform cache root unless the user overrides it.
    let library = match gui_cache_dir() {
        Some(dir) => match LibraryDb::open(dir.join("library.sqlite3")) {
            Ok(db) => {
                logging::info(format!("boot: library {}", dir.display()));
                Some(Arc::new(db))
            }
            Err(err) => {
                logging::error(format!("boot: library {}: {err}", dir.display()));
                None
            }
        },
        None => {
            logging::error("boot: library unavailable: no cache directory");
            None
        }
    };
    let (notice_tx, notice_rx) = unbounded();
    let (event_tx, event_rx) = unbounded();
    let mut dispatcher = Dispatcher::new(pipeline.command_tx(), notice_tx).tap_events(event_tx);
    dispatcher.with_topology(Some(config_path.clone()));
    dispatcher.with_live(live.clone(), Some(config_path.clone()));
    dispatcher.with_library(library.clone());

    let mut app = AppState::new(
        decks,
        initial_backends,
        notice_rx,
        event_rx,
        dispatcher.slots(),
        dispatcher.scan(),
    );
    app.library = library.clone();
    app.auto_analyse = auto_analyse;
    app.shared_backends = Some(Arc::clone(&backends));
    app.sample_rate = live.audio.sample_rate;
    app.ring_frames = live.audio.ring_frames;
    app.profile_path = Some(config_path.clone());
    app.live_path = Some(config_path.clone());
    app.mixer_path = Some(config_path.clone());

    let preference_path = if profile::is_builtin(&config_path) {
        preference::DEFAULT_PATH.to_owned()
    } else {
        config_path.clone()
    };
    let (pref, _notes) = match preference::load(&preference_path) {
        Ok(loaded) => loaded,
        Err(err) => {
            logging::error(format!("boot: preference {preference_path}: {err}"));
            Default::default()
        }
    };
    let wave_palette = WavePalette::from_preference(&pref.waveform.colors);
    app.key_format = pref.display.key_format;
    app.waveform_low_hz = pref.waveform.low_hz;
    app.waveform_high_hz = pref.waveform.high_hz;
    app.decoder_start_ms = pref.library.decoder_start_ms;
    app.grid_offset_ms = pref.library.grid_offset_ms;
    if let Ok(mut offset) = GRID_OFFSET_MS.lock() {
        *offset = pref.library.grid_offset_ms;
    }
    KEY_FORMAT.store(
        if pref.display.key_format == KeyFormat::Camelot {
            0
        } else {
            1
        },
        Ordering::Relaxed,
    );
    AUTO_ANALYSE.store(auto_analyse, Ordering::Relaxed);
    app.sync_library(&pref.library);
    app.reload_browser();

    dispatcher.prime(decks, pipeline.response_rx());
    seed_fx(&dispatcher, decks);
    attach_controllers(
        &MidiBoot {
            controllers: &midi_controllers,
            legacy_map: midi_legacy_map,
            config_path: &midi_config_path,
            mixer: &midi_mixer,
        },
        &dispatcher,
        &mut app,
    );
    logging::info("boot: ready");

    let dispatcher = Arc::new(dispatcher);
    let boot = BootData {
        dispatcher: Arc::clone(&dispatcher),
        browser_tx: app.browser_tx.clone(),
        library: library.clone(),
        sample_rate: live.audio.sample_rate,
        wave_palette,
        backends,
        decoder_start_ms: pref.library.decoder_start_ms,
        config_path: config_path.clone(),
    };
    Ok((pipeline, dispatcher, library, app, boot))
}

fn pump(
    pipeline: AudioPipeline,
    dispatcher: Arc<Dispatcher>,
    _library: Option<Arc<LibraryDb>>,
    app: &mut AppState,
    state_rx: &Receiver<StateRequest>,
    sink: &Arc<Mutex<Option<crate::frb_generated::StreamSink<SessionEvent>>>>,
    alive: &AtomicBool,
) {
    let decks = app.decks;
    let sample_rate = app.sample_rate;
    let mut meta: Vec<Option<DeckMeta>> = vec![None; decks];
    let mut waveform_sent = vec![false; decks];
    let mut cover_sent = vec![false; decks];
    let mut last_log = 0usize;
    let mut wave_width = 0.0f64;
    let mut wave_fpp = 0.0f64;
    let mut pending_states = false;
    let mut ticks = 0u64;
    let mut next_tick = Instant::now();
    let mut stopped = false;

    while alive.load(Ordering::SeqCst) && !stopped {
        while let Ok(request) = state_rx.try_recv() {
            match request {
                StateRequest::Waveform { deck, reply } => {
                    let data = waveform_for(app, deck);
                    let _ = reply.send(data);
                }
                StateRequest::Cover { deck, reply } => {
                    let data = cover_for(app, deck);
                    let _ = reply.send(data);
                }
                StateRequest::Meta { deck, reply } => {
                    let _ = reply.send(meta.get(deck as usize).cloned().flatten());
                }
                StateRequest::SetMeta { deck, meta: next } => {
                    if let Some(slot) = meta.get_mut(deck as usize) {
                        *slot = Some(next.clone());
                    }
                    waveform_sent[deck as usize] = false;
                    cover_sent[deck as usize] = false;
                    send_event(
                        sink,
                        SessionEvent {
                            kind: crate::api::EventKind::Loaded,
                            tick: None,
                            deck,
                            meta: Some(next),
                            error: false,
                            text: String::new(),
                            browser: None,
                        },
                    );
                }
                StateRequest::SetWaveView {
                    width,
                    frames_per_pixel,
                } => {
                    wave_width = width;
                    wave_fpp = frames_per_pixel;
                }
                StateRequest::WaveStrip {
                    deck,
                    center_frame,
                    frames_per_pixel,
                    columns,
                    reply,
                } => {
                    let _ = reply.send(build_strip(
                        app,
                        deck,
                        center_frame,
                        frames_per_pixel,
                        columns,
                    ));
                }
                StateRequest::Logs { reply } => {
                    let logs = app
                        .log
                        .iter()
                        .map(|line| LogDto {
                            error: matches!(line.level, app::response::Level::Error),
                            text: line.text.clone(),
                        })
                        .collect();
                    let _ = reply.send(logs);
                }
                StateRequest::ReconnectMidi { port, map, reply } => {
                    if let Some(port) = port {
                        app.midi_port = Some(port);
                    }
                    if let Some(map) = map {
                        app.midi_map = Some(map);
                    }
                    let retry = app.connect_midi(
                        dispatcher.command_tx.clone(),
                        &dispatcher.notices,
                        &dispatcher,
                    );
                    let _ = reply.send(if retry.is_some() {
                        Err("the controller did not reconnect".to_owned())
                    } else {
                        Ok(())
                    });
                }
                StateRequest::DisableMidi { reply } => {
                    app.midi_port = None;
                    app.midi.clear();
                    for spec in &mut app.controller_sessions {
                        spec.port = None;
                    }
                    dispatcher.clear_midi();
                    let _ = reply.send(Ok(()));
                }
                StateRequest::ApplyPreference { key, value, reply } => {
                    let _ = reply.send(apply_preference_to_app(app, &key, &value));
                }
                StateRequest::SyncLibrary { path, reply } => {
                    let result = match preference::load(&path) {
                        Ok((pref, _notes)) => {
                            app.sync_library(&pref.library);
                            app.library_dirty = true;
                            Ok(())
                        }
                        Err(err) => Err(err),
                    };
                    let _ = reply.send(result);
                }
                StateRequest::Shutdown { reply } => {
                    let _ = reply.send(());
                    stopped = true;
                }
            }
        }
        if stopped {
            break;
        }

        while let Ok(response) = pipeline.response_rx().try_recv() {
            app.on_response(&response, &pipeline);
        }
        app.drain();
        let library_changed = std::mem::take(&mut app.library_dirty);
        let analysis_finished = std::mem::take(&mut app.analysis_list_finished);
        if library_changed || analysis_finished {
            send_event(
                sink,
                SessionEvent {
                    kind: if analysis_finished {
                        crate::api::EventKind::AnalysisListFinished
                    } else {
                        crate::api::EventKind::LibraryChanged
                    },
                    tick: None,
                    deck: 0,
                    meta: None,
                    error: false,
                    text: String::new(),
                    browser: None,
                },
            );
        }
        for action in app.drain_browser_actions() {
            let (browser, deck) = match action {
                BrowserAction::Up => (BrowserCommand::Up, None),
                BrowserAction::Down => (BrowserCommand::Down, None),
                BrowserAction::Open => (BrowserCommand::Open, None),
                BrowserAction::Exit => (BrowserCommand::Exit, None),
                BrowserAction::Load { deck } => (BrowserCommand::Load, deck),
                BrowserAction::Refresh => (BrowserCommand::Refresh, None),
            };
            send_event(sink, SessionEvent {
                kind: crate::api::EventKind::Browser,
                tick: None,
                deck: deck.unwrap_or(u8::MAX),
                meta: None,
                error: false,
                text: String::new(),
                browser: Some(browser),
            });
        }

        for deck in 0..decks {
            if !waveform_sent[deck] && app.waveforms.get(deck).is_some_and(Option::is_some) {
                waveform_sent[deck] = true;
                send_event(
                    sink,
                    SessionEvent {
                        kind: crate::api::EventKind::WaveformReady,
                        tick: None,
                        deck: deck as u8,
                        meta: None,
                        error: false,
                        text: String::new(),
                        browser: None,
                    },
                );
            }
            if !cover_sent[deck] && app.covers.get(deck).is_some_and(Option::is_some) {
                cover_sent[deck] = true;
                send_event(
                    sink,
                    SessionEvent {
                        kind: crate::api::EventKind::CoverReady,
                        tick: None,
                        deck: deck as u8,
                        meta: None,
                        error: false,
                        text: String::new(),
                        browser: None,
                    },
                );
            }
        }

        if app.log.len() != last_log {
            last_log = app.log.len();
            if let Some(line) = app.log.back() {
                send_event(
                    sink,
                    SessionEvent {
                        kind: crate::api::EventKind::Log,
                        tick: None,
                        deck: 0,
                        meta: None,
                        error: matches!(line.level, app::response::Level::Error),
                        text: line.text.clone(),
                        browser: None,
                    },
                );
            }
        }

        let now = Instant::now();
        if now >= next_tick {
            next_tick += TICK;
            if next_tick <= now {
                next_tick = now + TICK;
            }
            ticks = ticks.wrapping_add(1);

            if ticks.is_multiple_of(SLOW_EVERY) {
                if let Some(meters) = pipeline.meters() {
                    app.meters = Some(meters);
                }
                for deck in 0..decks {
                    let _ = dispatcher.command_tx.send(Command::GetFxState {
                        chain: FxChainId::Deck(deck as u8),
                    });
                }
            }

            if !pending_states && dispatcher.command_tx.send(Command::GetAllStates).is_ok() {
                pending_states = true;
                app.pending_states = 1;
            }
            if app.pending_states == 0 {
                pending_states = false;
            }

            let tick = build_tick(
                app,
                sample_rate,
                wave_width,
                wave_fpp,
                ticks.is_multiple_of(SLOW_EVERY),
            );
            send_event(
                sink,
                SessionEvent {
                    kind: crate::api::EventKind::Tick,
                    tick: Some(tick),
                    deck: 0,
                    meta: None,
                    error: false,
                    text: String::new(),
                    browser: None,
                },
            );
        }

        thread::sleep(Duration::from_millis(2));
    }

    send_event(
        sink,
        SessionEvent {
            kind: crate::api::EventKind::Stopped,
            tick: None,
            deck: 0,
            meta: None,
            error: false,
            text: String::new(),
            browser: None,
        },
    );
    alive.store(false, Ordering::SeqCst);
    drop(dispatcher);
    drop(pipeline);
}

/// The config's `[[controller]]` entries connect automatically, exactly as the
/// REPL path does. A missing device is a warning, never a failed launch.
struct MidiBoot<'a> {
    controllers: &'a [profile::Controller],
    legacy_map: Option<String>,
    config_path: &'a Path,
    mixer: &'a audio::MixerConfig,
}

fn attach_controllers(
    boot: &MidiBoot<'_>,
    dispatcher: &Dispatcher,
    app: &mut AppState,
) {
    let map_path = boot
        .legacy_map
        .clone()
        .unwrap_or_else(|| profile::map_path_for(boot.config_path));
    let routes = profile::deck_routes(boot.mixer, None);
    let sessions: Vec<profile::ControllerSession> = boot
        .controllers
        .iter()
        .map(|entry| {
            let map = entry.map.clone().unwrap_or_else(|| map_path.clone());
            let port = entry.device.clone();
            let routes = profile::deck_routes(boot.mixer, Some(&entry.id));
            profile::ControllerSession {
                id: entry.id.clone(),
                port,
                map,
                routes,
            }
        })
        .collect();
    app.deck_routes = routes;
    app.midi_port = sessions.first().and_then(|entry| entry.port.clone());
    app.midi_map = sessions.first().map(|entry| entry.map.clone());
    app.controller_sessions = sessions;
    app.connect_midi(dispatcher.command_tx.clone(), &dispatcher.notices, dispatcher);
}

fn gui_cache_dir() -> Option<std::path::PathBuf> {
    if let Some(dir) = app::paths::cache() {
        return Some(dir);
    }
    if let Some(dir) = std::env::var_os("PIPEFADER_CACHE").filter(|dir| !dir.is_empty()) {
        return Some(std::path::PathBuf::from(dir));
    }
    let base = std::env::var_os("XDG_CACHE_HOME")
        .filter(|dir| !dir.is_empty())
        .map(std::path::PathBuf::from)
        .or_else(|| {
            std::env::var_os("HOME")
                .filter(|home| !home.is_empty())
                .map(|home| std::path::PathBuf::from(home).join(".cache"))
        })?;
    Some(base.join("pipefader"))
}

fn send_event(
    sink: &Arc<Mutex<Option<crate::frb_generated::StreamSink<SessionEvent>>>>,
    event: SessionEvent,
) {
    let mut guard = match sink.lock() {
        Ok(guard) => guard,
        Err(_) => return,
    };
    if let Some(sink) = guard.as_ref() {
        if sink.add(event).is_err() {
            *guard = None;
        }
    }
}

fn build_tick(
    app: &AppState,
    sample_rate: u32,
    wave_width: f64,
    wave_fpp: f64,
    include_fx: bool,
) -> Tick {
    let decks = app
        .states
        .iter()
        .map(|state| {
            let hot_cues: Vec<u8> = state
                .hot_cues
                .iter()
                .enumerate()
                .filter_map(|(index, cue)| cue.map(|_| index as u8))
                .collect();
            let hot_cue_frames: Vec<u64> = state
                .hot_cues
                .iter()
                .flatten()
                .map(|cue| cue.frame)
                .collect();
            DeckTick {
                deck: state.deck_id,
                frame: state.current_frame,
                total_frames: state.total_frames,
                sample_rate,
                playing: state.playing,
                tempo: state.tempo,
                tempo_range: state.tempo_range,
                bpm_at_frame: state.bpm_at_frame,
                bpm: state.bpm_at_frame * state.playing_rate,
                playing_rate: state.playing_rate,
                key: state.key.clone().unwrap_or_default(),
                sync_mode: state.sync_mode.clone(),
                sync_leader: state.sync_leader,
                keylock: matches!(state.keylock, KeylockMode::On),
                loop_active: state.loop_range.is_some(),
                loop_in: state.loop_range.map(|(start, _)| start).unwrap_or(0),
                loop_out: state.loop_range.map(|(_, end)| end).unwrap_or(0),
                loop_armed: state.loop_in_armed.is_some(),
                loop_beats_num: state.loop_beats.numerator(),
                loop_beats_den: state.loop_beats.denominator(),
                jump_beats: state.jump_beats,
                cue_frame: state.cue_frame,
                hot_cues,
                hot_cue_frames,
                vinyl: state.vinyl,
                nudge: state.nudge,
                wave: wave_hints(app, state, wave_width, wave_fpp),
                stems_ready: state.stems.ready,
                stems_separated: state.stems.separated,
            }
        })
        .collect();
    let channels = app
        .meters
        .as_ref()
        .map(|meters| {
            meters
                .channels
                .iter()
                .map(|levels| ChannelTick {
                    flow: levels.flow,
                    deck: levels.deck,
                    crossfader: levels.crossfader,
                    cue_send: levels.cue_send,
                    gain: levels.gain,
                })
                .collect()
        })
        .unwrap_or_default();
    let (master_peak, cue_peak, deck_peaks) = app.peaks();
    let fx = if include_fx {
        app.deck_fx
            .iter()
            .enumerate()
            .map(|(deck, slots)| DeckFxTick {
                deck: deck as u8,
                slots: slots.iter().map(fx_slot_dto).collect(),
            })
            .collect()
    } else {
        Vec::new()
    };
    Tick {
        decks,
        channels,
        master_peak,
        cue_peak,
        deck_peaks,
        fx,
    }
}

/// The sketch's FX panel always has something to show. A fresh config has no
/// per-deck inserts, so give each deck one echo and one reverb; if the profile
/// already declares user slots, leave them alone.
fn seed_fx(dispatcher: &Dispatcher, decks: usize) {
    let snapshot = dispatcher.slots().snapshot();
    for deck in 0..decks {
        let chain = protocol::deck_label(deck as u8);
        let has_user_fx = snapshot.get(&chain).is_some_and(|slots| {
            slots
                .iter()
                .any(|slot| !matches!(slot.role.as_str(), "eq" | "filter"))
        });
        if !has_user_fx {
            let base = snapshot.get(&chain).map_or(0, Vec::len);
            for (offset, kind) in ["echo", "reverb"].into_iter().enumerate() {
                let _ = dispatcher.command_tx.send(Command::AddFx {
                    chain: FxChainId::Deck(deck as u8),
                    kind: kind.to_owned(),
                });
                // The sketch starts with FX off; the engine's new slot defaults on.
                let _ = dispatcher.command_tx.send(Command::SetFxEnabled {
                    slot: FxSlotRef {
                        chain: FxChainId::Deck(deck as u8),
                        index: base + offset,
                    },
                    enabled: false,
                });
            }
        }
    }
}

fn build_strip(
    app: &AppState,
    deck: u8,
    center_frame: u64,
    frames_per_pixel: f64,
    columns: u32,
) -> Option<WaveStrip> {
    let waveform = app.waveforms.get(deck as usize)?.as_ref()?;
    let state = app.states.get(deck as usize)?;
    let grid = app.grids.get(deck as usize).and_then(Option::as_ref);
    let columns = columns.clamp(1, 8192);
    let viewport = WaveViewport {
        width: columns,
        frames_per_pixel: frames_per_pixel.max(1.0),
        playhead: center_frame,
    };
    let frame = wave::frame(Some(waveform), grid, state, viewport);
    let mut strip = WaveStrip {
        start_frame: frame.start_frame,
        frames_per_pixel: frame.frames_per_pixel,
        columns: frame.columns.len() as u32,
        left_low: Vec::with_capacity(frame.columns.len()),
        left_mid: Vec::with_capacity(frame.columns.len()),
        left_high: Vec::with_capacity(frame.columns.len()),
        right_low: Vec::with_capacity(frame.columns.len()),
        right_mid: Vec::with_capacity(frame.columns.len()),
        right_high: Vec::with_capacity(frame.columns.len()),
    };
    for column in &frame.columns {
        strip.left_low.push(column.left.low);
        strip.left_mid.push(column.left.mid);
        strip.left_high.push(column.left.high);
        strip.right_low.push(column.right.low);
        strip.right_mid.push(column.right.mid);
        strip.right_high.push(column.right.high);
    }
    Some(strip)
}

fn wave_hints(
    app: &AppState,
    state: &protocol::DeckState,
    width: f64,
    frames_per_pixel: f64,
) -> WaveHints {
    let width_u = width.round().clamp(0.0, f64::from(u32::MAX)) as u32;
    let viewport = WaveViewport {
        width: width_u,
        frames_per_pixel: frames_per_pixel.max(1.0),
        playhead: state.current_frame,
    };
    let grid = app.grids.get(state.deck_id as usize).and_then(Option::as_ref);
    let markers = wave::markers(grid, state, viewport);
    let hot_cues = markers
        .hot_cues
        .iter()
        .filter_map(|(slot, column)| {
            state
                .hot_cues
                .get(*slot as usize)
                .and_then(|cue| cue.as_ref())
                .map(|cue| WaveHotCue {
                    slot: *slot,
                    column: *column as f32,
                    frame: cue.frame,
                })
        })
        .collect();
    WaveHints {
        width: width as f32,
        frames_per_pixel: viewport.frames_per_pixel,
        start_frame: viewport.start_frame(),
        beats: markers.beats.iter().map(|column| *column as f32).collect(),
        bars: markers.bars.iter().map(|column| *column as f32).collect(),
        loop_start: markers.loop_range.map(|(start, _)| start as f32),
        loop_end: markers.loop_range.map(|(_, end)| end as f32),
        loop_armed: markers.loop_armed.map(|column| column as f32),
        cue: markers.cue.map(|column| column as f32),
        hot_cues,
    }
}

fn fx_slot_dto(slot: &protocol::FxSlotStatus) -> FxSlotDto {
    FxSlotDto {
        index: slot.index as u32,
        role: slot.role.clone(),
        kind: slot.kind.clone(),
        enabled: slot.enabled,
        params: slot
            .params
            .iter()
            .map(|param| FxParamDto {
                name: param.name.clone(),
                value: param.value,
                min: param.range.map(|range| range.0),
                max: param.range.map(|range| range.1),
                beats: param.beats,
            })
            .collect(),
    }
}

fn waveform_for(app: &AppState, deck: u8) -> Option<WaveformData> {
    let waveform = app.waveforms.get(deck as usize)?.as_ref()?;
    const COLUMNS: usize = 16_384;
    let total_frames = waveform.total_frames();
    if total_frames == 0 {
        return None;
    }
    let frames_per_column = total_frames as f64 / COLUMNS as f64;
    let mut data = WaveformData {
        columns: COLUMNS as u32,
        total_frames,
        left_low: Vec::with_capacity(COLUMNS),
        left_mid: Vec::with_capacity(COLUMNS),
        left_high: Vec::with_capacity(COLUMNS),
        right_low: Vec::with_capacity(COLUMNS),
        right_mid: Vec::with_capacity(COLUMNS),
        right_high: Vec::with_capacity(COLUMNS),
    };
    for column in waveform.columns(0.0, frames_per_column, COLUMNS) {
        data.left_low.push(column.left.low);
        data.left_mid.push(column.left.mid);
        data.left_high.push(column.left.high);
        data.right_low.push(column.right.low);
        data.right_mid.push(column.right.mid);
        data.right_high.push(column.right.high);
    }
    Some(data)
}

fn cover_for(app: &AppState, deck: u8) -> Option<CoverData> {
    let cover = app.covers.get(deck as usize)?.as_ref()?;
    Some(CoverData {
        width: cover.width,
        height: cover.height,
        rgba: cover.rgba.clone(),
    })
}

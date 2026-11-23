import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:pipefader_gui/core/layout_mode.dart';
import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/model/fixtures.dart';
import 'package:pipefader_gui/model/library.dart';
import 'package:pipefader_gui/model/peaks.dart';
import 'package:pipefader_gui/bridge/engine.dart';
import 'package:pipefader_gui/bridge/generated/api.dart' as frb;
import 'package:pipefader_gui/state/menu_state.dart';

/// The pieces of a deck that change while the sketch runs: transport, tempo,
/// pads, units and the meter.
class DeckRuntime {
  DeckRuntime({
    required this.view,
    required this.frame,
    required this.playing,
    required this.tempo,
    this.index = 0,
  });

  DeckView view;

  /// The deck's slot, which picks its colour from [deckColors].
  final int index;

  int frame;
  bool playing;
  double tempo;
  double nudge = 0;

  bool sync = false;
  bool keylock = true;

  PadMode padMode = PadMode.cue;
  final Set<int> hotCues = <int>{};

  BeatMode beatMode = BeatMode.beatloop;
  int loopBeatsIndex = 4;
  int jumpBeatsIndex = 4;
  bool loopArmed = false;
  bool loopActive = false;

  /// The two switchable slots in the full control band and the phone's single
  /// slot. The option lists are the tabs offered for each slot.
  UnitKind unitA = UnitKind.padsCue;
  UnitKind unitB = UnitKind.mixer;
  UnitKind phoneUnit = UnitKind.padsCue;

  final List<UnitKind> unitAOptions = List<UnitKind>.of(deskUnitA);
  final List<UnitKind> unitBOptions = List<UnitKind>.of(deskUnitB);
  final List<UnitKind> phoneUnitOptions = List<UnitKind>.of(phoneUnitKinds);

  double high = -0.24;
  double mid = 0.14;
  double low = 0.32;
  double filter = -0.10;

  double fader = 0.8;

  int fxSlot = 0;
  int fxParamA = 1;
  int fxParamB = 0;
  String fxParamALabel = 'FB';
  String fxParamBLabel = 'MIX';
  bool fxHasBeats = true;
  double fx1 = 0.36;
  double fx2 = 0.58;
  bool fxOn = false;
  int beatsIndex = 3;

  double meter = 0.4;
  double meterPeak = 0.5;

  /// Embedded artwork decoded on the UI thread, when the track has any.
  ui.Image? cover;

  /// Rust-computed marker columns for the scrolling waveform.
  WaveOverlay? wave;

  /// Rust-computed peak columns for the current viewport (with overscan).
  WaveStripData? strip;
  bool stripPending = false;
  bool stripFailed = false;

  /// Source frames for the whole-track overview.
  int cueFrame = 0;
  int loopIn = 0;
  int loopOut = 0;
  final Map<int, int> hotCueFrames = <int, int>{};

  /// The engine's non-eq/filter slots for this deck, in chain order.
  List<LiveFxSlot> liveFx = const <LiveFxSlot>[];

  String get fxName =>
      liveFx.isEmpty ? fxSlots[fxSlot] : liveFx[fxSlot % liveFx.length].kind;

  List<String> get fxNames =>
      liveFx.isEmpty ? fxSlots : liveFx.map((slot) => slot.kind).toList();

  Peaks get peaks => view.peaks;

  bool get atEnd => frame >= view.totalFrames;

  double get playingRate => tempo + nudge;

  double get bpm => view.bpm * playingRate;

  double get tempoPercent => (tempo - 1.0) * 100.0;

  String get loopLabel => beatLabels[loopBeatsIndex];

  int get jumpSize => jumpSizes[jumpBeatsIndex];
}

/// The session the GUI paints. Without an [EngineClient] it is the original
/// local sketch (fixtures and simulated frames); with one it mirrors the Rust
/// session and forwards every performance action to the engine.
class AppModel extends ChangeNotifier {
  AppModel({
    LayoutMode? forcedLayout,
    int fullDecks = 2,
    int phoneDecks = 2,
    EngineClient? engine,
  }) : this._(forcedLayout, fullDecks, phoneDecks, engine);

  AppModel._(this._forcedLayout, int fullDecks, int phoneDecks, this.engine)
    : _fullDecks = _legalFull(fullDecks),
      _phoneDecks = _legalPhone(phoneDecks),
      decks = _buildDecks(live: engine != null) {
    if (engine != null) {
      _bindEngine();
      unawaited(menu.ensureLoaded());
    }
  }

  /// When non-null the model is driven by the Rust engine instead of the
  /// local sketch. Tests and the web preview leave it null.
  final EngineClient? engine;

  /// The logo menu's profile/output/MIDI snapshot. Kept on the model so opening the menu again
  /// does not lose a half-edited output list.
  late final MenuState menu = MenuState(engine: engine);

  StreamSubscription<frb.SessionEvent>? _engineSub;

  final List<DeckRuntime> decks;

  /// Repainted on every tick; only the time-dependent widgets listen to it, so
  /// the browser and the control band are not rebuilt sixty times a second.
  final ValueNotifier<int> clock = ValueNotifier<int>(0);

  final List<LibEntry> libraryRoots = List<LibEntry>.of(libraries);
  final List<ListEntry> lists = List<ListEntry>.of(playlists);
  final List<TrackRow> allTracks = List<TrackRow>.of(tracks);

  /// Guards against an older async library query overwriting a newer one.
  int _libraryEpoch = 0;
  int? _playlistId;
  double _waveWidth = 0;
  double _waveFpp = 0;
  WavePaletteData? wavePalette;

  LayoutMode? _forcedLayout;
  int _fullDecks;
  int _phoneDecks;

  /// Which deck each full control column drives, left then right.
  final List<int> _fullSlots = <int>[0, 1];

  /// The phone keeps its own pair, because it caps at three decks while the
  /// full band can show four.
  final List<int> _phoneSlots = <int>[0, 1];

  int selectedLibrary = 0;
  int selectedList = 0;
  int selectedTrack = 0;
  bool libraryOpen = true;
  bool rightOpen = false;
  bool searchOpen = false;
  bool browserOverlayOpen = false;
  String searchText = '';

  /// The phone browser drills down one column at a time: 0 library roots, 1
  /// lists, 2 tracks. The deck continues to browse from where it left off when
  /// the overlay closes and reopens.
  int browseDepth = 0;

  /// The shared waveform zoom, in source frames per pixel.
  double framesPerPixel = 340;

  double crossfader = 0.0;

  double _time = 0;

  static const double minFramesPerPixel = 256;
  static const double maxFramesPerPixel = 45000;

  LayoutMode? get forcedLayout => _forcedLayout;

  int get fullDecks => _fullDecks;

  int get phoneDecks => _phoneDecks;

  /// A two-deck rig has nothing to pick, so the deck keys are hidden.
  bool get fullHasDeckChoice => _fullDecks > 2;

  /// The phone stops at three decks; its left column then has 1/3.
  bool get phoneHasDeckChoice => _phoneDecks > 2;

  int deckCountFor(LayoutMode mode) =>
      deckCountForLayout(mode, fullDecks: _fullDecks, phoneDecks: _phoneDecks);

  /// The deck a full control column currently drives.
  int fullSlotDeck(int column) =>
      _fullSlots[column % 2].clamp(0, _fullDecks - 1);

  /// The deck a phone control column currently drives.
  int phoneSlotDeck(int column) =>
      _phoneSlots[column % 2].clamp(0, _phoneDecks - 1);

  List<DeckRuntime> activeDecks(int count) =>
      decks.take(count).toList(growable: false);

  /// The main mark's per-deck sounding flags and the first playing deck. The menu draws the same
  /// `LogoFaders`, so both places stay in step without either owning a copy of the rule.
  ({List<bool> sounding, int leader}) logoStatus(LayoutMode mode) {
    final active = activeDecks(deckCountFor(mode));
    var leader = -1;
    final sounding = <bool>[];
    for (var i = 0; i < active.length; i++) {
      final on = active[i].playing;
      sounding.add(on);
      if (on && leader < 0) leader = i;
    }
    return (sounding: sounding, leader: leader);
  }

  List<TrackRow> get visibleTracks {
    final query = searchText.trim().toLowerCase();
    if (query.isEmpty) return allTracks;
    // The Rust library search also matches the path; filtering by title/artist
    // here would silently drop those hits. With a live engine the query has
    // already been applied, so show its results as-is.
    if (engine != null) return allTracks;
    return allTracks
        .where(
          (track) =>
              track.title.toLowerCase().contains(query) ||
              track.artist.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  /// Total playing time of the visible list, in seconds.
  int get visibleSeconds =>
      visibleTracks.fold(0, (sum, track) => sum + track.seconds);

  /// How many of the visible tracks have peaks ready. The sketch has no
  /// analyser yet, so a track counts as analysed once its peaks exist.
  int get analysedCount => visibleTracks.where((track) => track.bpm > 0).length;

  int get unanalysedCount => visibleTracks.length - analysedCount;

  void setLayout(LayoutMode mode) {
    _forcedLayout = mode;
    browserOverlayOpen = false;
    _resetSlots();
    notifyListeners();
  }

  void setFullDecks(int count) {
    _fullDecks = _legalFull(count);
    _resetSlots();
    notifyListeners();
  }

  void setPhoneDecks(int count) {
    _phoneDecks = _legalPhone(count);
    _resetSlots();
    notifyListeners();
  }

  /// The decks a full control column can drive: 1/3 on the left, 2/4 on the
  /// right.
  List<int> fullColumnDecks(int column) => <int>[
    for (var i = column % 2; i < _fullDecks; i += 2) i,
  ];

  /// The same list for the phone, which stops at three decks.
  List<int> phoneColumnDecks(int column) => <int>[
    for (var i = column % 2; i < _phoneDecks; i += 2) i,
  ];

  /// Selects the deck under a full control column. The picker only offers decks
  /// of that column's parity, so a stale index cannot land on the wrong side.
  void setFullSlot(int column, int deck) {
    final index = column % 2;
    if (deck < 0 || deck >= _fullDecks || deck % 2 != index) return;
    if (_fullSlots[index] == deck) return;
    _fullSlots[index] = deck;
    notifyListeners();
  }

  /// Selects the deck under a phone control column.
  void setPhoneSlot(int column, int deck) {
    final index = column % 2;
    if (deck < 0 || deck >= _phoneDecks || deck % 2 != index) return;
    if (_phoneSlots[index] == deck) return;
    _phoneSlots[index] = deck;
    notifyListeners();
  }

  static int _legalFull(int value) => value >= 4 ? 4 : 2;

  static int _legalPhone(int value) => value >= 3 ? 3 : 2;

  /// A layout or deck-count change must not leave a column on a deck that is
  /// no longer in the rig.
  void _resetSlots() {
    _fullSlots[0] = 0;
    _fullSlots[1] = 1;
    _phoneSlots[0] = 0;
    _phoneSlots[1] = 1;
  }

  void advance(double dt) {
    final step = dt.clamp(0.0, 0.1);
    _time += step;
    if (engine != null) {
      // The engine pushes a tick at ~30Hz; advance the playhead locally between
      // ticks so the waveform moves at the display's refresh rate. The next
      // tick is the source of truth and snaps any drift away.
      for (final deck in decks) {
        if (deck.playing && deck.view.totalFrames > 0) {
          deck.frame += (step * deck.view.sampleRate * deck.playingRate)
              .round();
          if (deck.frame > deck.view.totalFrames) {
            deck.frame = deck.view.totalFrames;
          }
        }
      }
      clock.value++;
      return;
    }
    for (final deck in decks) {
      if (deck.playing && !deck.atEnd) {
        deck.frame += (step * deck.view.sampleRate * deck.playingRate).round();
        if (deck.frame >= deck.view.totalFrames) {
          deck.frame = deck.view.totalFrames;
          deck.playing = false;
        }
      }
      _updateMeter(deck);
    }
    clock.value++;
  }

  void _updateMeter(DeckRuntime deck) {
    final peaks = deck.peaks;
    final index = ((deck.frame / deck.view.totalFrames) * (peaks.length - 1))
        .round()
        .clamp(0, peaks.length - 1);
    final amplitude = peaks.leftLow[index];
    final wobble =
        0.68 +
        0.32 *
            math.sin(_time * 5.1 + deck.view.coverSeed) *
            math.sin(_time * 2.3 + 1.1);
    final level = (amplitude * deck.fader * 0.66 + 0.01) * wobble;
    deck.meter = deck.playing ? level.clamp(0.0, 1.0) : 0.0;
    deck.meterPeak = math.max(deck.meter, deck.meterPeak * 0.985);
  }

  /// Reports the scrolling waveform's pixel width and zoom. Rust uses it to
  /// project beat/cue/loop markers into columns; repeated equal values are
  /// dropped so a build does not spam FFI.
  void setWaveView(double width, double framesPerPixel) {
    if ((width - _waveWidth).abs() < 0.5 &&
        (framesPerPixel - _waveFpp).abs() < 0.01) {
      return;
    }
    _waveWidth = width;
    _waveFpp = framesPerPixel;
    for (final deck in decks) {
      deck.strip = null;
      deck.stripPending = false;
      deck.stripFailed = false;
    }
    unawaited(engine?.setWaveView(width, framesPerPixel));
  }

  // ---- live engine ---------------------------------------------------------

  void _bindEngine() {
    _engineSub = engine!.events.listen(_onEngineEvent);
    unawaited(_loadPalette());
    unawaited(loadLibrary());
  }

  Future<void> _loadPalette() async {
    if (engine == null) return;
    final palette = await engine!.wavePalette();
    wavePalette = WavePaletteData(
      low: palette.low,
      mid: palette.mid,
      high: palette.high,
      beat: palette.beat,
      bar: palette.bar,
      loopWash: palette.loopWash,
      center: palette.center,
      playhead: palette.playhead,
      memoryCue: palette.memoryCue,
      hotCues: palette.hotCues,
    );
    notifyListeners();
  }

  void _onEngineEvent(frb.SessionEvent event) {
    switch (event.kind) {
      case frb.EventKind.tick:
        final tick = event.tick;
        if (tick != null) _applyTick(tick);
      case frb.EventKind.loaded:
        final meta = event.meta;
        if (meta != null) _applyMeta(meta);
      case frb.EventKind.waveformReady:
        unawaited(_loadWaveform(event.deck));
        decks[event.deck].stripFailed = false;
        _ensureStrip(decks[event.deck]);
      case frb.EventKind.coverReady:
        unawaited(_loadCover(event.deck));
      case frb.EventKind.log:
        // The TUI prints these; the GUI has no log pane yet. Keep the last
        // one on the model so a future status strip can show it.
        _lastLog = event.text;
      case frb.EventKind.libraryChanged:
        unawaited(refreshLibrary());
      case frb.EventKind.stopped:
        break;
    }
  }

  String _lastLog = '';

  String get lastLog => _lastLog;

  void _applyMeta(frb.DeckMeta meta) {
    final index = meta.deck;
    if (index < 0 || index >= decks.length) return;
    final deck = decks[index];
    final view = deck.view;
    deck.view = view.copyWith(
      title: meta.title.isEmpty ? 'Untitled' : meta.title,
      artist: meta.artist.isEmpty ? 'Unknown Artist' : meta.artist,
      album: meta.album,
      key: meta.key.isEmpty ? '--' : meta.key,
      bpm: meta.bpm,
      sampleRate: meta.sampleRate > 0 ? meta.sampleRate : view.sampleRate,
      totalFrames: meta.totalFrames.toInt(),
      firstBeat: meta.firstBeat.toInt(),
      peaks: _emptyPeaks(),
    );
    deck.cover?.dispose();
    deck.cover = null;
    deck.wave = null;
    deck.strip = null;
    deck.stripPending = false;
    deck.stripFailed = false;
    deck.cueFrame = 0;
    deck.loopIn = 0;
    deck.loopOut = 0;
    deck.hotCueFrames.clear();
    deck.hotCues.clear();
    deck.meter = 0;
    deck.meterPeak = 0;
    notifyListeners();
  }

  void _applyTick(frb.Tick tick) {
    for (final state in tick.decks) {
      final index = state.deck;
      if (index < 0 || index >= decks.length) continue;
      final deck = decks[index];
      deck.frame = state.frame.toInt();
      deck.playing = state.playing;
      deck.tempo = state.tempo;
      deck.nudge = state.nudge;
      deck.sync = state.syncMode != 'free';
      deck.keylock = state.keylock;
      deck.loopActive = state.loopActive;
      deck.loopArmed = state.loopArmed;
      deck.loopBeatsIndex = _beatIndex(state.loopBeatsNum, state.loopBeatsDen);
      deck.jumpBeatsIndex = _jumpIndex(state.jumpBeats.toInt());
      deck.hotCues
        ..clear()
        ..addAll(state.hotCues);
      deck.hotCueFrames.clear();
      for (var i = 0; i < state.hotCues.length; i++) {
        if (i < state.hotCueFrames.length) {
          deck.hotCueFrames[state.hotCues[i]] = state.hotCueFrames[i].toInt();
        }
      }
      deck.cueFrame = state.cueFrame.toInt();
      deck.loopIn = state.loopIn.toInt();
      deck.loopOut = state.loopOut.toInt();
      final wave = state.wave;
      if (wave.width > 0) {
        deck.wave = WaveOverlay(
          width: wave.width,
          startFrame: wave.startFrame,
          beats: wave.beats,
          bars: wave.bars,
          loopStart: wave.loopStart,
          loopEnd: wave.loopEnd,
          loopArmed: wave.loopArmed,
          cue: wave.cue,
          hotCues: [
            for (final cue in wave.hotCues)
              WaveHotCueHint(slot: cue.slot, column: cue.column),
          ],
        );
      }

      final view = deck.view;
      final sampleRate = state.sampleRate > 0
          ? state.sampleRate
          : view.sampleRate;
      final bpm = state.bpmAtFrame > 0 ? state.bpmAtFrame : view.bpm;
      if (view.sampleRate != sampleRate ||
          view.totalFrames != state.totalFrames.toInt() ||
          (bpm - view.bpm).abs() > 0.001 ||
          (state.tempoRange - view.tempoRange).abs() > 0.0001 ||
          (state.key.isNotEmpty && state.key != view.key)) {
        deck.view = view.copyWith(
          sampleRate: sampleRate,
          totalFrames: state.totalFrames.toInt(),
          bpm: bpm,
          tempoRange: state.tempoRange,
          key: state.key.isEmpty ? view.key : state.key,
        );
      }

      if (index < tick.channels.length) {
        final channel = tick.channels[index];
        // The engine's channel fader is bipolar; the sketch's bar is 0..1.
        deck.fader = (channel.deck + 1) / 2;
      }
      if (index < tick.deckPeaks.length) {
        deck.meter = tick.deckPeaks[index].clamp(0.0, 1.0);
        deck.meterPeak = math.max(deck.meter, deck.meterPeak * 0.985);
      }
      _applyFxTick(index, tick);
      _ensureStrip(deck);
    }
    clock.value++;
    notifyListeners();
  }

  void _applyFxTick(int deckIndex, frb.Tick tick) {
    if (deckIndex >= tick.fx.length) return;
    final deck = decks[deckIndex];
    final slots = tick.fx[deckIndex].slots
        .where((slot) => slot.role != 'eq' && slot.role != 'filter')
        .map(
          (slot) => LiveFxSlot(
            index: slot.index,
            role: slot.role,
            kind: slot.kind,
            enabled: slot.enabled,
            params: slot.params
                .map(
                  (param) => LiveFxParam(
                    name: param.name,
                    value: param.value,
                    min: param.min,
                    max: param.max,
                    beats: param.beats,
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);

    // The tone prefix is not a user slot; draw it from the same chain report.
    for (final slot in tick.fx[deckIndex].slots) {
      if (slot.role == 'eq') {
        deck.high = _paramValue(slot, 'high', deck.high);
        deck.mid = _paramValue(slot, 'mid', deck.mid);
        deck.low = _paramValue(slot, 'low', deck.low);
      } else if (slot.role == 'filter') {
        deck.filter = _paramValue(slot, 'value', deck.filter);
      }
    }

    deck.liveFx = slots;
    if (slots.isEmpty) {
      deck.fxOn = false;
      return;
    }
    deck.fxSlot = deck.fxSlot.clamp(0, slots.length - 1);
    final selected = slots[deck.fxSlot];
    deck.fxOn = selected.enabled;
    final feedback = selected.param('feedback') ?? selected.param('FB');
    final mix = selected.param('mix') ?? selected.param('MIX');
    if (feedback != null) deck.fx1 = feedback.value;
    if (mix != null) deck.fx2 = mix.value;
    for (final param in selected.params) {
      if (param.beats != 0) {
        deck.beatsIndex = _fxBeatIndex(param.beats);
        break;
      }
    }
    // The two knobs the sketch exposes map onto the effect's own parameters:
    // feedback (echo) is the performance control, mix is the wet amount.
    final reverb = selected.kind == 'reverb';
    deck.fxParamALabel = reverb ? 'SIZE' : 'FB';
    deck.fxParamBLabel = 'MIX';
    deck.fxParamA = selected.params.indexWhere(
      (p) => p.name == (reverb ? 'size' : 'feedback'),
    );
    if (deck.fxParamA < 0) deck.fxParamA = 0;
    deck.fxParamB = selected.params.indexWhere((p) => p.name == 'mix');
    if (deck.fxParamB < 0) {
      deck.fxParamB = selected.params.length > 1 ? 1 : 0;
    }
    deck.fxHasBeats = selected.params.any((p) => p.beats != 0);
  }

  static double _paramValue(frb.FxSlotDto slot, String name, double fallback) {
    for (final param in slot.params) {
      if (param.name == name) return param.value;
    }
    return fallback;
  }

  static int _beatIndex(int num, int den) {
    const table = <(int, int)>[
      (1, 4),
      (1, 2),
      (1, 1),
      (2, 1),
      (4, 1),
      (8, 1),
      (16, 1),
      (32, 1),
    ];
    for (var i = 0; i < table.length; i++) {
      if (table[i].$1 == num && table[i].$2 == den) return i;
    }
    return 4;
  }

  static int _jumpIndex(int beats) {
    final value = beats.abs();
    for (var i = 0; i < jumpSizes.length; i++) {
      if (jumpSizes[i] == value) return i;
    }
    return 3;
  }

  static int _fxBeatIndex(int beats) {
    final value = beats > 0 ? beats.toDouble() : 1.0 / -beats;
    const values = <double>[0.125, 0.25, 0.5, 1, 2, 4];
    var best = 3;
    var bestDelta = double.infinity;
    for (var i = 0; i < values.length; i++) {
      final delta = (values[i] - value).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = i;
      }
    }
    return best;
  }

  Future<void> _loadWaveform(int deckIndex) async {
    if (engine == null || deckIndex < 0 || deckIndex >= decks.length) return;
    final data = await engine!.waveform(deckIndex);
    if (data == null) return;
    final deck = decks[deckIndex];
    deck.view = deck.view.copyWith(peaks: _peaksFrom(data));
    notifyListeners();
  }

  Future<void> _loadCover(int deckIndex) async {
    if (engine == null || deckIndex < 0 || deckIndex >= decks.length) return;
    final data = await engine!.cover(deckIndex);
    if (data == null || data.width == 0 || data.height == 0) return;
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      data.rgba,
      data.width,
      data.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    final deck = decks[deckIndex];
    deck.cover?.dispose();
    deck.cover = image;
    notifyListeners();
  }

  void _ensureStrip(DeckRuntime deck) {
    if (engine == null || _waveWidth <= 0 || _waveFpp <= 0) return;
    if (deck.strip == null && deck.stripFailed) return;
    final strip = deck.strip;
    final center = deck.frame.toDouble();
    if (strip != null && (strip.framesPerPixel - _waveFpp).abs() < 0.01) {
      final span = strip.columns * strip.framesPerPixel;
      final left = strip.startFrame;
      final right = left + span;
      if (center >= left + span * 0.25 && center <= right - span * 0.25) {
        return;
      }
    }
    if (deck.stripPending) return;
    deck.stripPending = true;
    final columns = (_waveWidth * 3).round().clamp(64, 8192);
    unawaited(() async {
      try {
        final data = await engine!.waveformStrip(
          deck.index,
          center,
          _waveFpp,
          columns,
        );
        deck.stripPending = false;
        if (data == null || data.columns == 0) {
          deck.stripFailed = true;
          return;
        }
        deck.stripFailed = false;
        deck.strip = WaveStripData(
          startFrame: data.startFrame,
          framesPerPixel: data.framesPerPixel,
          columns: data.columns,
          leftLow: _stripBand(data.leftLow),
          leftMid: _stripBand(data.leftMid),
          leftHigh: _stripBand(data.leftHigh),
          rightLow: _stripBand(data.rightLow),
          rightMid: _stripBand(data.rightMid),
          rightHigh: _stripBand(data.rightHigh),
        );
        notifyListeners();
      } catch (_) {
        deck.stripPending = false;
      }
    }());
  }

  static Float32List _stripBand(Uint8List bytes) {
    final out = Float32List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      out[i] = bytes[i] / 255.0;
    }
    return out;
  }

  static Peaks _peaksFrom(frb.WaveformData data) {
    Float32List toFloats(Uint8List bytes) {
      final out = Float32List(bytes.length);
      for (var i = 0; i < bytes.length; i++) {
        out[i] = bytes[i] / 255.0;
      }
      return out;
    }

    return Peaks(
      leftLow: toFloats(data.leftLow),
      leftMid: toFloats(data.leftMid),
      leftHigh: toFloats(data.leftHigh),
      rightLow: toFloats(data.rightLow),
      rightMid: toFloats(data.rightMid),
      rightHigh: toFloats(data.rightHigh),
    );
  }

  // ---- library (live) ------------------------------------------------------

  Future<void> loadLibrary() => refreshLibrary();

  /// Reloads the browser while keeping the user's column selection if it still
  /// exists. Called at startup and whenever a background scan finishes.
  Future<void> refreshLibrary() async {
    if (engine == null) return;
    final epoch = ++_libraryEpoch;
    final previousSource = selectedLibrary;
    final previousList = selectedList;
    final roots = await engine!.libraryRoots();
    if (epoch != _libraryEpoch) return;
    libraryRoots
      ..clear()
      ..addAll(roots.map((root) => LibEntry(root.name, id: root.id)));
    selectedLibrary = roots.isEmpty
        ? 0
        : previousSource.clamp(0, roots.length - 1);
    selectedTrack = 0;
    notifyListeners();
    if (roots.isEmpty) {
      lists.clear();
      allTracks.clear();
      notifyListeners();
      return;
    }
    final fetchedLists = await engine!.libraryLists(roots[selectedLibrary].id);
    if (epoch != _libraryEpoch) return;
    lists
      ..clear()
      ..addAll(
        fetchedLists.map(
          (list) => ListEntry(list.name, id: list.id, sourceId: list.sourceId),
        ),
      );
    selectedList = fetchedLists.isEmpty
        ? 0
        : previousList.clamp(0, fetchedLists.length - 1);
    if (fetchedLists.isEmpty) {
      allTracks.clear();
      notifyListeners();
      return;
    }
    await _loadTracks(fetchedLists[selectedList].id, epoch);
  }

  Future<void> _loadLists(int sourceId, int epoch) async {
    final lists = await engine!.libraryLists(sourceId);
    if (epoch != _libraryEpoch) return;
    this.lists
      ..clear()
      ..addAll(
        lists.map(
          (list) => ListEntry(list.name, id: list.id, sourceId: list.sourceId),
        ),
      );
    selectedList = 0;
    notifyListeners();
    if (lists.isNotEmpty) {
      await _loadTracks(lists.first.id, epoch);
    } else {
      allTracks.clear();
      notifyListeners();
    }
  }

  Future<void> _loadTracks(int playlistId, int epoch) async {
    final tracks = await engine!.libraryTracks(playlistId);
    if (epoch != _libraryEpoch) return;
    _playlistId = playlistId;
    allTracks
      ..clear()
      ..addAll(tracks.map(_trackFrom));
    selectedTrack = 0;
    notifyListeners();
  }

  static TrackRow _trackFrom(frb.TrackDto track) => TrackRow(
    title: track.title,
    artist: track.artist,
    bpm: track.bpm,
    key: track.key.isEmpty ? '--' : track.key,
    seconds: track.seconds,
    trackId: track.trackId,
    locationId: track.locationId,
  );

  Future<void> _search(String query) async {
    final epoch = ++_libraryEpoch;
    if (query.trim().isEmpty) {
      final playlist = _playlistId;
      if (playlist != null) {
        await _loadTracks(playlist, epoch);
      }
      return;
    }
    final tracks = await engine!.librarySearch(query);
    if (epoch != _libraryEpoch) return;
    allTracks
      ..clear()
      ..addAll(tracks.map(_trackFrom));
    selectedTrack = 0;
    notifyListeners();
  }

  // ---- transport -----------------------------------------------------------

  void togglePlay(DeckRuntime deck) {
    if (deck.atEnd) deck.frame = 0;
    deck.playing = !deck.playing;
    unawaited(engine?.transport(deck.index, frb.TransportAction.toggle));
    notifyListeners();
  }

  void cue(DeckRuntime deck) {
    deck.playing = false;
    deck.frame = deck.view.firstBeat;
    unawaited(engine?.cue(deck.index, frb.CueAction.button));
    notifyListeners();
  }

  void toggleSync(DeckRuntime deck) {
    deck.sync = !deck.sync;
    unawaited(
      engine?.sync(
        deck.index,
        deck.sync ? frb.SyncAction.tempoLock : frb.SyncAction.unlock,
      ),
    );
    notifyListeners();
  }

  void toggleKeylock(DeckRuntime deck) {
    deck.keylock = !deck.keylock;
    unawaited(engine?.setKeylock(deck.index, deck.keylock));
    notifyListeners();
  }

  void setTempo(DeckRuntime deck, double tempo) {
    final range = deck.view.tempoRange;
    deck.tempo = tempo.clamp(1.0 - range, 1.0 + range);
    unawaited(engine?.setTempo(deck.index, deck.tempo));
    notifyListeners();
  }

  void adjustTempo(DeckRuntime deck, double delta) =>
      setTempo(deck, deck.tempo + delta);

  /// A relative bend used by the phone's horizontal drag.
  void setNudge(DeckRuntime deck, double value) {
    deck.nudge = value.clamp(-0.08, 0.08);
    unawaited(engine?.bend(deck.index, deck.nudge));
    notifyListeners();
  }

  void bend(DeckRuntime deck, double direction) {
    deck.nudge = direction * 0.06;
    unawaited(engine?.bend(deck.index, deck.nudge));
    notifyListeners();
  }

  void releaseBend(DeckRuntime deck) {
    if (deck.nudge == 0) return;
    deck.nudge = 0;
    unawaited(engine?.nudge(deck.index, frb.NudgeAction.stop));
    notifyListeners();
  }

  void cyclePadMode(DeckRuntime deck) {
    final modes = PadMode.values;
    setPadMode(deck, modes[(modes.indexOf(deck.padMode) + 1) % modes.length]);
  }

  /// All-in-one still changes pad modes from inside the pads panel. Any slot
  /// currently showing a pad unit follows, so a later layout switch never shows
  /// a CUE tab over LOOP pads.
  void setPadMode(DeckRuntime deck, PadMode mode) {
    deck.padMode = mode;
    final kind = _padUnit(mode);
    for (final slot in ControlSlot.values) {
      if (unitOf(deck, slot).padMode == null) continue;
      final options = unitOptions(deck, slot);
      final legal = _legalUnits(slot);
      if (!options.contains(kind)) {
        options
          ..add(kind)
          ..sort((a, b) => legal.indexOf(a).compareTo(legal.indexOf(b)));
      }
      _assignUnit(deck, slot, kind);
    }
    notifyListeners();
  }

  void tapPad(DeckRuntime deck, int index) {
    switch (deck.padMode) {
      case PadMode.cue:
        if (deck.hotCues.contains(index)) {
          unawaited(
            engine?.hotCue(deck.index, index, frb.HotCueAction.trigger),
          );
        } else {
          deck.hotCues.add(index);
          unawaited(engine?.hotCue(deck.index, index, frb.HotCueAction.set_));
        }
      case PadMode.loop:
        deck.loopBeatsIndex = index.clamp(0, beatLabels.length - 1);
        deck.loopActive = true;
        final (num, den) = _beatFraction(deck.loopBeatsIndex);
        unawaited(engine?.loopBeats(deck.index, num, den));
      case PadMode.jump:
        unawaited(engine?.beatJump(deck.index, jumpLabels[index]));
    }
    notifyListeners();
  }

  // ---- beat bar ------------------------------------------------------------

  void setBeatMode(DeckRuntime deck, BeatMode mode) {
    deck.beatMode = mode;
    notifyListeners();
  }

  void stepLoop(DeckRuntime deck, bool halve) {
    final next = halve ? deck.loopBeatsIndex - 1 : deck.loopBeatsIndex + 1;
    deck.loopBeatsIndex = next.clamp(0, beatLabels.length - 1);
    if (deck.loopActive) {
      unawaited(
        engine?.loop(
          deck.index,
          halve ? frb.LoopAction.halve : frb.LoopAction.double,
        ),
      );
    } else {
      final (num, den) = _beatFraction(deck.loopBeatsIndex);
      unawaited(engine?.loopBeats(deck.index, num, den));
    }
    notifyListeners();
  }

  void setLoopBeats(DeckRuntime deck, int index) {
    deck.loopBeatsIndex = index.clamp(0, beatLabels.length - 1);
    if (deck.loopActive) {
      final (num, den) = _beatFraction(deck.loopBeatsIndex);
      unawaited(engine?.loopBeats(deck.index, num, den));
    }
    notifyListeners();
  }

  void toggleLoopActive(DeckRuntime deck) {
    deck.loopActive = !deck.loopActive;
    if (deck.loopActive) deck.loopArmed = false;
    unawaited(engine?.loop(deck.index, frb.LoopAction.toggle));
    notifyListeners();
  }

  void loopIn(DeckRuntime deck) {
    deck.loopArmed = true;
    deck.loopActive = false;
    unawaited(engine?.loop(deck.index, frb.LoopAction.in_));
    notifyListeners();
  }

  void loopOut(DeckRuntime deck) {
    deck.loopArmed = false;
    deck.loopActive = true;
    unawaited(engine?.loop(deck.index, frb.LoopAction.out));
    notifyListeners();
  }

  void toggleLoopCall(DeckRuntime deck) {
    deck.loopActive = !deck.loopActive;
    if (deck.loopActive) deck.loopArmed = false;
    unawaited(engine?.loop(deck.index, frb.LoopAction.toggle));
    notifyListeners();
  }

  void setJumpBeats(DeckRuntime deck, int index) {
    deck.jumpBeatsIndex = index.clamp(0, jumpSizes.length - 1);
    notifyListeners();
  }

  void jumpBy(DeckRuntime deck, int direction) {
    final beats = jumpSizes[deck.jumpBeatsIndex] * direction;
    if (engine != null) {
      unawaited(engine!.beatJump(deck.index, beats));
    } else {
      final frames = (beats * deck.view.beatFrames).round();
      deck.frame = (deck.frame + frames).clamp(0, deck.view.totalFrames);
    }
    notifyListeners();
  }

  // ---- control slots -------------------------------------------------------

  List<UnitKind> unitOptions(DeckRuntime deck, ControlSlot slot) =>
      switch (slot) {
        ControlSlot.a => deck.unitAOptions,
        ControlSlot.b => deck.unitBOptions,
        ControlSlot.phone => deck.phoneUnitOptions,
      };

  UnitKind unitOf(DeckRuntime deck, ControlSlot slot) => switch (slot) {
    ControlSlot.a => deck.unitA,
    ControlSlot.b => deck.unitB,
    ControlSlot.phone => deck.phoneUnit,
  };

  /// Switches a slot to [kind]. Only an enabled tab can be selected.
  void selectUnit(DeckRuntime deck, ControlSlot slot, UnitKind kind) {
    if (!unitOptions(deck, slot).contains(kind)) return;
    if (unitOf(deck, slot) == kind) return;
    _assignUnit(deck, slot, kind);
    notifyListeners();
  }

  /// Adds or removes a unit tab. The last tab cannot be removed; removing the
  /// active one falls through to the first remaining tab.
  void toggleUnitOption(DeckRuntime deck, ControlSlot slot, UnitKind kind) {
    final legal = _legalUnits(slot);
    if (!legal.contains(kind)) return;
    final options = unitOptions(deck, slot);
    if (options.contains(kind)) {
      if (options.length == 1) return;
      options.remove(kind);
      if (unitOf(deck, slot) == kind) {
        _assignUnit(deck, slot, options.first);
      }
    } else {
      options
        ..add(kind)
        ..sort((a, b) => legal.indexOf(a).compareTo(legal.indexOf(b)));
    }
    notifyListeners();
  }

  List<UnitKind> _legalUnits(ControlSlot slot) => switch (slot) {
    ControlSlot.a => deskUnitA,
    ControlSlot.b => deskUnitB,
    ControlSlot.phone => phoneUnitKinds,
  };

  UnitKind _padUnit(PadMode mode) => switch (mode) {
    PadMode.cue => UnitKind.padsCue,
    PadMode.loop => UnitKind.padsLoop,
    PadMode.jump => UnitKind.padsJump,
  };

  void _assignUnit(DeckRuntime deck, ControlSlot slot, UnitKind kind) {
    switch (slot) {
      case ControlSlot.a:
        deck.unitA = kind;
      case ControlSlot.b:
        deck.unitB = kind;
      case ControlSlot.phone:
        deck.phoneUnit = kind;
    }
    final mode = kind.padMode;
    if (mode != null) deck.padMode = mode;
  }

  void setFader(DeckRuntime deck, double value) {
    deck.fader = value.clamp(0.0, 1.0);
    unawaited(
      engine?.setLevel(
        frb.LevelKind.deck,
        deck.fader * 2 - 1,
        deck: deck.index,
      ),
    );
    notifyListeners();
  }

  void setCrossfader(double value) {
    crossfader = value.clamp(-1.0, 1.0);
    unawaited(engine?.setCrossfader(crossfader));
    notifyListeners();
  }

  void setEq(DeckRuntime deck, int index, double value) {
    final v = value.clamp(-1.0, 1.0);
    switch (index) {
      case 0:
        deck.high = v;
        unawaited(engine?.setEq(deck.index, frb.EqBand.high, v));
      case 1:
        deck.mid = v;
        unawaited(engine?.setEq(deck.index, frb.EqBand.mid, v));
      case 2:
        deck.low = v;
        unawaited(engine?.setEq(deck.index, frb.EqBand.low, v));
      case 3:
        deck.filter = v;
        unawaited(engine?.setEq(deck.index, frb.EqBand.filter, v));
    }
    notifyListeners();
  }

  void setFxParam(DeckRuntime deck, int index, double value) {
    if (index == 0) {
      deck.fx1 = value.clamp(0.0, 1.0);
    } else {
      deck.fx2 = value.clamp(0.0, 1.0);
    }
    if (engine != null && deck.liveFx.isNotEmpty) {
      final slot = deck.liveFx[deck.fxSlot % deck.liveFx.length];
      unawaited(
        engine!.fx(
          deck.index,
          slot.index,
          frb.FxOp.setParam,
          param: index == 0 ? deck.fxParamA : deck.fxParamB,
          value: value.clamp(0.0, 1.0),
        ),
      );
    }
    notifyListeners();
  }

  void setFxSlot(DeckRuntime deck, int slot) {
    deck.fxSlot = slot;
    notifyListeners();
  }

  void toggleFx(DeckRuntime deck) {
    deck.fxOn = !deck.fxOn;
    if (engine != null && deck.liveFx.isNotEmpty) {
      final slot = deck.liveFx[deck.fxSlot % deck.liveFx.length];
      unawaited(
        engine!.fx(
          deck.index,
          slot.index,
          deck.fxOn ? frb.FxOp.enable : frb.FxOp.disable,
        ),
      );
    }
    notifyListeners();
  }

  void stepBeats(DeckRuntime deck, bool backward) {
    final next = deck.beatsIndex + (backward ? -1 : 1);
    deck.beatsIndex = next.clamp(0, fxBeats.length - 1);
    final beats = fxBeatValues[deck.beatsIndex];
    if (engine != null && deck.liveFx.isNotEmpty) {
      final slot = deck.liveFx[deck.fxSlot % deck.liveFx.length];
      var paramIndex = -1;
      for (var i = 0; i < slot.params.length; i++) {
        if (slot.params[i].beats != 0) {
          paramIndex = i;
          break;
        }
      }
      if (paramIndex >= 0) {
        unawaited(
          engine!.fx(
            deck.index,
            slot.index,
            frb.FxOp.setParam,
            param: paramIndex,
            value: beats,
          ),
        );
      }
    }
    notifyListeners();
  }

  // ---- waveform ------------------------------------------------------------

  void zoom({required bool inward}) {
    final factor = inward ? 0.625 : 1.6;
    framesPerPixel = (framesPerPixel * factor).clamp(
      minFramesPerPixel,
      maxFramesPerPixel,
    );
    notifyListeners();
  }

  // ---- browser -------------------------------------------------------------

  void toggleLibrary() {
    libraryOpen = !libraryOpen;
    notifyListeners();
  }

  void toggleRight() {
    rightOpen = !rightOpen;
    notifyListeners();
  }

  void toggleSearch() {
    searchOpen = !searchOpen;
    if (!searchOpen) searchText = '';
    notifyListeners();
  }

  void setSearch(String text) {
    searchText = text;
    selectedTrack = 0;
    if (engine != null) unawaited(_search(text));
    notifyListeners();
  }

  void selectLibrary(int index) {
    selectedLibrary = index;
    selectedList = 0;
    selectedTrack = 0;
    if (engine != null && index >= 0 && index < libraryRoots.length) {
      final epoch = ++_libraryEpoch;
      unawaited(_loadLists(libraryRoots[index].id, epoch));
    }
    notifyListeners();
  }

  void selectList(int index) {
    selectedList = index;
    selectedTrack = 0;
    if (engine != null && index >= 0 && index < lists.length) {
      final epoch = ++_libraryEpoch;
      unawaited(_loadTracks(lists[index].id, epoch));
    }
    notifyListeners();
  }

  void selectTrack(int index) {
    selectedTrack = index;
    notifyListeners();
  }

  void openBrowserOverlay() {
    browserOverlayOpen = true;
    notifyListeners();
  }

  void closeBrowserOverlay() {
    browserOverlayOpen = false;
    notifyListeners();
  }

  /// Steps the phone browser one column deeper (library → lists → tracks).
  void browseInto() {
    if (browseDepth < 2) {
      browseDepth += 1;
      notifyListeners();
    }
  }

  /// Steps the phone browser back one column.
  void browseBack() {
    if (browseDepth > 0) {
      browseDepth -= 1;
      notifyListeners();
    }
  }

  /// Loads the picked track onto a deck and closes the overlay, keeping the
  /// browse depth so reopening returns to the same list.
  void loadTrackOnto(DeckRuntime deck, int index) {
    final visible = visibleTracks;
    if (index < 0 || index >= visible.length) return;
    selectedTrack = index;
    browserOverlayOpen = false;
    loadTrackRow(deck, visible[index]);
  }

  /// Loads one library row into a deck. Used by the phone tap and by dropping a
  /// row on a deck header.
  void loadTrackRow(DeckRuntime deck, TrackRow track) {
    browserOverlayOpen = false;
    final view = deck.view;
    deck.view = view.copyWith(
      title: track.title,
      artist: track.artist,
      key: track.key,
      bpm: track.bpm,
      totalFrames: track.seconds * view.sampleRate,
      firstBeat: 0,
    );
    deck.cover?.dispose();
    deck.cover = null;
    deck.wave = null;
    deck.strip = null;
    deck.stripPending = false;
    deck.stripFailed = false;
    deck.cueFrame = 0;
    deck.loopIn = 0;
    deck.loopOut = 0;
    deck.hotCueFrames.clear();
    deck.hotCues.clear();
    if (engine != null && track.locationId >= 0) {
      unawaited(engine!.loadTrack(deck.index, track.locationId));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _engineSub?.cancel();
    for (final deck in decks) {
      deck.cover?.dispose();
    }
    menu.dispose();
    clock.dispose();
    super.dispose();
  }

  static Peaks _emptyPeaks() => Peaks(
    leftLow: Float32List(2),
    leftMid: Float32List(2),
    leftHigh: Float32List(2),
    rightLow: Float32List(2),
    rightMid: Float32List(2),
    rightHigh: Float32List(2),
  );

  static DeckView _blankView(int index) {
    return DeckView(
      artist: '',
      title: 'No Track',
      album: '',
      key: '--',
      bpm: 0,
      sampleRate: 44100,
      totalFrames: 0,
      firstBeat: 0,
      peaks: _emptyPeaks(),
      coverSeed: index,
    );
  }

  static List<DeckRuntime> _buildDecks({bool live = false}) {
    if (live) {
      return [
        for (var index = 0; index < 4; index++)
          DeckRuntime(
            view: _blankView(index),
            index: index,
            frame: 0,
            playing: false,
            tempo: 1.0,
          ),
      ];
    }
    final views = buildDecks();
    return [
      DeckRuntime(
        view: views[0],
        index: 0,
        frame: (views[0].totalFrames * 0.372).round(),
        playing: true,
        tempo: 1.0,
      )..hotCues.addAll(const [0, 2, 4]),
      DeckRuntime(
          view: views[1],
          index: 1,
          frame: (views[1].totalFrames * 0.518).round(),
          playing: false,
          tempo: 1.02,
        )
        ..hotCues.addAll(const [1, 3])
        ..high = 0.16
        ..mid = -0.22
        ..low = 0.20
        ..filter = -0.28,
      DeckRuntime(
        view: views[2],
        index: 2,
        frame: (views[2].totalFrames * 0.214).round(),
        playing: false,
        tempo: 0.99,
      )..hotCues.add(6),
      DeckRuntime(
          view: views[3],
          index: 3,
          frame: (views[3].totalFrames * 0.633).round(),
          playing: false,
          tempo: 1.0,
        )
        ..high = -0.08
        ..low = 0.44
        ..filter = 0.12,
    ];
  }
}

(int, int) _beatFraction(int index) {
  const table = <(int, int)>[
    (1, 4),
    (1, 2),
    (1, 1),
    (2, 1),
    (4, 1),
    (8, 1),
    (16, 1),
    (32, 1),
  ];
  return table[index.clamp(0, table.length - 1)];
}

const beatLabels = <String>['1/4', '1/2', '1', '2', '4', '8', '16', '32'];
const jumpSizes = <int>[1, 2, 4, 8, 16, 32];
const jumpLabels = <int>[-16, -8, -4, -2, 2, 4, 8, 16];
const fxBeatValues = <double>[0.125, 0.25, 0.5, 1, 2, 4];
const fxBeats = <String>['1/8', '1/4', '1/2', '1', '2', '4'];
const fxSlots = <String>['echo', 'delay', 'reverb'];

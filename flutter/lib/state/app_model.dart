import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../model/deck.dart';
import '../model/fixtures.dart';
import '../model/library.dart';
import '../model/peaks.dart';

/// The pieces of a deck that change while the sketch runs: transport, tempo,
/// pads, units and the meter.
class DeckRuntime {
  DeckRuntime({
    required this.view,
    required this.frame,
    required this.playing,
    required this.tempo,
  });

  final DeckView view;

  int frame;
  bool playing;
  double tempo;
  double nudge = 0;

  bool sync = false;

  PadMode padMode = PadMode.cue;
  final Set<int> hotCues = <int>{};
  int loopIndex = 4;
  int jumpIndex = 4;
  int jumpSizeIndex = 4;
  bool loopArmed = false;
  bool loopActive = false;

  /// The outer slot is fixed to the pads; only the inner one is switchable.
  UnitKind unitInner = UnitKind.beatctl;

  double high = -0.24;
  double mid = 0.14;
  double low = 0.32;
  double filter = -0.10;

  double fader = 0.8;

  int fxSlot = 0;
  double fx1 = 0.36;
  double fx2 = 0.58;
  bool fxHold = false;
  int beatsIndex = 3;

  double meter = 0.4;
  double meterPeak = 0.5;

  Peaks get peaks => view.peaks;

  bool get atEnd => frame >= view.totalFrames;

  double get playingRate => tempo + nudge;

  double get bpm => view.bpm * playingRate;

  double get tempoPercent => (tempo - 1.0) * 100.0;

  String get loopLabel => PadMode.loop.pads[loopIndex];

  int get jumpSize => jumpSizes[jumpSizeIndex];
}

/// The session the GUI paints. A sketch only: everything advances locally and
/// nothing here talks to the engine.
class AppModel extends ChangeNotifier {
  AppModel._(this.decks);

  factory AppModel() {
    final views = buildDecks();
    return AppModel._([
      DeckRuntime(
        view: views[0],
        frame: (views[0].totalFrames * 0.372).round(),
        playing: true,
        tempo: 1.0,
      )..hotCues.addAll(const [0, 2, 4]),
      DeckRuntime(
        view: views[1],
        frame: (views[1].totalFrames * 0.518).round(),
        playing: false,
        tempo: 1.02,
      )
        ..hotCues.addAll(const [1, 3])
        ..high = 0.16
        ..mid = -0.22
        ..low = 0.20
        ..filter = -0.28,
    ]);
  }

  final List<DeckRuntime> decks;

  /// Repainted on every tick; only the time-dependent widgets listen to it, so
  /// the browser and the control band are not rebuilt sixty times a second.
  final ValueNotifier<int> clock = ValueNotifier<int>(0);

  final List<LibEntry> libraryRoots = libraries;
  final List<ListEntry> lists = playlists;
  final List<TrackRow> allTracks = tracks;

  int selectedLibrary = 0;
  int selectedList = 0;
  int selectedTrack = 0;
  bool libraryOpen = true;
  bool searchOpen = false;
  String searchText = '';

  /// The shared waveform zoom, in source frames per pixel.
  double framesPerPixel = 340;

  double crossfader = 0.0;

  double _time = 0;

  static const double minFramesPerPixel = 40;
  static const double maxFramesPerPixel = 45000;

  List<TrackRow> get visibleTracks {
    final query = searchText.trim().toLowerCase();
    if (query.isEmpty) return allTracks;
    return allTracks
        .where((track) =>
            track.title.toLowerCase().contains(query) ||
            track.artist.toLowerCase().contains(query))
        .toList(growable: false);
  }

  void advance(double dt) {
    final step = dt.clamp(0.0, 0.1);
    _time += step;
    for (final deck in decks) {
      if (deck.playing && !deck.atEnd) {
        deck.frame +=
            (step * deck.view.sampleRate * deck.playingRate).round();
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
    final wobble = 0.68 +
        0.32 *
            math.sin(_time * 5.1 + deck.view.coverSeed) *
            math.sin(_time * 2.3 + 1.1);
    final level = (amplitude * deck.fader * 0.66 + 0.01) * wobble;
    deck.meter = deck.playing ? level.clamp(0.0, 1.0) : 0.0;
    deck.meterPeak = math.max(deck.meter, deck.meterPeak * 0.985);
  }

  // ---- transport -----------------------------------------------------------

  void togglePlay(DeckRuntime deck) {
    if (deck.atEnd) deck.frame = 0;
    deck.playing = !deck.playing;
    notifyListeners();
  }

  void cue(DeckRuntime deck) {
    deck.playing = false;
    deck.frame = deck.view.firstBeat;
    notifyListeners();
  }

  void toggleSync(DeckRuntime deck) {
    deck.sync = !deck.sync;
    notifyListeners();
  }

  void adjustTempo(DeckRuntime deck, double delta) {
    final range = deck.view.tempoRange;
    deck.tempo = (deck.tempo + delta).clamp(1.0 - range, 1.0 + range);
    notifyListeners();
  }

  void bend(DeckRuntime deck, double direction) {
    deck.nudge = direction * 0.06;
    notifyListeners();
  }

  void releaseBend(DeckRuntime deck) {
    if (deck.nudge == 0) return;
    deck.nudge = 0;
    notifyListeners();
  }

  void cyclePadMode(DeckRuntime deck) {
    final modes = PadMode.values;
    deck.padMode = modes[(modes.indexOf(deck.padMode) + 1) % modes.length];
    notifyListeners();
  }

  void setPadMode(DeckRuntime deck, PadMode mode) {
    deck.padMode = mode;
    notifyListeners();
  }

  void tapPad(DeckRuntime deck, int index) {
    switch (deck.padMode) {
      case PadMode.cue:
        if (!deck.hotCues.remove(index)) deck.hotCues.add(index);
      case PadMode.loop:
        deck.loopIndex = index;
      case PadMode.jump:
        deck.jumpIndex = index;
    }
    notifyListeners();
  }

  void stepLoop(DeckRuntime deck, bool halve) {
    final next = halve ? deck.loopIndex - 1 : deck.loopIndex + 1;
    deck.loopIndex = next.clamp(0, PadMode.loop.pads.length - 1);
    notifyListeners();
  }

  void setJumpSize(DeckRuntime deck, int index) {
    deck.jumpSizeIndex = index.clamp(0, jumpSizes.length - 1);
    notifyListeners();
  }

  void jumpBy(DeckRuntime deck, int direction) {
    final frames =
        (deck.jumpSize * direction * deck.view.beatFrames).round();
    deck.frame = (deck.frame + frames).clamp(0, deck.view.totalFrames);
    notifyListeners();
  }

  void loopIn(DeckRuntime deck) {
    deck.loopArmed = true;
    deck.loopActive = false;
    notifyListeners();
  }

  void loopOut(DeckRuntime deck) {
    deck.loopArmed = false;
    deck.loopActive = true;
    notifyListeners();
  }

  void toggleLoopCall(DeckRuntime deck) {
    deck.loopActive = !deck.loopActive;
    notifyListeners();
  }

  // ---- control slots -------------------------------------------------------

  void setUnit(DeckRuntime deck, UnitKind kind) {
    deck.unitInner = kind;
    notifyListeners();
  }

  void setFader(DeckRuntime deck, double value) {
    deck.fader = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setCrossfader(double value) {
    crossfader = value.clamp(-1.0, 1.0);
    notifyListeners();
  }

  void setEq(DeckRuntime deck, int index, double value) {
    final v = value.clamp(-1.0, 1.0);
    switch (index) {
      case 0:
        deck.high = v;
      case 1:
        deck.mid = v;
      case 2:
        deck.low = v;
      case 3:
        deck.filter = v;
    }
    notifyListeners();
  }

  void setFxParam(DeckRuntime deck, int index, double value) {
    if (index == 0) {
      deck.fx1 = value.clamp(0.0, 1.0);
    } else {
      deck.fx2 = value.clamp(0.0, 1.0);
    }
    notifyListeners();
  }

  void setFxSlot(DeckRuntime deck, int slot) {
    deck.fxSlot = slot;
    notifyListeners();
  }

  void toggleFxHold(DeckRuntime deck) {
    deck.fxHold = !deck.fxHold;
    notifyListeners();
  }

  void setFxHold(DeckRuntime deck, bool hold) {
    if (deck.fxHold == hold) return;
    deck.fxHold = hold;
    notifyListeners();
  }

  void stepBeats(DeckRuntime deck, bool backward) {
    final next = deck.beatsIndex + (backward ? -1 : 1);
    deck.beatsIndex = next.clamp(0, fxBeats.length - 1);
    notifyListeners();
  }

  // ---- waveform ------------------------------------------------------------

  void zoom({required bool inward}) {
    final factor = inward ? 0.625 : 1.6;
    framesPerPixel =
        (framesPerPixel * factor).clamp(minFramesPerPixel, maxFramesPerPixel);
    notifyListeners();
  }

  // ---- browser -------------------------------------------------------------

  void toggleLibrary() {
    libraryOpen = !libraryOpen;
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
    notifyListeners();
  }

  void selectLibrary(int index) {
    selectedLibrary = index;
    selectedList = 0;
    selectedTrack = 0;
    notifyListeners();
  }

  void selectList(int index) {
    selectedList = index;
    selectedTrack = 0;
    notifyListeners();
  }

  void selectTrack(int index) {
    selectedTrack = index;
    notifyListeners();
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }
}

const fxBeats = <String>['1/8', '1/4', '1/2', '1', '2', '4'];
const jumpSizes = <int>[1, 2, 4, 8, 16, 32];

const fxSlots = <String>['echo', 'delay', 'reverb'];

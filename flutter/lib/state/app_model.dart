import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:pipefader_gui/core/layout_mode.dart';
import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/model/fixtures.dart';
import 'package:pipefader_gui/model/library.dart';
import 'package:pipefader_gui/model/peaks.dart';

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

  final DeckView view;

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

  final List<UnitKind> unitAOptions = List<UnitKind>.of(deskUnitKinds);
  final List<UnitKind> unitBOptions = List<UnitKind>.of(deskUnitKinds);
  final List<UnitKind> phoneUnitOptions = List<UnitKind>.of(phoneUnitKinds);

  double high = -0.24;
  double mid = 0.14;
  double low = 0.32;
  double filter = -0.10;

  double fader = 0.8;

  int fxSlot = 0;
  double fx1 = 0.36;
  double fx2 = 0.58;
  bool fxOn = false;
  int beatsIndex = 3;

  double meter = 0.4;
  double meterPeak = 0.5;

  Peaks get peaks => view.peaks;

  bool get atEnd => frame >= view.totalFrames;

  double get playingRate => tempo + nudge;

  double get bpm => view.bpm * playingRate;

  double get tempoPercent => (tempo - 1.0) * 100.0;

  String get loopLabel => beatLabels[loopBeatsIndex];

  int get jumpSize => jumpSizes[jumpBeatsIndex];
}

/// The session the GUI paints. A sketch only: everything advances locally and
/// nothing here talks to the engine.
class AppModel extends ChangeNotifier {
  AppModel({LayoutMode? forcedLayout, int fullDecks = 2, int phoneDecks = 2})
    : this._(forcedLayout, fullDecks, phoneDecks);

  AppModel._(this._forcedLayout, int fullDecks, int phoneDecks)
    : _fullDecks = _legalFull(fullDecks),
      _phoneDecks = _legalPhone(phoneDecks),
      decks = _buildDecks();

  final List<DeckRuntime> decks;

  /// Repainted on every tick; only the time-dependent widgets listen to it, so
  /// the browser and the control band are not rebuilt sixty times a second.
  final ValueNotifier<int> clock = ValueNotifier<int>(0);

  final List<LibEntry> libraryRoots = libraries;
  final List<ListEntry> lists = playlists;
  final List<TrackRow> allTracks = tracks;

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

  static const double minFramesPerPixel = 40;
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

  List<TrackRow> get visibleTracks {
    final query = searchText.trim().toLowerCase();
    if (query.isEmpty) return allTracks;
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

  void toggleKeylock(DeckRuntime deck) {
    deck.keylock = !deck.keylock;
    notifyListeners();
  }

  void setTempo(DeckRuntime deck, double tempo) {
    final range = deck.view.tempoRange;
    deck.tempo = tempo.clamp(1.0 - range, 1.0 + range);
    notifyListeners();
  }

  void adjustTempo(DeckRuntime deck, double delta) =>
      setTempo(deck, deck.tempo + delta);

  /// A relative bend used by the phone's horizontal drag.
  void setNudge(DeckRuntime deck, double value) {
    deck.nudge = value.clamp(-0.08, 0.08);
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
        if (!deck.hotCues.remove(index)) deck.hotCues.add(index);
      case PadMode.loop:
        deck.loopBeatsIndex = index.clamp(0, beatLabels.length - 1);
        deck.loopActive = true;
      case PadMode.jump:
        deck.jumpBeatsIndex = index.clamp(0, jumpSizes.length - 1);
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
    notifyListeners();
  }

  void setLoopBeats(DeckRuntime deck, int index) {
    deck.loopBeatsIndex = index.clamp(0, beatLabels.length - 1);
    notifyListeners();
  }

  void toggleLoopActive(DeckRuntime deck) {
    deck.loopActive = !deck.loopActive;
    if (deck.loopActive) deck.loopArmed = false;
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
    if (deck.loopActive) deck.loopArmed = false;
    notifyListeners();
  }

  void setJumpBeats(DeckRuntime deck, int index) {
    deck.jumpBeatsIndex = index.clamp(0, jumpSizes.length - 1);
    notifyListeners();
  }

  void jumpBy(DeckRuntime deck, int direction) {
    final frames = (deck.jumpSize * direction * deck.view.beatFrames).round();
    deck.frame = (deck.frame + frames).clamp(0, deck.view.totalFrames);
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
    ControlSlot.a || ControlSlot.b => deskUnitKinds,
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

  void toggleFx(DeckRuntime deck) {
    deck.fxOn = !deck.fxOn;
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
    selectedTrack = index;
    browserOverlayOpen = false;
    notifyListeners();
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  static List<DeckRuntime> _buildDecks() {
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

const beatLabels = <String>['1/4', '1/2', '1', '2', '4', '8', '16', '32'];
const jumpSizes = <int>[1, 2, 4, 8, 16, 32];
const fxBeats = <String>['1/8', '1/4', '1/2', '1', '2', '4'];
const fxSlots = <String>['echo', 'delay', 'reverb'];

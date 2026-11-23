import 'dart:typed_data';

import 'package:pipefader_gui/model/peaks.dart';

/// What a control slot can become. The three pad modes are separate units, so
/// a slot's tabs are the units themselves rather than a second mode row.
/// [mixerMax] only appears on the phone, where the EQ and FX share one column.
enum UnitKind { padsCue, padsLoop, padsJump, tempo, mixer, fx, mixerMax }

extension UnitKindLabel on UnitKind {
  String get label => switch (this) {
    UnitKind.padsCue => 'cue',
    UnitKind.padsLoop => 'loop',
    UnitKind.padsJump => 'jump',
    UnitKind.tempo => 'tempo',
    UnitKind.mixer => 'mixer',
    UnitKind.fx => 'fx',
    UnitKind.mixerMax => 'mixer max',
  };

  /// The short label used in a unit slot's tab row.
  String get tabLabel => switch (this) {
    UnitKind.mixerMax => 'Mixer',
    _ => label,
  };

  /// The pad mode a pad unit drives; null for the other units.
  PadMode? get padMode => switch (this) {
    UnitKind.padsCue => PadMode.cue,
    UnitKind.padsLoop => PadMode.loop,
    UnitKind.padsJump => PadMode.jump,
    _ => null,
  };
}

/// Which switchable slot a unit header belongs to.
enum ControlSlot { a, b, phone }

/// The desk's first slot is pad-only; the second is the mixer/performance slot.
const List<UnitKind> deskUnitA = <UnitKind>[
  UnitKind.padsCue,
  UnitKind.padsLoop,
  UnitKind.padsJump,
];

const List<UnitKind> deskUnitB = <UnitKind>[
  UnitKind.mixer,
  UnitKind.tempo,
  UnitKind.fx,
];

/// The units offered in the phone's single slot.
const List<UnitKind> phoneUnitKinds = <UnitKind>[
  UnitKind.padsCue,
  UnitKind.padsLoop,
  UnitKind.padsJump,
  UnitKind.mixerMax,
];

/// What the beat bar over a waveform is showing.
enum BeatMode { beatloop, beatjump, manualloop }

extension BeatModeLabel on BeatMode {
  String get label => switch (this) {
    BeatMode.beatloop => 'beatloop',
    BeatMode.beatjump => 'beatjump',
    BeatMode.manualloop => 'manualloop',
  };
}

/// What the eight pads fire.
enum PadMode { cue, loop, jump }

extension PadModeLabel on PadMode {
  String get label => switch (this) {
    PadMode.cue => 'cue',
    PadMode.loop => 'loop',
    PadMode.jump => 'jump',
  };

  List<String> get pads => switch (this) {
    PadMode.cue => const ['1', '2', '3', '4', '5', '6', '7', '8'],
    PadMode.loop => const ['1/4', '1/2', '1', '2', '4', '8', '16', '32'],
    PadMode.jump => const ['-16', '-8', '-4', '-2', '+2', '+4', '+8', '+16'],
  };
}

/// The one palette the Rust side sends for both front-ends.
class WavePaletteData {
  const WavePaletteData({
    required this.low,
    required this.mid,
    required this.high,
    required this.beat,
    required this.bar,
    required this.loopWash,
    required this.center,
    required this.playhead,
    required this.memoryCue,
    required this.hotCues,
  });

  final int low;
  final int mid;
  final int high;
  final int beat;
  final int bar;
  final int loopWash;
  final int center;
  final int playhead;
  final int memoryCue;
  final List<int> hotCues;
}

/// A viewport-sized waveform slice with one screen of overscan on each side.
class WaveStripData {
  const WaveStripData({
    required this.startFrame,
    required this.framesPerPixel,
    required this.columns,
    required this.leftLow,
    required this.leftMid,
    required this.leftHigh,
    required this.rightLow,
    required this.rightMid,
    required this.rightHigh,
  });

  final double startFrame;
  final double framesPerPixel;
  final int columns;
  final Float32List leftLow;
  final Float32List leftMid;
  final Float32List leftHigh;
  final Float32List rightLow;
  final Float32List rightMid;
  final Float32List rightHigh;
}

/// One hot cue as the engine projects it onto the current waveform viewport.
class WaveHotCueHint {
  const WaveHotCueHint({required this.slot, required this.column});

  final int slot;
  final double column;
}

/// Rust-computed overlay for one scrolling waveform. Columns are pixels from
/// the left edge of the view the UI last sent.
class WaveOverlay {
  const WaveOverlay({
    required this.width,
    required this.startFrame,
    required this.beats,
    required this.bars,
    this.loopStart,
    this.loopEnd,
    this.loopArmed,
    this.cue,
    this.hotCues = const <WaveHotCueHint>[],
  });

  final double width;
  final double startFrame;
  final List<double> beats;
  final List<double> bars;
  final double? loopStart;
  final double? loopEnd;
  final double? loopArmed;
  final double? cue;
  final List<WaveHotCueHint> hotCues;
}

/// One FX slot as the engine reports it. Kept local (rather than importing the
/// generated bridge type) so the widget layer never depends on codegen output.
class LiveFxParam {
  const LiveFxParam({
    required this.name,
    required this.value,
    this.min,
    this.max,
    this.beats = 0,
  });

  final String name;
  final double value;
  final double? min;
  final double? max;
  final int beats;
}

class LiveFxSlot {
  const LiveFxSlot({
    required this.index,
    required this.role,
    required this.kind,
    required this.enabled,
    required this.params,
  });

  final int index;
  final String role;
  final String kind;
  final bool enabled;
  final List<LiveFxParam> params;

  LiveFxParam? param(String name) {
    for (final p in params) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// Everything about a deck that does not change while the sketch runs. Runtime
/// state (position, tempo, pads) lives in the app model.
class DeckView {
  const DeckView({
    required this.artist,
    required this.title,
    required this.album,
    required this.key,
    required this.bpm,
    required this.sampleRate,
    required this.totalFrames,
    required this.firstBeat,
    required this.peaks,
    required this.coverSeed,
    this.tempoRange = 0.08,
  });

  final String artist;
  final String title;
  final String album;
  final String key;
  final double bpm;
  final double tempoRange;
  final int sampleRate;
  final int totalFrames;

  /// Source frame of the first downbeat; the grid is `bpm` after that.
  final int firstBeat;

  final Peaks peaks;
  final int coverSeed;

  DeckView copyWith({
    String? artist,
    String? title,
    String? album,
    String? key,
    double? bpm,
    double? tempoRange,
    int? sampleRate,
    int? totalFrames,
    int? firstBeat,
    Peaks? peaks,
    int? coverSeed,
  }) {
    return DeckView(
      artist: artist ?? this.artist,
      title: title ?? this.title,
      album: album ?? this.album,
      key: key ?? this.key,
      bpm: bpm ?? this.bpm,
      tempoRange: tempoRange ?? this.tempoRange,
      sampleRate: sampleRate ?? this.sampleRate,
      totalFrames: totalFrames ?? this.totalFrames,
      firstBeat: firstBeat ?? this.firstBeat,
      peaks: peaks ?? this.peaks,
      coverSeed: coverSeed ?? this.coverSeed,
    );
  }

  double get beatFrames => sampleRate * 60.0 / bpm;
  double get seconds => totalFrames / sampleRate;
}

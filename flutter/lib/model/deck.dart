import 'peaks.dart';

/// What a control slot can become. [mixerMax] only appears on the phone, where
/// the EQ and FX share one column.
enum UnitKind { pads, tempo, mixer, fx, mixerMax }

extension UnitKindLabel on UnitKind {
  String get label => switch (this) {
    UnitKind.pads => 'pads',
    UnitKind.tempo => 'tempo',
    UnitKind.mixer => 'mixer',
    UnitKind.fx => 'fx',
    UnitKind.mixerMax => 'mixer max',
  };
}

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

  double get beatFrames => sampleRate * 60.0 / bpm;
  double get seconds => totalFrames / sampleRate;
}

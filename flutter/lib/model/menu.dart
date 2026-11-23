import 'package:pipefader_gui/bridge/generated/api.dart' as frb;

/// The two mixer roles the Output page exposes. The config file spells the second one `cue`;
/// the menu says "precue" so it is not confused with a deck's cue button.
enum OutputRole { master, precue }

extension OutputRoleX on OutputRole {
  String get label => this == OutputRole.master ? 'Master' : 'Precue';

  /// The spelling written to `[[mixer.output]].role`.
  String get configName => this == OutputRole.master ? 'master' : 'cue';

  static OutputRole fromConfig(String value) =>
      value == 'cue' ? OutputRole.precue : OutputRole.master;
}

/// One `[[mixer.output]]` row as the menu shows it.
class OutputChannel {
  const OutputChannel({
    required this.index,
    required this.name,
    required this.role,
    this.device = '',
    this.channels,
    this.gain = 1,
  });

  final int index;
  final String name;
  final OutputRole role;
  final String device;
  final (int, int)? channels;
  final double gain;

  factory OutputChannel.fromDto(frb.OutputDto dto) => OutputChannel(
    index: dto.index,
    name: dto.name,
    role: OutputRoleX.fromConfig(dto.role),
    device: dto.device,
    channels: dto.channels.length == 2
        ? (dto.channels[0], dto.channels[1])
        : null,
    gain: dto.gain,
  );

  /// `CH 1-2` for a bound pair, `CH --` when the file left it to the device default.
  String get channelLabel {
    final pair = channels;
    return pair == null ? 'CH --' : 'CH ${pair.$1}-${pair.$2}';
  }

  /// A second line for a bound device; empty when the host default is in use.
  String get deviceLabel => device.isEmpty ? 'System default' : device;
}

/// One selectable controller-map file.
class MapFileInfo {
  const MapFileInfo({
    required this.path,
    required this.name,
    this.builtin = false,
  });

  final String path;
  final String name;
  final bool builtin;

  factory MapFileInfo.fromDto(frb.MapFileDto dto) =>
      MapFileInfo(path: dto.path, name: dto.name, builtin: dto.builtin);
}

/// One selectable MIDI input.
class MidiPortInfo {
  const MidiPortInfo({required this.index, required this.name});

  final int index;
  final String name;

  factory MidiPortInfo.fromDto(frb.MidiPortDto dto) =>
      MidiPortInfo(index: dto.index, name: dto.name);
}

/// The machine settings the menu can edit. Values mirror the profile; names are the menu's, not
/// TOML paths.
class MenuSettings {
  const MenuSettings({
    this.sampleRate = 44100,
    this.crossfaderCurve = 'classic',
    this.cueBlend = -1,
    this.autogain = false,
  });

  final int sampleRate;
  final String crossfaderCurve;
  final double cueBlend;
  final bool autogain;

  MenuSettings copyWith({
    int? sampleRate,
    String? crossfaderCurve,
    double? cueBlend,
    bool? autogain,
  }) => MenuSettings(
    sampleRate: sampleRate ?? this.sampleRate,
    crossfaderCurve: crossfaderCurve ?? this.crossfaderCurve,
    cueBlend: cueBlend ?? this.cueBlend,
    autogain: autogain ?? this.autogain,
  );

  factory MenuSettings.fromDto(frb.MenuStateDto dto) => MenuSettings(
    sampleRate: dto.sampleRate,
    crossfaderCurve: dto.crossfaderCurve,
    cueBlend: dto.cueBlend,
    autogain: dto.autogain,
  );

  /// The menu's three presets for the continuous -1..1 blend.
  String get cueBlendName => switch (cueBlend) {
    < -0.5 => 'cue',
    > 0.5 => 'master',
    _ => 'both',
  };
}

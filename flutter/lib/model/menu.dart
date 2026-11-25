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

/// One library source shown in Preferences.
class LibrarySourceInfo {
  const LibrarySourceInfo({
    required this.id,
    required this.name,
    required this.path,
    required this.origin,
  });

  final int id;
  final String name;
  final String path;
  final String origin;

  factory LibrarySourceInfo.fromDto(frb.LibrarySourceDto dto) =>
      LibrarySourceInfo(
        id: dto.id,
        name: dto.name,
        path: dto.path,
        origin: dto.origin,
      );
}

/// One selectable value on a settings row.
class SettingsOptionData {
  const SettingsOptionData({required this.label, required this.value});

  final String label;
  final String value;

  factory SettingsOptionData.fromDto(frb.SettingsOptionDto dto) =>
      SettingsOptionData(label: dto.label, value: dto.value);
}

/// One editable row, as the backend describes it.
class SettingsRowData {
  const SettingsRowData({
    required this.key,
    required this.label,
    required this.note,
    required this.kind,
    required this.value,
    required this.options,
    required this.needsRestart,
    required this.enabled,
  });

  final String key;
  final String label;
  final String note;
  final String kind;
  final String value;
  final List<SettingsOptionData> options;
  final bool needsRestart;
  final bool enabled;

  SettingsRowData copyWith({String? value}) => SettingsRowData(
    key: key,
    label: label,
    note: note,
    kind: kind,
    value: value ?? this.value,
    options: options,
    needsRestart: needsRestart,
    enabled: enabled,
  );

  factory SettingsRowData.fromDto(frb.SettingsRowDto dto) => SettingsRowData(
    key: dto.key,
    label: dto.label,
    note: dto.note,
    kind: dto.kind,
    value: dto.value,
    options: dto.options.map(SettingsOptionData.fromDto).toList(growable: false),
    needsRestart: dto.needsRestart,
    enabled: dto.enabled,
  );
}

class SettingsSectionData {
  const SettingsSectionData({required this.title, required this.rows});

  final String title;
  final List<SettingsRowData> rows;

  factory SettingsSectionData.fromDto(frb.SettingsSectionDto dto) =>
      SettingsSectionData(
        title: dto.title,
        rows: dto.rows.map(SettingsRowData.fromDto).toList(growable: false),
      );
}

class SettingsPageData {
  const SettingsPageData({
    required this.id,
    required this.title,
    required this.sections,
  });

  final String id;
  final String title;
  final List<SettingsSectionData> sections;

  factory SettingsPageData.fromDto(frb.SettingsPageDto dto) => SettingsPageData(
    id: dto.id,
    title: dto.title,
    sections: dto.sections
        .map(SettingsSectionData.fromDto)
        .toList(growable: false),
  );

  SettingsPageData withValue(String key, String value) => SettingsPageData(
    id: id,
    title: title,
    sections: [
      for (final section in sections)
        SettingsSectionData(
          title: section.title,
          rows: [
            for (final row in section.rows)
              if (row.key == key) row.copyWith(value: value) else row,
          ],
        ),
    ],
  );
}

/// The preview/test copy of the pages. The engine replaces this with the profile's real values as
/// soon as it attaches; keeping a small copy here lets the web sketch open every page.
List<SettingsPageData> defaultSettingsPages() => [
  SettingsPageData(
    id: 'mixer',
    title: 'Mixer',
    sections: [
      _section('Crossfader', [
        _choice('crossfader_curve', 'Curve', 'classic', [
          ('Classic', 'classic'),
          ('Constant Power', 'constant_power'),
          ('Cut', 'cut'),
        ]),
        _choice('cue_blend', 'Cue Blend', 'cue', [
          ('Cue', 'cue'),
          ('Both', 'both'),
          ('Master', 'master'),
        ]),
        _choice('cue_cut_width', 'Cut Width', '0.05', [
          ('0.02', '0.02'),
          ('0.05', '0.05'),
          ('0.10', '0.1'),
        ]),
      ]),
      _section('Fader', [
        _choice('fader_position', 'Cue Tap', 'pre', [
          ('Pre', 'pre'),
          ('Post', 'post'),
        ]),
      ]),
      _section('Auto Gain', [
        _toggle('autogain', 'Auto Gain', false),
        _choice('autogain_target_db', 'Target', '-12', [
          ('-18 dB', '-18'),
          ('-15 dB', '-15'),
          ('-12 dB', '-12'),
          ('-9 dB', '-9'),
          ('-6 dB', '-6'),
        ]),
      ]),
      _section('Limiter', [
        _toggle('limiter', 'Limiter', true),
        _choice('limiter_ceiling_db', 'Ceiling', '-1', [
          ('-3 dB', '-3'),
          ('-2 dB', '-2'),
          ('-1 dB', '-1'),
          ('0 dB', '0'),
        ]),
      ]),
      _section('EQ', [
        _choice('eq_lower_hz', 'Low / Mid', '250', [
          ('100 Hz', '100'),
          ('150 Hz', '150'),
          ('250 Hz', '250'),
          ('400 Hz', '400'),
        ]),
        _choice('eq_higher_hz', 'Mid / High', '2000', [
          ('1 kHz', '1000'),
          ('1.5 kHz', '1500'),
          ('2 kHz', '2000'),
          ('3 kHz', '3000'),
        ]),
      ]),
      _section('Filter', [
        _choice('filter', 'Kind', 'linear', [
          ('Linear', 'linear'),
          ('Moog', 'moog'),
        ]),
      ]),
    ],
  ),
  SettingsPageData(
    id: 'audio',
    title: 'Audio',
    sections: [
      _section('Playback', [
        _choice('sample_rate', 'Sample Rate', '44100', [
          ('44.1 kHz', '44100'),
          ('48 kHz', '48000'),
          ('96 kHz', '96000'),
        ], restart: true),
      ]),
      _section('Keylock', [
        _choice('keylock_block', 'Block', '2048', [
          ('1024', '1024'),
          ('2048', '2048'),
          ('4096', '4096'),
        ], restart: true),
      ]),
      _section('Stems', [
        _choice('stems_provider', 'Provider', 'cpu', [
          ('CPU', 'cpu'),
          ('CUDA', 'cuda'),
        ], restart: true),
      ]),
    ],
  ),
  SettingsPageData(
    id: 'analysis',
    title: 'Analysis',
    sections: [
      _section('Backends', [
        _choice('beats_backend', 'Beats', 'timestretch', [
          ('Stratum', 'stratum'),
          ('Time-stretch', 'timestretch'),
        ]),
        _choice('key_backend', 'Key', 'timestretch', [
          ('Stratum', 'stratum'),
          ('Time-stretch', 'timestretch'),
        ]),
      ]),
      _section('Behaviour', [
        _toggle('auto_analyse', 'Auto Analyse', false),
      ]),
      _section('Grid', [
        _choice('grid_offset_ms', 'Offset', '0', [
          ('-16 ms', '-16'),
          ('-8 ms', '-8'),
          ('0 ms', '0'),
          ('8 ms', '8'),
          ('16 ms', '16'),
        ]),
      ]),
    ],
  ),
  SettingsPageData(
    id: 'display',
    title: 'Display',
    sections: [
      _section('Keys', [
        _choice('key_format', 'Notation', 'camelot', [
          ('Camelot', 'camelot'),
          ('Classic', 'classic'),
        ]),
      ]),
      _section('Panel', [
        _toggle('follow', 'Follow Commands', true),
      ]),
    ],
  ),
];

SettingsSectionData _section(String title, List<SettingsRowData> rows) =>
    SettingsSectionData(title: title, rows: rows);

SettingsRowData _choice(
  String key,
  String label,
  String value,
  List<(String, String)> options, {
  bool restart = false,
}) => SettingsRowData(
  key: key,
  label: label,
  note: restart ? 'restart required' : '',
  kind: 'choice',
  value: value,
  options: [
    for (final option in options)
      SettingsOptionData(label: option.$1, value: option.$2),
  ],
  needsRestart: restart,
  enabled: true,
);

SettingsRowData _toggle(String key, String label, bool value) => SettingsRowData(
  key: key,
  label: label,
  note: '',
  kind: 'toggle',
  value: value ? 'on' : 'off',
  options: const [
    SettingsOptionData(label: 'Off', value: 'off'),
    SettingsOptionData(label: 'On', value: 'on'),
  ],
  needsRestart: false,
  enabled: true,
);

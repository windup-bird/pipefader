import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:pipefader_gui/bridge/engine.dart';
import 'package:pipefader_gui/bridge/generated/api.dart' as frb;
import 'package:pipefader_gui/model/menu.dart';

/// The logo menu's session-backed state.
///
/// With an engine it mirrors the profile through the bridge. Without one (the web preview and
/// widget tests) it keeps enough local state to exercise every page: one master destination,
/// no MIDI input, and the same default settings the built-in profile has.
class MenuState extends ChangeNotifier {
  MenuState({this.engine});

  final EngineClient? engine;

  bool _loaded = false;
  bool _loading = false;
  bool _busy = false;
  String? _error;

  String profile = 'config.toml';
  bool builtin = false;
  String midiPort = '';
  String midiMap = 'mapping.toml';

  List<OutputChannel> _outputs = <OutputChannel>[
    const OutputChannel(
      index: 0,
      name: 'Master 1',
      role: OutputRole.master,
      channels: (0, 1),
    ),
  ];

  OutputRole role = OutputRole.master;
  List<MidiPortInfo> ports = const <MidiPortInfo>[];
  List<MapFileInfo> maps = const <MapFileInfo>[
    MapFileInfo(path: 'mapping.toml', name: 'mapping.toml'),
  ];
  MenuSettings settings = const MenuSettings();

  bool refreshing = false;
  DateTime? refreshedAt;

  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;
  List<OutputChannel> get outputs => List.unmodifiable(_outputs);

  List<OutputChannel> outputsFor(OutputRole role) =>
      _outputs.where((channel) => channel.role == role).toList(growable: false);

  int get masterCount =>
      _outputs.where((channel) => channel.role == OutputRole.master).length;

  void selectRole(OutputRole value) {
    if (role == value) return;
    role = value;
    notifyListeners();
  }

  /// Loads the profile once. The menu opens immediately on the local defaults; the bridge answer
  /// replaces them when it arrives.
  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    _loading = true;
    notifyListeners();
    try {
      if (engine != null) {
        final dto = await engine!.menuState();
        _apply(dto);
        await _loadMidi();
      }
      _loaded = true;
      _error = null;
    } catch (err) {
      _error = '$err';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Re-probes destinations and MIDI ports. The UI's refresh glyph spins for this future.
  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    _error = null;
    notifyListeners();
    try {
      if (engine != null) {
        _apply(await engine!.outputRefresh());
        await _loadMidi();
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 320));
      }
      refreshedAt = DateTime.now();
    } catch (err) {
      _error = '$err';
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<void> addOutput(OutputRole role) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (engine != null) {
        _apply(await engine!.outputAdd(role.configName));
      } else {
        final next = _nextChannels();
        _outputs = <OutputChannel>[
          ..._outputs,
          OutputChannel(
            index: _outputs.length,
            name: _nextName(role),
            role: role,
            channels: next,
          ),
        ];
      }
      this.role = role;
    } catch (err) {
      _error = '$err';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> removeOutput(OutputChannel channel) async {
    if (_busy) return;
    if (channel.role == OutputRole.master && masterCount <= 1) {
      _error = 'The last master output cannot be removed';
      notifyListeners();
      return;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (engine != null) {
        _apply(await engine!.outputRemove(channel.index));
      } else {
        final remaining = _outputs
            .where((item) => item.index != channel.index)
            .toList(growable: false);
        _outputs = <OutputChannel>[
          for (var i = 0; i < remaining.length; i++)
            OutputChannel(
              index: i,
              name: remaining[i].name,
              role: remaining[i].role,
              device: remaining[i].device,
              channels: remaining[i].channels,
              gain: remaining[i].gain,
            ),
        ];
      }
    } catch (err) {
      _error = '$err';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Opens a different MIDI input. The bridge writes the port into the profile and reconnects the
  /// session; the local preview only remembers the name.
  Future<void> selectMidiPort(MidiPortInfo port) async {
    if (_busy || port.name == midiPort) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (engine != null) {
        _apply(await engine!.setMidiPort(port.name));
      } else {
        midiPort = port.name;
      }
    } catch (err) {
      _error = '$err';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Points the controller at another map. The bridge writes the profile and reconnects; the local
  /// preview only remembers the path.
  Future<void> selectMidiMap(MapFileInfo map) async {
    if (_busy || map.path == midiMap) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (engine != null) {
        _apply(await engine!.setMidiMap(map.path));
        await _loadMidi();
      } else {
        midiMap = map.path;
      }
    } catch (err) {
      _error = '$err';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _loadMidi() async {
    if (engine == null) return;
    ports = (await engine!.midiPorts())
        .map(MidiPortInfo.fromDto)
        .toList(growable: false);
    maps = (await engine!.midiMaps())
        .map(MapFileInfo.fromDto)
        .toList(growable: false);
  }

  /// Writes one settings row. Keys match the Rust `app::config::settings` API.
  Future<void> setSetting(String key, String value) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (engine != null) {
        _apply(await engine!.setSetting(key, value));
      } else {
        settings = switch (key) {
          'sample_rate' => settings.copyWith(
            sampleRate: int.tryParse(value) ?? settings.sampleRate,
          ),
          'crossfader_curve' => settings.copyWith(crossfaderCurve: value),
          'cue_blend' => settings.copyWith(
            cueBlend: switch (value) {
              'cue' => -1,
              'master' => 1,
              _ => 0,
            },
          ),
          'autogain' => settings.copyWith(autogain: value == 'on'),
          _ => settings,
        };
      }
    } catch (err) {
      _error = '$err';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _apply(frb.MenuStateDto dto) {
    profile = dto.profile;
    builtin = dto.builtin;
    midiPort = dto.midiPort;
    midiMap = dto.midiMap;
    settings = MenuSettings.fromDto(dto);
    // An engine profile with no destinations is a real (if silent) state; the local preview has
    // already supplied its one master before this point, so do not invent a row here.
    _outputs = dto.outputs.map(OutputChannel.fromDto).toList(growable: false);
  }

  String _nextName(OutputRole role) {
    var number = 1;
    while (_outputs.any(
      (channel) =>
          channel.role == role && channel.name == '${role.label} $number',
    )) {
      number += 1;
    }
    return '${role.label} $number';
  }

  (int, int) _nextChannels() {
    final used = <int>{};
    for (final channel in _outputs) {
      final pair = channel.channels;
      if (pair == null) continue;
      used
        ..add(pair.$1)
        ..add(pair.$2);
    }
    var left = 0;
    while (used.contains(left) || used.contains(left + 1)) {
      left += 2;
    }
    return (left, left + 1);
  }
}

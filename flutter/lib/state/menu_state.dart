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

  EngineClient? engine;

  /// Attaches the engine after the first frame. The menu then reloads its snapshot instead of
  /// keeping the local defaults it painted while the engine was still booting.
  void attach(EngineClient next) {
    if (engine != null) return;
    engine = next;
    _loaded = false;
    _error = null;
    notifyListeners();
  }

  bool _loaded = false;
  bool _loading = false;
  bool _busy = false;
  bool _restartRequired = false;
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
  List<frb.OutputDeviceDto> devices = const <frb.OutputDeviceDto>[];
  int deviceChoice =
      0; // 0 = the host default, otherwise devices[deviceChoice - 1].
  (int, int) addChannels = (0, 1);
  List<MidiPortInfo> ports = const <MidiPortInfo>[];
  List<MapFileInfo> maps = const <MapFileInfo>[
    MapFileInfo(path: 'mapping.toml', name: 'mapping.toml'),
  ];
  List<SettingsPageData> settingsPages = defaultSettingsPages();
  List<String> libraryFolders = const <String>[];
  List<LibrarySourceInfo> librarySources = const <LibrarySourceInfo>[];

  bool refreshing = false;
  DateTime? refreshedAt;

  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;

  SettingsPageData? settingsPage(String id) {
    for (final page in settingsPages) {
      if (page.id == id) return page;
    }
    return null;
  }

  /// Android does not reload output streams live (oboe can block the audio callback); the config is
  /// written and the output page asks for a restart.
  bool get restartRequired => _restartRequired;
  List<OutputChannel> get outputs => List.unmodifiable(_outputs);

  List<OutputChannel> outputsFor(OutputRole role) =>
      _outputs.where((channel) => channel.role == role).toList(growable: false);

  int get masterCount =>
      _outputs.where((channel) => channel.role == OutputRole.master).length;

  /// The stereo pairs offered for the selected device. `0,1` is always present so a host that
  /// reports no channel count still gets a usable default.
  List<(int, int)> get channelPairs {
    final channels = deviceChoice == 0 ? 2 : devices[deviceChoice - 1].channels;
    final count = channels < 2 ? 2 : (channels > 8 ? 8 : channels);
    return [for (var i = 0; i < count ~/ 2; i++) (i * 2, i * 2 + 1)];
  }

  String? get selectedDevice =>
      deviceChoice == 0 ? null : devices[deviceChoice - 1].name;

  void selectRole(OutputRole value) {
    if (role == value) return;
    role = value;
    notifyListeners();
  }

  void selectDevice(int choice) {
    if (deviceChoice == choice) return;
    deviceChoice = choice.clamp(0, devices.length);
    final pairs = channelPairs;
    addChannels = pairs.first;
    notifyListeners();
  }

  void selectChannels((int, int) pair) {
    if (addChannels == pair) return;
    addChannels = pair;
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
        await _loadDevices();
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

  /// Re-reads the profile without re-probing devices. Pages that can change the same config from
  /// another place (the browser's Add folder writes the library section) call this when they open.
  Future<void> reloadProfile() async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (engine != null) {
        _apply(await engine!.menuState());
        await _loadDevices();
        await _loadMidi();
      }
      _loaded = true;
    } catch (err) {
      _error = '$err';
    } finally {
      _busy = false;
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
        await _loadDevices();
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
        _apply(
          await engine!.outputAdd(
            role.configName,
            device: selectedDevice,
            channels: [addChannels.$1, addChannels.$2],
          ),
        );
      } else {
        _outputs = <OutputChannel>[
          ..._outputs,
          OutputChannel(
            index: _outputs.length,
            name: _nextName(role),
            role: role,
            device: selectedDevice ?? '',
            channels: addChannels,
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

  /// Clears the controller's device so no input is attached. The map is kept: picking another
  /// controller should not make the user choose the map again.
  Future<void> disableController() async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (engine != null) {
        _apply(await engine!.disableController());
      } else {
        midiPort = '';
      }
    } catch (err) {
      _error = '$err';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Installs a map file chosen from the host's file dialog. The bridge validates the bytes and
  /// copies them beside the profile; the local preview only remembers the name.
  Future<bool> importMidiMap(String name, Uint8List bytes) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (engine != null) {
        _apply(await engine!.importMidiMap(name, bytes));
        await _loadMidi();
      } else {
        final map = MapFileInfo(path: name, name: name);
        maps = [
          for (final entry in maps)
            if (entry.path != map.path) entry,
          map,
        ];
        midiMap = map.path;
      }
      return true;
    } catch (err) {
      _error = '$err';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _loadDevices() async {
    if (engine == null) return;
    devices = await engine!.outputDevices();
    if (deviceChoice > devices.length) {
      deviceChoice = 0;
      addChannels = (0, 1);
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
        settingsPages = [
          for (final page in settingsPages) page.withValue(key, value),
        ];
      }
    } catch (err) {
      _error = '$err';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> addLibraryFolder(String path) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (engine != null) {
        _apply(await engine!.libraryAddFolder(path));
      } else if (!libraryFolders.contains(path)) {
        libraryFolders = [...libraryFolders, path];
      }
    } catch (err) {
      _error = '$err';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> removeLibraryFolder(String path) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (engine != null) {
        _apply(await engine!.libraryRemoveFolder(path));
      } else {
        libraryFolders = [
          for (final folder in libraryFolders)
            if (folder != path) folder,
        ];
      }
    } catch (err) {
      _error = '$err';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> rescanLibrary() async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (engine != null) {
        _apply(await engine!.libraryRescan());
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
    settingsPages = dto.settings
        .map(SettingsPageData.fromDto)
        .toList(growable: false);
    // An engine profile with no destinations is a real (if silent) state; the local preview has
    // already supplied its one master before this point, so do not invent a row here.
    _outputs = dto.outputs.map(OutputChannel.fromDto).toList(growable: false);
    _restartRequired = dto.restartRequired;
    libraryFolders = List<String>.of(dto.library_.folders);
    librarySources = dto.library_.sources
        .map(LibrarySourceInfo.fromDto)
        .toList(growable: false);
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
}

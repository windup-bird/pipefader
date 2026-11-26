import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pipefader_gui/bridge/generated/api.dart' as frb;
import 'package:pipefader_gui/bridge/generated/frb_generated.dart';

/// Thin Dart facade over the generated bridge. Everything here is async because
/// FRB runs the Rust call on its own worker thread; the UI never blocks on it.
class EngineClient {
  EngineClient._();

  final StreamController<frb.SessionEvent> _events =
      StreamController<frb.SessionEvent>.broadcast();
  StreamSubscription<frb.SessionEvent>? _subscription;
  bool _disposed = false;

  Stream<frb.SessionEvent> get events => _events.stream;

  /// The generated bridge may only be initialized once, and boot races the
  /// engine start against the error logger and the Android volume channel. Every
  /// entry point awaits this one future instead of calling `init` directly.
  static Future<void>? _bridgeReady;

  static Future<void> ensureBridge() {
    final ready = _bridgeReady;
    if (ready != null) return ready;
    final pending = _initBridge();
    _bridgeReady = pending;
    return pending;
  }

  static Future<void> _initBridge() async {
    try {
      await PipefaderBridge.init();
    } catch (_) {
      _bridgeReady = null;
      rethrow;
    }
  }

  /// Boots the Rust engine and starts listening. Idempotent in Rust, so a
  /// Flutter hot restart reuses the live session instead of opening the sound
  /// card twice.
  static Future<EngineClient> start({frb.SessionPathsDto? paths}) async {
    await ensureBridge();
    await frb.start(paths: paths);
    final client = EngineClient._();
    client._subscription = frb.subscribe().listen(
      client._events.add,
      onError: client._events.addError,
      onDone: client._events.close,
    );
    return client;
  }

  /// Appends Flutter-side failures to the bridge log. Best effort: if the native library never
  /// loaded there is nowhere to write, so the caller still gets the debug print.
  static Future<void> logClientError(String text) async {
    try {
      await ensureBridge();
      await frb.logClientError(text: text);
    } catch (error) {
      debugPrint('Pipefader could not log: $error\n$text');
    }
  }

  /// The in-app log reader; works even when the engine never attached.
  static Future<List<String>> recentLogs({int limit = 400}) async {
    await ensureBridge();
    return frb.recentLogs(limit: limit);
  }

  Future<void> shutdown() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    await frb.shutdown();
    await _events.close();
  }

  // ---- transport ---------------------------------------------------------

  Future<void> transport(int deck, frb.TransportAction action) =>
      frb.transport(deck: deck, action: action);

  Future<void> cue(int deck, frb.CueAction action) =>
      frb.cue(deck: deck, action: action);

  Future<void> hotCue(int deck, int slot, frb.HotCueAction action) =>
      frb.hotCue(deck: deck, slot: slot, action: action);

  Future<void> vinyl(int deck, frb.VinylAction action) =>
      frb.vinyl(deck: deck, action: action);

  Future<void> seek(int deck, int frame) =>
      frb.seek(deck: deck, frame: BigInt.from(frame));

  Future<void> beatJump(int deck, int beats) =>
      frb.beatJump(deck: deck, beats: beats);

  Future<void> jumpStep(int deck, int direction) =>
      frb.jumpStep(deck: deck, direction: direction);

  Future<void> scaleJump(int deck, bool halve) =>
      frb.scaleJump(deck: deck, halve: halve);

  Future<void> setTempo(int deck, double tempo) =>
      frb.setTempo(deck: deck, tempo: tempo);

  Future<void> setTempoFader(int deck, double position) =>
      frb.setTempoFader(deck: deck, position: position);

  Future<void> setTempoRange(int deck, double range) =>
      frb.setTempoRange(deck: deck, range: range);

  Future<void> sync(int deck, frb.SyncAction action) =>
      frb.sync_(deck: deck, action: action);

  Future<void> nudge(int deck, frb.NudgeAction action) =>
      frb.nudge(deck: deck, action: action);

  Future<void> bend(int deck, double delta) =>
      frb.bend(deck: deck, delta: delta);

  Future<void> setKeylock(int deck, bool on) =>
      frb.setKeylock(deck: deck, on_: on);

  Future<void> loop(int deck, frb.LoopAction action) =>
      frb.loopAction(deck: deck, action: action);

  Future<void> loopBeats(int deck, int num, int den) =>
      frb.loopBeats(deck: deck, num: num, den: den);

  Future<void> setLevel(frb.LevelKind kind, double value, {int deck = 0}) =>
      frb.setLevel(
        target: frb.LevelTarget(kind: kind, deck: deck, stem: 0),
        value: value,
      );

  Future<void> setCrossfader(double value) => frb.setCrossfader(value: value);

  Future<void> setEq(int deck, frb.EqBand band, double value) =>
      frb.setEq(deck: deck, band: band, value: value);

  Future<void> fx(
    int deck,
    int slot,
    frb.FxOp op, {
    int param = 0,
    double value = 0.0,
  }) => frb.fx(deck: deck, slot: slot, op: op, param: param, value: value);

  Future<void> fxAdd(int deck, String kind) =>
      frb.fxAdd(deck: deck, kind: kind);

  // ---- loading and library ----------------------------------------------

  Future<void> loadTrack(int deck, int locationId) =>
      frb.loadTrack(deck: deck, locationId: locationId);

  Future<void> loadPath(int deck, String path, {double? bpm}) =>
      frb.loadPath(deck: deck, path: path, bpm: bpm);

  Future<void> analyseTrack(int locationId) =>
      frb.analyseTrack(locationId: locationId);

  Future<void> analyseList(int playlistId) =>
      frb.analyseList(playlistId: playlistId);

  Future<List<frb.LibraryRoot>> libraryRoots() => frb.libraryRoots();

  Future<List<frb.LibraryList>> libraryLists(int sourceId) =>
      frb.libraryLists(sourceId: sourceId);

  Future<List<frb.TrackDto>> libraryTracks(int playlistId) =>
      frb.libraryTracks(playlistId: playlistId);

  Future<List<frb.TrackDto>> librarySearch(String query, {int limit = 200}) =>
      frb.librarySearch(query: query, limit: limit);

  Future<void> setWaveView(double width, double framesPerPixel) =>
      frb.setWaveView(width: width, framesPerPixel: framesPerPixel);

  Future<frb.WaveformData?> waveform(int deck) => frb.waveform(deck: deck);

  Future<frb.WaveStrip?> waveformStrip(
    int deck,
    double centerFrame,
    double framesPerPixel,
    int columns,
  ) => frb.waveformStrip(
    deck: deck,
    centerFrame: BigInt.from(centerFrame.round()),
    framesPerPixel: framesPerPixel,
    columns: columns,
  );

  Future<frb.WavePaletteDto> wavePalette() => frb.wavePalette();

  Future<frb.CoverData?> cover(int deck) => frb.cover(deck: deck);

  Future<frb.DeckMeta?> deckMeta(int deck) => frb.deckMeta(deck: deck);

  // ---- logo menu -----------------------------------------------------------

  Future<frb.MenuStateDto> menuState() => frb.menuState();

  Future<frb.MenuStateDto> outputAdd(
    String role, {
    String? device,
    List<int>? channels,
  }) => frb.outputAdd(
    role: role,
    device: device,
    channels: channels == null ? null : Uint16List.fromList(channels),
  );

  Future<List<frb.OutputDeviceDto>> outputDevices() => frb.outputDevices();

  Future<frb.MenuStateDto> outputBind(
    int index, {
    String? device,
    List<int>? channels,
  }) => frb.outputBind(
    index: index,
    device: device,
    channels: channels == null ? null : Uint16List.fromList(channels),
  );

  Future<frb.MenuStateDto> outputRemove(int index) =>
      frb.outputRemove(index: index);

  Future<frb.MenuStateDto> outputRefresh() => frb.outputRefresh();

  Future<List<frb.MidiPortDto>> midiPorts() => frb.midiPorts();

  Future<frb.MenuStateDto> setMidiPort(String port) =>
      frb.setMidiPort(port: port);

  Future<List<frb.MapFileDto>> midiMaps() => frb.midiMaps();

  Future<frb.MenuStateDto> setMidiMap(String path) =>
      frb.setMidiMap(mapPath: path);

  Future<frb.MenuStateDto> disableController() => frb.disableController();

  Future<frb.MenuStateDto> importMidiMap(String name, Uint8List bytes) =>
      frb.importMidiMap(name: name, bytes: bytes);

  Future<frb.MenuStateDto> setSetting(String key, String value) =>
      frb.setSetting(key: key, value: value);

  Future<frb.MenuStateDto> libraryAddFolder(String path) =>
      frb.libraryAddFolder(path: path);

  Future<frb.MenuStateDto> libraryRemoveFolder(String path) =>
      frb.libraryRemoveFolder(path: path);

  Future<frb.MenuStateDto> libraryRescan() => frb.libraryRescan();
}

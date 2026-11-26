import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:pipefader_gui/bridge/engine.dart';
import 'package:pipefader_gui/bridge/generated/api.dart' as frb;

const MethodChannel _sessionChannel = MethodChannel('pipefader/session');

/// Mounts that arrived before the engine attached (or before the host channel was ready). Replayed
/// by [flushVolumeEvents] once the session exists.
final List<(String, String)> _pending = <(String, String)>[];

/// Android reports removable volumes over `pipefader/session`; the desktop watcher is unchanged.
void installVolumeEvents() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  _sessionChannel.setMethodCallHandler(_handleVolumeCall);
}

Future<Object?> _handleVolumeCall(MethodCall call) async {
  final path = call.arguments;
  if (path is! String || path.isEmpty) return null;
  await _send(call.method, path);
  return null;
}

Future<void> _send(String method, String path) async {
  try {
    await EngineClient.ensureBridge();
    switch (method) {
      case 'volumeMounted':
        await frb.volumeMounted(root: path);
      case 'volumeUnmounted':
        await frb.volumeUnmounted(root: path);
    }
  } catch (error) {
    _pending.add((method, path));
    debugPrint('Pipefader volume event queued: $error');
  }
}

/// Asks the host for volumes that were already attached before the engine existed. The Kotlin
/// callback only reports changes, and its first events race Dart's handler registration.
Future<void> syncExistingVolumes() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final paths =
        await _sessionChannel.invokeListMethod<String>('listVolumes') ??
        const <String>[];
    for (final path in paths) {
      await _send('volumeMounted', path);
    }
  } catch (error) {
    debugPrint('Pipefader could not list mounted volumes: $error');
  }
}

/// Replays events that could not reach the session yet. Safe to call more than once.
Future<void> flushVolumeEvents() async {
  if (_pending.isEmpty) return;
  final events = List<(String, String)>.of(_pending);
  _pending.clear();
  for (final (method, path) in events) {
    await _send(method, path);
  }
}

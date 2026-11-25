import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One file the host's picker returned. The bytes are read by the host so the same flow works on
/// Android (SAF has no path) and on the desktop (GTK may point at a remote volume).
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

const MethodChannel _fileChannel = MethodChannel('pipefader/file');

/// Opens the host's file chooser filtered to controller maps. Returns null when the platform has
/// no chooser (the web preview) or the user cancels.
Future<PickedFile?> pickMapFile() => _pick('pickMapFile');

/// Opens the host's folder chooser. Returns a filesystem path, or null when the user cancels.
Future<String?> pickDirectory() async {
  if (kIsWeb) return null;
  try {
    return await _fileChannel.invokeMethod<String>('pickDirectory');
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

Future<PickedFile?> _pick(String method) async {
  if (kIsWeb) return null;
  try {
    final result = await _fileChannel.invokeMapMethod<String, Object?>(
      method,
    );
    if (result == null) return null;
    final name = result['name'] as String?;
    final bytes = result['bytes'];
    if (name == null || bytes is! Uint8List) return null;
    return PickedFile(name: name, bytes: bytes);
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

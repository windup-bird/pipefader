import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _sessionChannel = MethodChannel('pipefader/session');

/// Whether the app can walk `/storage/emulated/0` and USB volumes. Non-Android hosts do not need
/// the grant; the channel is only present on Android.
Future<bool> hasStoragePermission() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return true;
  }
  try {
    return await _sessionChannel.invokeMethod<bool>('hasStoragePermission') ??
        false;
  } catch (error) {
    debugPrint('Pipefader storage permission check failed: $error');
    return true;
  }
}

/// Opens the system screen (Android 11+) or the runtime permission dialog (Android 10). The caller
/// re-checks on resume; a denial simply leaves the prompt in place.
Future<void> requestStoragePermission() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _sessionChannel.invokeMethod<void>('requestStoragePermission');
  } catch (error) {
    debugPrint('Pipefader storage permission request failed: $error');
  }
}

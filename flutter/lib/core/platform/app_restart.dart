import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _sessionChannel = MethodChannel('pipefader/session');

/// Asks the host to restart the app after a setting that needs a new process. Android is the only
/// target that needs it today; elsewhere the settings apply live and this is a no-op.
Future<bool> restartApp() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    await _sessionChannel.invokeMethod<void>('restartApp');
    return true;
  } catch (_) {
    return false;
  }
}

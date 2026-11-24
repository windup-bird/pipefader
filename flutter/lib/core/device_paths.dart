import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:pipefader_gui/bridge/generated/api.dart' as frb;

/// The platform channel the Android host uses to hand over its private directories. Every other
/// platform returns null and lets the Rust session keep its `HOME`/XDG rules.
const MethodChannel _sessionChannel = MethodChannel('pipefader/session');

Future<frb.SessionPathsDto?> deviceSessionPaths() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return null;
  }
  try {
    final map = await _sessionChannel.invokeMapMethod<String, Object?>(
      'sessionPaths',
    );
    if (map == null) return null;
    return frb.SessionPathsDto(
      config: map['config'] as String?,
      cache: map['cache'] as String?,
      mediaHome: map['mediaHome'] as String?,
      log: map['log'] as String?,
      seed: map['seed'] as bool? ?? false,
    );
  } catch (error, stack) {
    debugPrint('Pipefader session paths unavailable: $error\n$stack');
    return null;
  }
}

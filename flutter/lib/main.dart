import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show FlutterError, debugPrint, kIsWeb;
import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/bridge/engine.dart';
import 'package:pipefader_gui/core/device_paths.dart';
import 'package:pipefader_gui/core/storage_permission.dart';
import 'package:pipefader_gui/core/volume_events.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/app_shell.dart';
import 'package:pipefader_gui/state/app_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();
  installVolumeEvents();
  final model = AppModel();
  if (!kIsWeb) {
    model.beginEngineStart();
  }
  runApp(PipefaderApp(model: model));
  if (!kIsWeb) {
    unawaited(_bootEngine(model));
  }
}

/// Boots the engine after the first frame. The shell shows the local sketch until the attach;
/// a failure marks the model offline instead of leaving a blank startup.
Future<void> _bootEngine(AppModel model) async {
  try {
    model.setStorageGranted(await hasStoragePermission());
    final paths = await deviceSessionPaths();
    final engine = await EngineClient.start(paths: paths);
    model.attachEngine(engine);
    if (model.storageGranted) {
      await syncExistingVolumes();
      await flushVolumeEvents();
    }
  } catch (error, stack) {
    debugPrint('Pipefader engine failed to start: $error\n$stack');
    model.markEngineFailed('$error');
    unawaited(
      EngineClient.logClientError('engine failed to start: $error\n$stack'),
    );
  }
}

/// Flutter failures before or after boot belong in the same file as the Rust boot steps.
void _installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      EngineClient.logClientError(
        'flutter: ${details.exceptionAsString()}\n${details.stack ?? ''}',
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Pipefader uncaught: $error\n$stack');
    unawaited(EngineClient.logClientError('uncaught: $error\n$stack'));
    return true;
  };
}

class PipefaderApp extends StatelessWidget {
  const PipefaderApp({this.model, super.key});

  final AppModel? model;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pipefader',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => DefaultTextStyle.merge(
        style: const TextStyle(fontSize: T.s13, height: 1.2, color: T.text),
        child: child!,
      ),
      home: Material(
        type: MaterialType.transparency,
        child: AppShell(model: model),
      ),
    );
  }
}

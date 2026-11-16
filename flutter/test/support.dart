import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pipefader_gui/layout/app_shell.dart';
import 'package:pipefader_gui/theme.dart';

/// Loads the SDK's Roboto into the test engine so goldens show real glyphs
/// instead of Ahem boxes. A machine without that path still runs, only boxed.
Future<void> loadTestFonts() async {
  const dir = '/home/windupbird/flutter/bin/cache/artifacts/material_fonts';
  if (!Directory(dir).existsSync()) return;
  final loader = FontLoader('Roboto');
  for (final name in const [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final file = File('$dir/$name');
    if (!file.existsSync()) continue;
    loader.addFont(
      file.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
    );
  }
  await loader.load();
}

/// The app under test, with a repaint boundary at the root so an overlay (the
/// unit menu) is part of the captured image too.
Widget buildTestApp({Key? boundaryKey}) {
  return RepaintBoundary(
    key: boundaryKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => DefaultTextStyle.merge(
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          height: 1.2,
          color: T.text,
        ),
        child: child!,
      ),
      home: const Material(
        type: MaterialType.transparency,
        child: AppShell(),
      ),
    ),
  );
}

Future<void> pumpAppAt(
  WidgetTester tester,
  Size size, {
  Key? boundaryKey,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(buildTestApp(boundaryKey: boundaryKey));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 400));
}

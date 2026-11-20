import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pipefader_gui/layout/app_shell.dart';
import 'package:pipefader_gui/layout/full_layout.dart';
import 'package:pipefader_gui/layout/landscape_layout.dart';
import 'package:pipefader_gui/layout/stacked_layout.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';

import 'support.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('auto layout follows the viewport', (tester) async {
    Future<void> pump(Size size) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Material(
            type: MaterialType.transparency,
            child: AppShell(model: AppModel(forcedLayout: null)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 32));
    }

    await pump(const Size(1024, 768));
    expect(find.byType(FullLayout), findsOneWidget);

    await pump(const Size(844, 390));
    expect(find.byType(LandscapeLayout), findsOneWidget);

    await pump(const Size(390, 844));
    expect(find.byType(StackedLayout), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pipefader_gui/core/layout_mode.dart';
import 'package:pipefader_gui/state/app_model.dart';

import 'support.dart';

/// Rendering smoke test: one representative frame per layout, written to
/// `test/goldens`. Run with `flutter test --update-goldens` to refresh them.
void main() {
  setUpAll(loadTestFonts);

  final cases = <(String, Size, LayoutMode, int, int)>[
    ('full2', const Size(1440, 900), LayoutMode.full, 2, 2),
    ('landscape2', const Size(844, 390), LayoutMode.landscape, 2, 2),
    ('stacked2', const Size(390, 844), LayoutMode.stacked, 2, 2),
    ('allinone2', const Size(1440, 900), LayoutMode.allInOne, 2, 2),
  ];

  for (final (name, size, mode, fullDecks, phoneDecks) in cases) {
    testWidgets('paints $name', (tester) async {
      final boundary = GlobalKey();
      final model = AppModel(
        forcedLayout: mode,
        fullDecks: fullDecks,
        phoneDecks: phoneDecks,
      );
      await pumpAppAt(tester, size, boundaryKey: boundary, model: model);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/$name.png'),
      );
    });
  }
}

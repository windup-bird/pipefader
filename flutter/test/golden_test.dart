import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pipefader_gui/layout/layout_mode.dart';
import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/widgets/cover.dart';
import 'package:pipefader_gui/widgets/logo.dart';

import 'support.dart';

/// Rendering smoke test: paints every face at the size it is meant for and
/// writes the frames to `test/goldens`. Run with
/// `flutter test --update-goldens` to refresh them.
void main() {
  setUpAll(loadTestFonts);

  final cases = <(String, Size, LayoutMode, int, int)>[
    ('full2', const Size(1440, 900), LayoutMode.full, 2, 2),
    ('full4', const Size(1600, 1000), LayoutMode.full, 4, 2),
    ('landscape2', const Size(844, 390), LayoutMode.landscape, 2, 2),
    ('landscape3', const Size(844, 390), LayoutMode.landscape, 2, 3),
    ('stacked2', const Size(390, 844), LayoutMode.stacked, 2, 2),
    ('stacked3', const Size(390, 844), LayoutMode.stacked, 2, 3),
    ('allinone2', const Size(1440, 900), LayoutMode.allInOne, 2, 2),
    ('allinone4', const Size(1600, 1000), LayoutMode.allInOne, 4, 2),
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

  testWidgets('paints the fx panel', (tester) async {
    final boundary = GlobalKey();
    final model = AppModel(forcedLayout: LayoutMode.full);
    model.decks[0].unitB = UnitKind.fx;
    model.decks[1].unitB = UnitKind.fx;
    await pumpAppAt(
      tester,
      const Size(1440, 900),
      boundaryKey: boundary,
      model: model,
    );
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/fx.png'),
    );
  });

  testWidgets('paints the phone mixer', (tester) async {
    final boundary = GlobalKey();
    final model = AppModel(forcedLayout: LayoutMode.stacked, phoneDecks: 2);
    model.decks[0].phoneUnit = UnitKind.mixerMax;
    model.decks[1].phoneUnit = UnitKind.mixerMax;
    await pumpAppAt(
      tester,
      const Size(390, 844),
      boundaryKey: boundary,
      model: model,
    );
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/mixer-max.png'),
    );
  });

  testWidgets('paints the header menu', (tester) async {
    final boundary = GlobalKey();
    await pumpAppAt(
      tester,
      const Size(1440, 900),
      boundaryKey: boundary,
      model: AppModel(forcedLayout: LayoutMode.full),
    );
    await tester.tap(find.byType(LogoMark).first);
    await tester.pump(const Duration(milliseconds: 120));
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/menu.png'),
    );
  });

  testWidgets('paints the phone browser', (tester) async {
    final boundary = GlobalKey();
    await pumpAppAt(
      tester,
      const Size(844, 390),
      boundaryKey: boundary,
      model: AppModel(forcedLayout: LayoutMode.landscape),
    );
    await tester.tap(find.byType(CoverArt).first);
    await tester.pump(const Duration(milliseconds: 120));
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/browser.png'),
    );
  });
}

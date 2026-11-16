import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('unit menu switches a slot to tempo', (tester) async {
    final boundary = GlobalKey();
    await pumpAppAt(tester, const Size(1440, 900), boundaryKey: boundary);

    await tester.tap(find.text('BEATCTL').first);
    await tester.pump(const Duration(milliseconds: 80));
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/unit-menu.png'),
    );

    await tester.tap(find.text('TEMPO'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('RANGE ±8% ·'), findsOneWidget);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/tempo.png'),
    );
  });

  testWidgets('library collapses and search filters the list', (tester) async {
    final boundary = GlobalKey();
    await pumpAppAt(tester, const Size(1440, 900), boundaryKey: boundary);

    expect(find.text('USB'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('library-toggle')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('USB'), findsNothing);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/browser-collapsed.png'),
    );

    await tester.tap(find.byKey(const ValueKey('search-toggle')));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.enterText(find.byType(TextField), 'iron');
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.textContaining('Iron Yard'), findsOneWidget);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/search.png'),
    );
  });

  testWidgets('transport toggles between play and pause', (tester) async {
    await pumpAppAt(tester, const Size(1440, 900));
    expect(find.text('PAUSE'), findsOneWidget);
    await tester.tap(find.text('PAUSE'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('PLAY'), findsNWidgets(2));
  });

  testWidgets('every unit panel renders', (tester) async {
    final boundary = GlobalKey();
    await pumpAppAt(tester, const Size(1440, 900), boundaryKey: boundary);

    Future<void> choose(String from, String to) async {
      await tester.tap(find.text(from).first);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text(to));
      await tester.pump(const Duration(milliseconds: 60));
    }

    await choose('BEATCTL', 'MIXER');
    await choose('BEATCTL', 'TEMPO');
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/units.png'),
    );

    await choose('MIXER', 'FX');
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/fx.png'),
    );
  });

  testWidgets('jump size menu opens from the jump key', (tester) async {
    final boundary = GlobalKey();
    await pumpAppAt(tester, const Size(1440, 900), boundaryKey: boundary);
    await tester.tap(find.text('16 jump').first);
    await tester.pump(const Duration(milliseconds: 80));
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/jump-menu.png'),
    );
  });
}

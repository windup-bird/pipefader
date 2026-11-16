import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

/// Rendering smoke test: paints the shell at the three widths the plan names
/// and writes the frames to `test/goldens`. Run with `flutter test
/// --update-goldens` to refresh them.
void main() {
  setUpAll(loadTestFonts);

  for (final (name, size) in <(String, Size)>[
    ('wide', const Size(1440, 900)),
    ('compact', const Size(1024, 768)),
    ('phone', const Size(390, 844)),
    ('landscape', const Size(844, 390)),
  ]) {
    testWidgets('paints $name', (tester) async {
      final boundary = GlobalKey();
      await pumpAppAt(tester, size, boundaryKey: boundary);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/$name.png'),
      );
    });
  }
}

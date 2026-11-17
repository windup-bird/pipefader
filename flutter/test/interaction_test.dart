import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pipefader_gui/layout/control_phone.dart';
import 'package:pipefader_gui/layout/deck_info.dart';
import 'package:pipefader_gui/layout/layout_mode.dart';
import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/units/panels.dart';
import 'package:pipefader_gui/layout/stacked_layout.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/widgets/cover.dart';
import 'package:pipefader_gui/widgets/logo.dart';

import 'support.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('logo menu switches layout', (tester) async {
    await pumpAppAt(tester, const Size(1440, 900));
    await tester.tap(find.byType(LogoMark).first);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('DECKS'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('layout-stacked')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(StackedLayout), findsOneWidget);
  });

  testWidgets('full deck count changes the info row', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.full);
    await pumpAppAt(tester, const Size(1600, 1000), model: model);
    expect(find.byType(DeckInfo), findsNWidgets(2));

    await tester.tap(find.byType(LogoMark).first);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const ValueKey('decks-4')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(DeckInfo), findsNWidgets(4));
  });

  testWidgets('unit menu switches a slot to mixer', (tester) async {
    await pumpAppAt(tester, const Size(1440, 900));
    await tester.tap(find.text('TEMPO').first);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('MIXER'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('HIGH'), findsOneWidget);
  });

  testWidgets('library collapses and search filters the list', (tester) async {
    await pumpAppAt(tester, const Size(1440, 900));
    expect(find.text('USB'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('library-toggle')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('USB'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('search-toggle')));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.enterText(find.byType(TextField), 'iron');
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.textContaining('Iron Yard'), findsOneWidget);
  });

  testWidgets('browser right column opens blank', (tester) async {
    await pumpAppAt(tester, const Size(1440, 900));
    expect(find.byKey(const ValueKey('browser-blank')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('right-toggle')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('browser-blank')), findsOneWidget);
  });

  testWidgets('cover raises the browser in landscape', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.landscape, phoneDecks: 2);
    await pumpAppAt(tester, const Size(844, 390), model: model);
    expect(find.text('BROWSER'), findsNothing);

    await tester.tap(find.byType(CoverArt).first);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('BROWSER'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('browser-close')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('BROWSER'), findsNothing);
  });

  testWidgets('transport toggles between play and pause', (tester) async {
    await pumpAppAt(tester, const Size(1440, 900));
    expect(find.text('PAUSE'), findsOneWidget);
    await tester.tap(find.text('PAUSE'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('PLAY'), findsNWidgets(2));
  });

  testWidgets('phone tempo drag raises the bpm', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.stacked, phoneDecks: 2);
    final before = model.decks[0].bpm;
    await pumpAppAt(tester, const Size(390, 844), model: model);
    await tester.drag(find.byType(TempoTouch).first, const Offset(0, -24));
    await tester.pump(const Duration(milliseconds: 80));
    expect(model.decks[0].bpm, greaterThan(before));
  });

  testWidgets('fx parameter bar drags like a fader', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.full);
    model.decks[0].unitB = UnitKind.fx;
    final before = model.decks[0].fx1;
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    await tester.drag(find.byType(ParamBar).first, const Offset(24, 0));
    await tester.pump(const Duration(milliseconds: 80));
    expect(model.decks[0].fx1, greaterThan(before));
  });

  testWidgets('phone unit switches to the mixer', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.stacked, phoneDecks: 2);
    await pumpAppAt(tester, const Size(390, 844), model: model);
    await tester.tap(find.text('PADS').first);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('MIXER MAX'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(model.decks[0].phoneUnit, UnitKind.mixerMax);
  });

  testWidgets('phone deck picker selects the third deck', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.stacked, phoneDecks: 3);
    await pumpAppAt(tester, const Size(390, 844), model: model);
    expect(find.byKey(const ValueKey('deck-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('deck-3')), findsOneWidget);
    expect(model.phoneSlotDeck(0), 0);

    await tester.tap(find.byKey(const ValueKey('deck-3')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(model.phoneSlotDeck(0), 2);
  });

  testWidgets('settings row opens a panel', (tester) async {
    await pumpAppAt(tester, const Size(1440, 900));
    await tester.tap(find.byType(LogoMark).first);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const ValueKey('menu-settings')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.textContaining('TEMPO RANGE'), findsOneWidget);
  });
}

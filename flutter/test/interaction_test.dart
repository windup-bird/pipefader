import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pipefader_gui/layout/deck_info.dart';
import 'package:pipefader_gui/layout/layout_mode.dart';
import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/units/panels.dart';
import 'package:pipefader_gui/layout/stacked_layout.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/theme.dart';
import 'package:pipefader_gui/widgets/buttons.dart';
import 'package:pipefader_gui/widgets/cover.dart';
import 'package:pipefader_gui/widgets/deck_picker.dart';
import 'package:pipefader_gui/layout/header.dart';
import 'package:pipefader_gui/widgets/tempo_control.dart';
import 'package:pipefader_gui/widgets/unit_header.dart';

import 'support.dart';

void main() {
  setUpAll(loadTestFonts);

  test('control scale clamps and grows with the band', () {
    const small = ControlScale(40);
    const base = ControlScale(128);
    const large = ControlScale(400);
    expect(small.font(T.s9), greaterThanOrEqualTo(T.s8));
    expect(large.font(T.s22), lessThanOrEqualTo(30.0));
    expect(large.size(24), greaterThan(base.size(24)));
    expect(base.size(24), greaterThan(small.size(24)));
  });

  testWidgets('logo menu switches layout', (tester) async {
    await pumpAppAt(tester, const Size(1440, 900));
    await tester.tap(find.byType(LogoButton).first);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Decks'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('layout-stacked')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(StackedLayout), findsOneWidget);
  });

  testWidgets('full deck count changes the info row', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.full);
    await pumpAppAt(tester, const Size(1600, 1000), model: model);
    expect(find.byType(DeckInfo), findsNWidgets(2));

    await tester.tap(find.byType(LogoButton).first);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const ValueKey('decks-4')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(DeckInfo), findsNWidgets(4));
  });

  testWidgets('unit tab switches a slot to mixer', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.full);
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    await tester.tap(
      find.descendant(
        of: find.byType(UnitHeader).first,
        matching: find.text('MIXER'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(model.decks[0].unitA, UnitKind.mixer);
    expect(find.text('HIGH'), findsNWidgets(3));
  });

  testWidgets('unit gear toggles the tab set', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.full);
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    final header = find.byType(UnitHeader).first;
    expect(
      find.descendant(of: header, matching: find.text('TEMPO')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('unit-settings')).first);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const ValueKey('unit-option-tempo')));
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      find.descendant(of: header, matching: find.text('TEMPO')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('unit-option-tempo')), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('unit-option-tempo')), findsNothing);
  });

  testWidgets('desk picker, sync and unit name share one height', (
    tester,
  ) async {
    final model = AppModel(forcedLayout: LayoutMode.full, fullDecks: 4);
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    final header =
        tester.renderObject(find.byType(UnitHeader).first) as RenderBox;
    final sync = tester.renderObject(
      find
          .ancestor(of: find.text('Sync'), matching: find.byType(PanelButton))
          .first,
    ) as RenderBox;
    final picker =
        tester.renderObject(find.byType(DeckPicker).first) as RenderBox;
    expect(sync.size.height, closeTo(header.size.height, 0.5));
    expect(picker.size.height, closeTo(header.size.height, 0.5));

    final tab = tester.widget<Text>(
      find
          .descendant(
            of: find.byType(UnitHeader).first,
            matching: find.text('CUE'),
          )
          .first,
    );
    expect(tab.style?.fontSize, greaterThan(9));
  });

  testWidgets('phone picker, sync and unit name share one height', (
    tester,
  ) async {
    final model = AppModel(forcedLayout: LayoutMode.stacked, phoneDecks: 3);
    await pumpAppAt(tester, const Size(390, 844), model: model);
    final header =
        tester.renderObject(find.byType(UnitHeader).first) as RenderBox;
    final sync = tester.renderObject(
      find
          .ancestor(of: find.text('Sync'), matching: find.byType(PanelButton))
          .first,
    ) as RenderBox;
    final picker =
        tester.renderObject(find.byType(DeckPicker).first) as RenderBox;
    expect(sync.size.height, closeTo(header.size.height, 0.5));
    expect(picker.size.height, closeTo(header.size.height, 0.5));
  });

  testWidgets('pad unit changes the pad mode', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.full);
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    await tester.tap(
      find.descendant(
        of: find.byType(UnitHeader).first,
        matching: find.text('LOOP'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(model.decks[0].padMode, PadMode.loop);
  });

  testWidgets('removing the active unit selects the first tab', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.full);
    model.decks[0].unitA = UnitKind.tempo;
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    await tester.tap(find.byKey(const ValueKey('unit-settings')).first);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const ValueKey('unit-option-tempo')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(model.decks[0].unitA, UnitKind.padsCue);
    expect(model.decks[0].padMode, PadMode.cue);
  });

  testWidgets('all-in-one pad mode reaches the full unit tabs', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.allInOne);
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    await tester.tap(find.text('JUMP').first);
    await tester.pump(const Duration(milliseconds: 80));
    expect(model.decks[0].padMode, PadMode.jump);
    expect(model.decks[0].unitA, UnitKind.padsJump);
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
    expect(find.byKey(const ValueKey('browser-close')), findsNothing);

    await tester.tap(find.byType(CoverArt).first);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const ValueKey('browser-close')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('browser-close')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const ValueKey('browser-close')), findsNothing);
  });

  testWidgets('transport toggles play state', (tester) async {
    final model = AppModel();
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    expect(model.decks[0].playing, isTrue);
    // The two transport halves share deck state, so tapping the left play key
    // pauses deck one.
    await tester.tap(find.byKey(const ValueKey('play-0')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(model.decks[0].playing, isFalse);
  });

  testWidgets('deck info tempo drag raises the bpm', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.stacked, phoneDecks: 2);
    final before = model.decks[0].bpm;
    await pumpAppAt(tester, const Size(390, 844), model: model);
    await tester.drag(find.byType(TempoControl).first, const Offset(0, -24));
    await tester.pump(const Duration(milliseconds: 80));
    expect(model.decks[0].bpm, greaterThan(before));
    expect(find.byType(TempoRuler), findsNothing);
  });

  testWidgets('tap pins the tempo ruler', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.stacked, phoneDecks: 2);
    await pumpAppAt(tester, const Size(390, 844), model: model);
    expect(find.byType(TempoRuler), findsNothing);

    await tester.tap(find.byType(TempoControl).first);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(TempoRuler), findsOneWidget);

    await tester.tap(find.byType(TempoControl).first);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(TempoRuler), findsNothing);
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
    await tester.tap(
      find.descendant(
        of: find.byType(UnitHeader).first,
        matching: find.text('MIXER'),
      ),
    );
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
    await tester.tap(find.byType(LogoButton).first);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const ValueKey('menu-settings')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.textContaining('Tempo Range'), findsOneWidget);
  });
}

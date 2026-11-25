import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pipefader_gui/layout/deck_info.dart';
import 'package:pipefader_gui/core/layout_mode.dart';
import 'package:pipefader_gui/core/i18n.dart';
import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/controls/param_bar.dart';
import 'package:pipefader_gui/layout/stacked_layout.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/model/menu.dart';
import 'package:pipefader_gui/model/library.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/controls/cover.dart';
import 'package:pipefader_gui/units/deck_picker.dart';
import 'package:pipefader_gui/layout/header.dart';
import 'package:pipefader_gui/units/tempo_control.dart';
import 'package:pipefader_gui/units/unit_header.dart';

import 'support.dart';

void main() {
  setUpAll(loadTestFonts);

  /// The app runs a frame ticker, so `pumpAndSettle` never settles. Two fixed frames are enough
  /// for the menu's 220 ms open and 150 ms page switch to finish and drop their outgoing widgets.
  Future<void> settleMenu(WidgetTester tester, [int milliseconds = 320]) async {
    await tester.pump(Duration(milliseconds: milliseconds));
    await tester.pump(const Duration(milliseconds: 80));
  }

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
    await settleMenu(tester);
    expect(find.byKey(const ValueKey('decks-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('decks-4')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('layout-stacked')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(StackedLayout), findsOneWidget);
  });

  testWidgets('full deck count changes the info row', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.full);
    await pumpAppAt(tester, const Size(1600, 1000), model: model);
    expect(find.byType(DeckInfo), findsNWidgets(2));

    await tester.tap(find.byType(LogoButton).first);
    await settleMenu(tester);
    await tester.tap(find.byKey(const ValueKey('decks-4')));
    await settleMenu(tester);
    expect(find.byType(DeckInfo), findsNWidgets(4));
  });

  testWidgets('desk slots split pads and mixer units', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.full);
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    final first = find.byType(UnitHeader).first;
    final second = find.byType(UnitHeader).at(1);
    expect(
      find.descendant(of: first, matching: find.text('MIXER')),
      findsNothing,
    );
    expect(
      find.descendant(of: second, matching: find.text('TEMPO')),
      findsOneWidget,
    );

    await tester.tap(find.descendant(of: first, matching: find.text('LOOP')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(model.decks[0].unitA, UnitKind.padsLoop);
    expect(model.decks[0].padMode, PadMode.loop);

    await tester.tap(find.descendant(of: second, matching: find.text('TEMPO')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(model.decks[0].unitB, UnitKind.tempo);
  });

  testWidgets('unit gear toggles the tab set', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.full);
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    final header = find.byType(UnitHeader).at(1);
    expect(
      find.descendant(of: header, matching: find.text('TEMPO')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('unit-settings')).at(1));
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
    model.decks[0].unitB = UnitKind.tempo;
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    await tester.tap(find.byKey(const ValueKey('unit-settings')).at(1));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const ValueKey('unit-option-tempo')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(model.decks[0].unitB, UnitKind.mixer);
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

  testWidgets('browser starts empty and the library panel collapses', (
    tester,
  ) async {
    await pumpAppAt(tester, const Size(1440, 900));
    expect(find.text('0 tracks'), findsOneWidget);
    expect(find.byKey(const ValueKey('library-add')), findsOneWidget);
    expect(find.textContaining('Iron Yard'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('library-toggle')));
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.byKey(const ValueKey('library-pane')), findsNothing);
    expect(find.text('0 tracks'), findsOneWidget);
  });

  testWidgets('library add offers a folder and the settings page', (
    tester,
  ) async {
    await pumpAppAt(tester, const Size(1440, 900));
    await tester.tap(find.byKey(const ValueKey('library-add')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const ValueKey('source-folder')), findsOneWidget);
    expect(find.byKey(const ValueKey('source-usb')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('source-settings')));
    await settleMenu(tester);
    expect(find.text('Preferences'), findsOneWidget);
  });

  testWidgets('the list column renders a tree and toggles children', (
    tester,
  ) async {
    final model = AppModel();
    model.lists.addAll(const [
      ListEntry('Root', id: 1, sourceId: 1, hasChildren: true),
      ListEntry('Child', id: 2, sourceId: 1, parentId: 1),
      ListEntry('Leaf', id: 3, sourceId: 1, parentId: 1),
    ]);
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    expect(find.text('Root'), findsOneWidget);
    expect(find.text('Child'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('list-toggle-1')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Child'), findsOneWidget);
    expect(find.text('Leaf'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('list-2')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(model.selectedListId, 2);
  });

  testWidgets('storage prompt follows the grant state', (tester) async {
    final model = AppModel()..setStorageGranted(false);
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    expect(find.byKey(const ValueKey('storage-permission')), findsOneWidget);

    model.setStorageGranted(true);
    await tester.pump();
    expect(find.byKey(const ValueKey('storage-permission')), findsNothing);
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

  testWidgets('cover raises the browser in all-in-one', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.allInOne);
    await pumpAppAt(tester, const Size(1440, 900), model: model);
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
    expect(model.decks[0].playing, isFalse);
    // The two transport halves share deck state, so tapping the left play key
    // starts deck one.
    await tester.tap(find.byKey(const ValueKey('play-0')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(model.decks[0].playing, isTrue);
  });

  testWidgets('deck info tempo drag raises the rate', (tester) async {
    final model = AppModel(forcedLayout: LayoutMode.stacked, phoneDecks: 2);
    final before = model.decks[0].tempo;
    await pumpAppAt(tester, const Size(390, 844), model: model);
    await tester.drag(find.byType(TempoControl).first, const Offset(0, -24));
    await tester.pump(const Duration(milliseconds: 80));
    expect(model.decks[0].tempo, greaterThan(before));
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

  testWidgets('mixer page writes a setting', (tester) async {
    final model = AppModel();
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    await tester.tap(find.byType(LogoButton).first);
    await settleMenu(tester);
    await tester.tap(find.byKey(const ValueKey('menu-mixer')));
    await settleMenu(tester);
    expect(find.text('Mixer'), findsOneWidget);
    expect(find.text('Crossfader'), findsOneWidget);
    expect(find.text('Curve'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('setting-crossfader_curve-constant_power')),
    );
    await settleMenu(tester);
    final page = model.menu.settingsPage('mixer')!;
    final row = page.sections
        .expand((section) => section.rows)
        .firstWhere((row) => row.key == 'crossfader_curve');
    expect(row.value, 'constant_power');
  });

  testWidgets('preferences page writes the sample rate', (tester) async {
    final model = AppModel();
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    await tester.tap(find.byType(LogoButton).first);
    await settleMenu(tester);
    await tester.tap(find.byKey(const ValueKey('menu-preferences')));
    await settleMenu(tester);
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Sample Rate'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('setting-sample_rate-48000')));
    await settleMenu(tester);
    final page = model.menu.settingsPage('audio')!;
    final row = page.sections
        .expand((section) => section.rows)
        .firstWhere((row) => row.key == 'sample_rate');
    expect(row.value, '48000');
  });

  testWidgets('menu keeps its header while the body scrolls', (
    tester,
  ) async {
    final model = AppModel(forcedLayout: LayoutMode.landscape);
    await pumpAppAt(tester, const Size(844, 390), model: model);
    await tester.tap(find.byType(LogoButton).first);
    await settleMenu(tester);
    await tester.drag(
      find.byKey(const ValueKey('menu-root-scroll')),
      const Offset(0, -320),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byKey(const ValueKey('menu-preferences')));
    await settleMenu(tester);
    expect(find.text('Preferences'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('menu-page-scroll')),
      const Offset(0, -260),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Preferences'), findsOneWidget);
  });

  testWidgets('output adds and removes channels', (tester) async {
    await pumpAppAt(tester, const Size(1440, 900));
    await tester.tap(find.byType(LogoButton).first);
    await settleMenu(tester);
    await tester.tap(find.byKey(const ValueKey('menu-output')));
    await settleMenu(tester);
    expect(find.text('Output'), findsOneWidget);
    expect(find.text('Master 1'), findsOneWidget);

    await _addOutput(tester);
    expect(find.text('Master 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('output-remove-1')));
    await settleMenu(tester);
    expect(find.text('Master 2'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('output-role-precue')));
    await settleMenu(tester);
    expect(find.text('No Precue channels'), findsOneWidget);
    await _addOutput(tester);
    expect(find.text('Precue 1'), findsOneWidget);
  });

  testWidgets('the last output can be removed and added again', (tester) async {
    await pumpAppAt(tester, const Size(1440, 900));
    await tester.tap(find.byType(LogoButton).first);
    await settleMenu(tester);
    await tester.tap(find.byKey(const ValueKey('menu-output')));
    await settleMenu(tester);

    await tester.tap(find.byKey(const ValueKey('output-remove-0')));
    await settleMenu(tester);
    expect(find.text('No Master channels'), findsOneWidget);

    await _addOutput(tester);
    expect(find.text('Master 1'), findsOneWidget);
  });

  testWidgets('interface switches to Chinese through the scope', (tester) async {
    await pumpAppAt(
      tester,
      const Size(1440, 900),
      lang: AppLang.zh,
    );
    await tester.tap(find.byType(LogoButton).first);
    await settleMenu(tester);
    expect(find.text('控制器'), findsOneWidget);
    expect(find.text('混音'), findsOneWidget);
    expect(find.text('偏好'), findsOneWidget);
  });

  testWidgets('controller disable clears the active port', (tester) async {
    final model = AppModel();
    model.menu.ports = const [
      MidiPortInfo(index: 0, name: 'Test Controller'),
    ];
    model.menu.midiPort = 'Test Controller';
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    await tester.tap(find.byType(LogoButton).first);
    await settleMenu(tester);
    await tester.tap(find.byKey(const ValueKey('menu-controller')));
    await settleMenu(tester);
    await tester.tap(
      find.byKey(const ValueKey('controller-port-0:Test Controller')),
    );
    await settleMenu(tester);
    await tester.tap(find.byKey(const ValueKey('controller-disable')));
    await settleMenu(tester);
    expect(model.menu.midiPort, isEmpty);
    expect(find.byKey(const ValueKey('controller-disable')), findsNothing);
  });

  testWidgets('library settings add and remove a folder', (tester) async {
    final model = AppModel();
    model.menu.libraryFolders = const ['/music'];
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    await tester.tap(find.byType(LogoButton).first);
    await settleMenu(tester);
    await tester.tap(find.byKey(const ValueKey('menu-preferences')));
    await settleMenu(tester);
    await tester.tap(find.byKey(const ValueKey('preferences-library')));
    await settleMenu(tester);
    expect(find.text('/music'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('library-remove-/music')));
    await settleMenu(tester);
    expect(model.menu.libraryFolders, isEmpty);
  });

  testWidgets('controller list and detail share the refresh key', (tester) async {
    final model = AppModel();
    model.menu.ports = const [MidiPortInfo(index: 0, name: 'Test Controller')];
    await pumpAppAt(tester, const Size(1440, 900), model: model);
    await tester.tap(find.byType(LogoButton).first);
    await settleMenu(tester);
    await tester.tap(find.byKey(const ValueKey('menu-controller')));
    await settleMenu(tester);
    expect(find.text('Controller'), findsOneWidget);
    expect(find.text('No MIDI input ports found'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('controller-port-0:Test Controller')),
    );
    await settleMenu(tester);
    expect(find.byKey(const ValueKey('controller-disable')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('controller-choose-map')),
      findsOneWidget,
    );
  });
}

Future<void> _addOutput(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('output-add')));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.byKey(const ValueKey('output-device-0')));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.byKey(const ValueKey('output-confirm')));
  await tester.pump(const Duration(milliseconds: 200));
}

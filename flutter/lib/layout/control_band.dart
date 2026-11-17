import 'package:material_ui/material_ui.dart';

import '../model/deck.dart';
import '../state/app_model.dart';
import '../theme.dart';
import '../units/panels.dart';
import '../units/unit_body.dart';
import '../widgets/bar_fader.dart';
import '../widgets/buttons.dart';
import '../widgets/deck_picker.dart';
import '../widgets/fader.dart';
import '../widgets/glyph.dart';
import '../widgets/meter.dart';
import '../widgets/unit_menu.dart';

const double _transportWidth = 54;
const double _centreWidth = 128;
const double _unitNameHeight = 16;
const double _deckKeySize = 30;

/// The units a full control slot can become.
const List<UnitKind> deskUnits = <UnitKind>[
  UnitKind.pads,
  UnitKind.tempo,
  UnitKind.mixer,
  UnitKind.fx,
];

/// The band under the waveforms: transport | unit | unit | fader, mirrored on
/// the right. Each half drives one deck; the picker above the transport shows
/// one key per deck in that half.
class ControlBand extends StatelessWidget {
  const ControlBand({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final first = model.decks[model.fullSlotDeck(0)];
    final second = model.decks[model.fullSlotDeck(1)];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Transport(model: model, deck: first, column: 0),
        const SizedBox(width: 8),
        Expanded(
          child: _UnitSlot(
            model: model,
            deck: first,
            kind: first.unitA,
            onSelect: (kind) => model.setUnitA(first, kind),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _UnitSlot(
            model: model,
            deck: first,
            kind: first.unitB,
            onSelect: (kind) => model.setUnitB(first, kind),
          ),
        ),
        const SizedBox(width: 10),
        _Centre(model: model),
        const SizedBox(width: 10),
        Expanded(
          child: _UnitSlot(
            model: model,
            deck: second,
            kind: second.unitB,
            onSelect: (kind) => model.setUnitB(second, kind),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _UnitSlot(
            model: model,
            deck: second,
            kind: second.unitA,
            onSelect: (kind) => model.setUnitA(second, kind),
          ),
        ),
        const SizedBox(width: 8),
        _Transport(model: model, deck: second, column: 1),
      ],
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({
    required this.model,
    required this.deck,
    required this.column,
  });

  final AppModel model;
  final DeckRuntime deck;
  final int column;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _transportWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (model.fullHasDeckChoice) ...[
            DeckPicker(model: model, column: column, expand: true),
            const SizedBox(height: 4),
          ],
          SizedBox(
            height: 20,
            child: PanelButton(
              label: 'sync',
              active: deck.sync,
              style: Ty.button.copyWith(fontSize: T.s9),
              onTap: () => model.toggleSync(deck),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: PanelButton(
              label: 'cue',
              style: Ty.button.copyWith(fontSize: T.s12),
              onTap: () => model.cue(deck),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PanelButton(
              label: deck.playing ? 'pause' : 'play',
              active: deck.playing,
              style: Ty.button.copyWith(fontSize: T.s12),
              onTap: () => model.togglePlay(deck),
            ),
          ),
        ],
      ),
    );
  }
}

/// One switchable slot: the panel, then its name underneath. The name is the
/// picker, unlike the TUI where the name sits above.
class _UnitSlot extends StatefulWidget {
  const _UnitSlot({
    required this.model,
    required this.deck,
    required this.kind,
    required this.onSelect,
  });

  final AppModel model;
  final DeckRuntime deck;
  final UnitKind kind;
  final ValueChanged<UnitKind> onSelect;

  @override
  State<_UnitSlot> createState() => _UnitSlotState();
}

class _UnitSlotState extends State<_UnitSlot> {
  final _anchor = GlobalKey();
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: buildUnit(
            kind: widget.kind,
            model: widget.model,
            deck: widget.deck,
          ),
        ),
        SizedBox(
          height: _unitNameHeight,
          child: Center(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: GestureDetector(
                key: _anchor,
                behavior: HitTestBehavior.opaque,
                onTap: () => showChoiceMenu(
                  context: context,
                  anchorKey: _anchor,
                  labels: deskUnits.map((kind) => kind.label).toList(),
                  current: deskUnits.indexOf(widget.kind),
                  onSelect: (index) => widget.onSelect(deskUnits[index]),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.kind.label.toUpperCase(),
                        style: Ty.labelSmall.copyWith(
                          color: _hover ? T.accentHi : T.accent,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Glyph(
                        GlyphKind.dropdown,
                        size: 7,
                        color: _hover ? T.accentHi : T.faint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Centre extends StatelessWidget {
  const _Centre({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final first = model.decks[model.fullSlotDeck(0)];
    final second = model.decks[model.fullSlotDeck(1)];
    return SizedBox(
      width: _centreWidth,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: BarFader(
                    value: first.fader,
                    onChanged: (value) => model.setFader(first, value),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 8,
                  child: ValueListenableBuilder<int>(
                    valueListenable: model.clock,
                    builder: (context, _, _) =>
                        LevelMeter(level: first.meter, peak: first.meterPeak),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BarFader(
                    value: second.fader,
                    onChanged: (value) => model.setFader(second, value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Crossfader(value: model.crossfader, onChanged: model.setCrossfader),
        ],
      ),
    );
  }
}

/// The all-in-one band: pad and FX panels only, one pair per control column,
/// no transport and no faders. It is a hint that the surface still has
/// controls, not a full mixer.
class AllInOneControlBand extends StatelessWidget {
  const AllInOneControlBand({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final first = model.decks[model.fullSlotDeck(0)];
    final second = model.decks[model.fullSlotDeck(1)];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _AllInOneSide(model: model, deck: first, column: 0),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AllInOneSide(model: model, deck: second, column: 1),
        ),
      ],
    );
  }
}

/// One half of the all-in-one hint: pads and FX, with the deck picker on the
/// outside edge, vertically centred and stacked.
class _AllInOneSide extends StatelessWidget {
  const _AllInOneSide({
    required this.model,
    required this.deck,
    required this.column,
  });

  final AppModel model;
  final DeckRuntime deck;
  final int column;

  @override
  Widget build(BuildContext context) {
    final pickerLeft = column == 0;
    final picker = SizedBox(
      width: _deckKeySize,
      child: Center(
        child: DeckPicker(
          model: model,
          column: column,
          vertical: true,
          buttonWidth: _deckKeySize,
          buttonHeight: _deckKeySize,
        ),
      ),
    );
    final body = Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: column == 0
            ? [
                Expanded(
                  flex: 3,
                  child: PadsPanel(model: model, deck: deck),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FxPanel(model: model, deck: deck),
                ),
              ]
            : [
                Expanded(
                  flex: 2,
                  child: FxPanel(model: model, deck: deck),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: PadsPanel(model: model, deck: deck),
                ),
              ],
      ),
    );
    final showPicker = model.fullHasDeckChoice;
    final children = <Widget>[];
    if (showPicker && pickerLeft) {
      children
        ..add(picker)
        ..add(const SizedBox(width: 8));
    }
    children.add(body);
    if (showPicker && !pickerLeft) {
      children
        ..add(const SizedBox(width: 8))
        ..add(picker);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

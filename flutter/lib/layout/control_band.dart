import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/bar_fader.dart';
import 'package:pipefader_gui/controls/fader.dart';
import 'package:pipefader_gui/controls/meter.dart';
import 'package:pipefader_gui/core/layout_metrics.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/core/theme_scope.dart';
import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/units/deck_picker.dart';
import 'package:pipefader_gui/units/panels/fx.dart';
import 'package:pipefader_gui/units/panels/pads.dart';
import 'package:pipefader_gui/units/transport_keys.dart';
import 'package:pipefader_gui/units/unit_body.dart';
import 'package:pipefader_gui/units/unit_header.dart';

const double _centreWidth = 128;
const double _deckKeySize = 30;
const double _transportShare = 0.055;
const double _minTransportWidth = 48;
const double _maxTransportWidth = 64;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final transportW = (constraints.maxWidth * _transportShare)
            .clamp(_minTransportWidth, _maxTransportWidth)
            .toDouble();
        final keyH = controlKeyHeight(constraints.maxHeight);
        final scale = ControlScale(constraints.maxHeight);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeckThemeScope(
              theme: DeckTheme(first.index),
              child: SizedBox(
                width: transportW,
                child: TransportKeys(
                  model: model,
                  deck: first,
                  column: 0,
                  usePhoneDecks: false,
                  keyHeight: keyH,
                  scale: scale,
                ),
              ),
            ),
            SizedBox(width: scale.size(6)),
            Expanded(
              child: DeckThemeScope(
                theme: DeckTheme(first.index),
                child: _UnitSlot(
                  model: model,
                  deck: first,
                  slot: ControlSlot.a,
                  keyHeight: keyH,
                  scale: scale,
                ),
              ),
            ),
            SizedBox(width: scale.size(6)),
            Expanded(
              child: DeckThemeScope(
                theme: DeckTheme(first.index),
                child: _UnitSlot(
                  model: model,
                  deck: first,
                  slot: ControlSlot.b,
                  keyHeight: keyH,
                  scale: scale,
                ),
              ),
            ),
            SizedBox(width: scale.size(6)),
            _Centre(model: model, scale: scale),
            SizedBox(width: scale.size(6)),
            Expanded(
              child: DeckThemeScope(
                theme: DeckTheme(second.index),
                child: _UnitSlot(
                  model: model,
                  deck: second,
                  slot: ControlSlot.b,
                  keyHeight: keyH,
                  scale: scale,
                ),
              ),
            ),
            SizedBox(width: scale.size(6)),
            Expanded(
              child: DeckThemeScope(
                theme: DeckTheme(second.index),
                child: _UnitSlot(
                  model: model,
                  deck: second,
                  slot: ControlSlot.a,
                  keyHeight: keyH,
                  scale: scale,
                ),
              ),
            ),
            SizedBox(width: scale.size(6)),
            DeckThemeScope(
              theme: DeckTheme(second.index),
              child: SizedBox(
                width: transportW,
                child: TransportKeys(
                  model: model,
                  deck: second,
                  column: 1,
                  usePhoneDecks: false,
                  keyHeight: keyH,
                  scale: scale,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One switchable slot: the tab row above, the panel below.
class _UnitSlot extends StatelessWidget {
  const _UnitSlot({
    required this.model,
    required this.deck,
    required this.slot,
    required this.keyHeight,
    required this.scale,
  });

  final AppModel model;
  final DeckRuntime deck;
  final ControlSlot slot;
  final double keyHeight;
  final ControlScale scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scale.size(4)),
      child: Column(
        children: [
          UnitHeader(
            model: model,
            deck: deck,
            slot: slot,
            height: keyHeight,
            scale: scale,
          ),
          Expanded(
            child: buildUnit(
              kind: model.unitOf(deck, slot),
              model: model,
              deck: deck,
              scale: scale,
            ),
          ),
        ],
      ),
    );
  }
}

class _Centre extends StatelessWidget {
  const _Centre({required this.model, required this.scale});

  final AppModel model;
  final ControlScale scale;

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
                  child: DeckThemeScope(
                    theme: DeckTheme(first.index),
                    child: BarFader(
                      value: first.fader,
                      scale: scale,
                      onChanged: (value) => model.setFader(first, value),
                    ),
                  ),
                ),
                SizedBox(width: scale.size(8)),
                SizedBox(
                  width: scale.size(8),
                  child: ValueListenableBuilder<int>(
                    valueListenable: model.clock,
                    builder: (context, _, _) =>
                        LevelMeter(level: first.meter, peak: first.meterPeak),
                  ),
                ),
                SizedBox(width: scale.size(8)),
                Expanded(
                  child: DeckThemeScope(
                    theme: DeckTheme(second.index),
                    child: BarFader(
                      value: second.fader,
                      scale: scale,
                      onChanged: (value) => model.setFader(second, value),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: scale.size(10)),
          Crossfader(
            value: model.crossfader,
            scale: scale,
            leftColor: DeckTheme(first.index).accent,
            rightColor: DeckTheme(second.index).accent,
            onChanged: model.setCrossfader,
          ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = ControlScale(constraints.maxHeight);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _AllInOneSide(
                model: model,
                deck: first,
                column: 0,
                scale: scale,
              ),
            ),
            SizedBox(width: scale.size(12)),
            Expanded(
              child: _AllInOneSide(
                model: model,
                deck: second,
                column: 1,
                scale: scale,
              ),
            ),
          ],
        );
      },
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
    required this.scale,
  });

  final AppModel model;
  final DeckRuntime deck;
  final int column;
  final ControlScale scale;

  @override
  Widget build(BuildContext context) {
    final pickerLeft = column == 0;
    final pickerSize = scale.size(_deckKeySize);
    final picker = SizedBox(
      width: pickerSize,
      child: Center(
        child: DeckPicker(
          model: model,
          column: column,
          vertical: true,
          buttonWidth: pickerSize,
          buttonHeight: pickerSize,
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
                  child: PadsPanel(
                    model: model,
                    deck: deck,
                    showModeTabs: true,
                    scale: scale,
                  ),
                ),
                SizedBox(width: scale.size(8)),
                Expanded(
                  flex: 2,
                  child: FxPanel(model: model, deck: deck, scale: scale),
                ),
              ]
            : [
                Expanded(
                  flex: 2,
                  child: FxPanel(model: model, deck: deck, scale: scale),
                ),
                SizedBox(width: scale.size(8)),
                Expanded(
                  flex: 3,
                  child: PadsPanel(
                    model: model,
                    deck: deck,
                    showModeTabs: true,
                    scale: scale,
                  ),
                ),
              ],
      ),
    );
    final showPicker = model.fullHasDeckChoice;
    final children = <Widget>[];
    if (showPicker && pickerLeft) {
      children
        ..add(picker)
        ..add(SizedBox(width: scale.size(8)));
    }
    children.add(body);
    if (showPicker && !pickerLeft) {
      children
        ..add(SizedBox(width: scale.size(8)))
        ..add(picker);
    }
    return DeckThemeScope(
      theme: DeckTheme(deck.index),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

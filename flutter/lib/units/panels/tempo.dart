import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/format.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/core/theme_scope.dart';
import 'package:pipefader_gui/state/app_model.dart';

/// Tempo: sync state, the BPM with its two step keys, the fader range and the
/// bend pair. Four rows, centred, nothing else.
class TempoPanel extends StatelessWidget {
  const TempoPanel({
    required this.model,
    required this.deck,
    this.scale,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final ControlScale? scale;

  @override
  Widget build(BuildContext context) {
    final s = scale ?? ControlScale.fallback;
    final synced = deck.sync;
    final syncLabel = !synced
        ? 'sync off'
        : model.decks.indexOf(deck).isEven
        ? 'sync leader'
        : 'sync follower';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          syncLabel,
          style: Ty.label.copyWith(
            fontSize: s.font(T.s10),
            color: synced ? DeckThemeScope.accentOf(context) : T.faint,
          ),
        ),
        SizedBox(height: s.size(4)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PanelButton(
              label: '-',
              width: 24,
              height: 24,
              scale: s,
              onTap: () => model.adjustTempo(deck, -0.001),
            ),
            SizedBox(width: s.size(8)),
            SizedBox(
              width: s.size(66),
              child: Text(
                bpmText(deck.bpm),
                textAlign: TextAlign.center,
                style: Ty.bpm.copyWith(fontSize: s.font(T.s22)),
              ),
            ),
            SizedBox(width: s.size(8)),
            PanelButton(
              label: '+',
              width: 24,
              height: 24,
              scale: s,
              onTap: () => model.adjustTempo(deck, 0.001),
            ),
          ],
        ),
        SizedBox(height: s.size(4)),
        Text(
          'range ±${(deck.view.tempoRange * 100).round()}% · ${tempoText(deck.tempo)}',
          style: Ty.labelSmall.copyWith(fontSize: s.font(T.s9)),
        ),
        SizedBox(height: s.size(6)),
        _BendRow(model: model, deck: deck, scale: s),
      ],
    );
  }
}

class _BendRow extends StatelessWidget {
  const _BendRow({
    required this.model,
    required this.deck,
    required this.scale,
  });

  final AppModel model;
  final DeckRuntime deck;
  final ControlScale scale;

  @override
  Widget build(BuildContext context) {
    final bending = deck.nudge != 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: scale.size(24),
          height: scale.size(24),
          child: HoldKey(
            label: '<',
            scale: scale,
            onDown: () => model.bend(deck, -1),
            onUp: () => model.releaseBend(deck),
          ),
        ),
        SizedBox(width: scale.size(8)),
        Text(
          bending ? 'BEND ${tempoText(1 + deck.nudge)}' : 'BEND',
          style: Ty.label.copyWith(
            fontSize: scale.font(T.s10),
            color: bending ? DeckThemeScope.accentOf(context) : T.faint,
          ),
        ),
        SizedBox(width: scale.size(8)),
        SizedBox(
          width: scale.size(24),
          height: scale.size(24),
          child: HoldKey(
            label: '>',
            scale: scale,
            onDown: () => model.bend(deck, 1),
            onUp: () => model.releaseBend(deck),
          ),
        ),
      ],
    );
  }
}

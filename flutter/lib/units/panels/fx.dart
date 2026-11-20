import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/controls/param_bar.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'fx_name.dart';

/// One FX slot: beat division, two parameters and the slot name. The name
/// toggles the slot; the small arrow opens the picker.
class FxPanel extends StatelessWidget {
  const FxPanel({
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
    return Padding(
      padding: EdgeInsets.fromLTRB(s.size(6), s.size(2), s.size(6), 0),
      child: Column(
        children: [
          SizedBox(
            height: s.size(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PanelButton(
                  label: '-',
                  width: 20,
                  height: 20,
                  scale: s,
                  onTap: () => model.stepBeats(deck, true),
                ),
                SizedBox(width: s.size(6)),
                Expanded(
                  child: Center(
                    child: _ValueLabel(
                      value: fxBeats[deck.beatsIndex],
                      label: 'beats',
                      scale: s,
                    ),
                  ),
                ),
                SizedBox(width: s.size(6)),
                PanelButton(
                  label: '+',
                  width: 20,
                  height: 20,
                  scale: s,
                  onTap: () => model.stepBeats(deck, false),
                ),
              ],
            ),
          ),
          SizedBox(height: s.size(4)),
          Expanded(
            child: ParamBar(
              label: 'FB',
              value: deck.fx1,
              scale: s,
              onChanged: (value) => model.setFxParam(deck, 0, value),
            ),
          ),
          SizedBox(height: s.size(3)),
          Expanded(
            child: ParamBar(
              label: 'MIX',
              value: deck.fx2,
              scale: s,
              onChanged: (value) => model.setFxParam(deck, 1, value),
            ),
          ),
          SizedBox(height: s.size(4)),
          SizedBox(
            height: s.size(24),
            child: FxName(model: model, deck: deck, scale: s, fill: true),
          ),
        ],
      ),
    );
  }
}

class _ValueLabel extends StatelessWidget {
  const _ValueLabel({
    required this.value,
    required this.label,
    required this.scale,
  });

  final String value;
  final String label;
  final ControlScale scale;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: Ty.num.copyWith(
              fontSize: scale.font(T.s16),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: TextStyle(fontSize: scale.font(T.s9), color: T.faint),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
  }
}

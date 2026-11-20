import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/bar_fader.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'fx_name.dart';

/// The phone's combined strip: four tone/filter faders and the FX param1
/// fader, all vertical and on the same baseline.
class MixerMaxPanel extends StatelessWidget {
  const MixerMaxPanel({
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
    final values = [deck.high, deck.mid, deck.low, deck.filter];
    const labels = ['HI', 'MID', 'LO', 'FIL'];

    Widget eqFader(int index) => Expanded(
      child: _MixerMaxFader(
        value: values[index],
        bipolar: true,
        scale: s,
        onChanged: (value) => model.setEq(deck, index, value),
        label: Text(
          labels[index],
          style: Ty.labelSmall.copyWith(fontSize: s.font(T.s8)),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(s.size(6), s.size(4), s.size(6), s.size(2)),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) SizedBox(width: s.size(6)),
            eqFader(i),
          ],
          SizedBox(width: s.size(8)),
          Expanded(
            child: _MixerMaxFader(
              value: deck.fx1,
              scale: s,
              onChanged: (value) => model.setFxParam(deck, 0, value),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: FxName(
                  model: model,
                  deck: deck,
                  compact: true,
                  scale: s,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MixerMaxFader extends StatelessWidget {
  const _MixerMaxFader({
    required this.value,
    required this.onChanged,
    required this.label,
    required this.scale,
    this.bipolar = false,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final Widget label;
  final bool bipolar;
  final ControlScale scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BarFader(
            value: value,
            bipolar: bipolar,
            scale: scale,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          height: scale.size(18),
          child: Center(child: label),
        ),
      ],
    );
  }
}

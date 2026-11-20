import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/bar_fader.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/state/app_model.dart';

/// The channel strip: high / mid / low / filter as vertical bars.
class MixerPanel extends StatelessWidget {
  const MixerPanel({
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
    const labels = ['HIGH', 'MID', 'LOW', 'FILT'];

    Widget eqFader(int index) => Expanded(
      child: Column(
        children: [
          Expanded(
            child: BarFader(
              value: values[index],
              bipolar: true,
              handleHeight: 5,
              scale: s,
              onChanged: (value) => model.setEq(deck, index, value),
            ),
          ),
          SizedBox(height: s.size(6)),
          Text(
            labels[index],
            style: Ty.labelSmall.copyWith(fontSize: s.font(T.s9)),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(s.size(6), s.size(6), s.size(6), s.size(2)),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) SizedBox(width: s.size(8)),
            eqFader(i),
          ],
        ],
      ),
    );
  }
}

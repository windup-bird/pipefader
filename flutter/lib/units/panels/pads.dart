import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/units/pad_grid.dart';

/// The pads slot. The desk picks the pad mode through the slot's unit tabs, so
/// the mode row only appears where there is no unit header (all-in-one).
class PadsPanel extends StatelessWidget {
  const PadsPanel({
    required this.model,
    required this.deck,
    this.showModeTabs = false,
    this.scale,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final bool showModeTabs;
  final ControlScale? scale;

  @override
  Widget build(BuildContext context) {
    final s = scale ?? ControlScale.fallback;
    return Column(
      children: [
        if (showModeTabs) ...[
          SizedBox(
            height: s.size(18),
            child: Center(
              child: ModeTabs(
                labels: PadMode.values.map((mode) => mode.label).toList(),
                selected: PadMode.values.indexOf(deck.padMode),
                scale: s,
                onSelect: (index) =>
                    model.setPadMode(deck, PadMode.values[index]),
              ),
            ),
          ),
          SizedBox(height: s.size(4)),
        ],
        Expanded(
          child: PadGrid(model: model, deck: deck, scale: s),
        ),
      ],
    );
  }
}

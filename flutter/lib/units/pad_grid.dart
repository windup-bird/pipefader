import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/pad.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/state/app_model.dart';

/// Eight pads in two rows of four. The pad-mode switches live above the slot,
/// not in here.
class PadGrid extends StatelessWidget {
  const PadGrid({
    required this.model,
    required this.deck,
    this.scale,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final ControlScale? scale;

  bool _isLit(int index) {
    switch (deck.padMode) {
      case PadMode.cue:
        return deck.hotCues.contains(index);
      case PadMode.loop:
        return deck.loopActive && deck.loopBeatsIndex == index;
      case PadMode.jump:
        return deck.jumpBeatsIndex == index;
    }
  }

  Color _colorOf(int index) {
    switch (deck.padMode) {
      case PadMode.cue:
        return T.padCueColors[index % T.padCueColors.length];
      case PadMode.loop:
        return T.padLoopColor;
      case PadMode.jump:
        return T.padJumpColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = deck.padMode.pads;
    final s = scale ?? ControlScale.fallback;

    Widget padCell(int index) => Expanded(
      child: Pad(
        label: labels[index],
        lit: _isLit(index),
        color: _colorOf(index),
        scale: s,
        onTap: () => model.tapPad(deck, index),
      ),
    );

    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) SizedBox(height: s.size(4)),
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < 4; column++) ...[
                  if (column > 0) SizedBox(width: s.size(4)),
                  padCell(row * 4 + column),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

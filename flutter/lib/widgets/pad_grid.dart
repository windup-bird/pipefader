import 'package:material_ui/material_ui.dart';

import '../model/deck.dart';
import '../state/app_model.dart';
import '../theme.dart';
import 'device.dart';

/// Eight pads in two rows of four. The pad-mode switches live above the slot,
/// not in here.
class PadGrid extends StatelessWidget {
  const PadGrid({required this.model, required this.deck, super.key});

  final AppModel model;
  final DeckRuntime deck;

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

  @override
  Widget build(BuildContext context) {
    final labels = deck.padMode.pads;

    Widget padCell(int index) => Expanded(
      child: Pad(
        label: labels[index],
        lit: _isLit(index),
        onTap: () => model.tapPad(deck, index),
      ),
    );

    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < 4; column++) ...[
                  if (column > 0) const SizedBox(width: 4),
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

class Pad extends StatefulWidget {
  const Pad({
    required this.label,
    required this.lit,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool lit;
  final VoidCallback onTap;

  @override
  State<Pad> createState() => _PadState();
}

class _PadState extends State<Pad> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final lit = widget.lit;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          decoration: keyFace(active: lit, pressed: _pressed, hover: _hover),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: Ty.pad.copyWith(
              color: lit ? T.bg : (_hover ? T.text : T.dim),
            ),
          ),
        ),
      ),
    );
  }
}

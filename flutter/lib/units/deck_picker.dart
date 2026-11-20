import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/core/device.dart';

/// The per-deck buttons above a transport. One key per deck, never a cycle:
/// the left column shows 1/3, the right 2/4. [expand] makes the row fill the
/// transport width; in all-in-one the picker turns vertical, sits on the
/// outside edge and uses square keys. Owners hide it for a two-deck rig.
class DeckPicker extends StatelessWidget {
  const DeckPicker({
    required this.model,
    required this.column,
    this.usePhoneDecks = false,
    this.vertical = false,
    this.expand = false,
    this.buttonWidth = 24,
    this.buttonHeight = 20,
    super.key,
  });

  final AppModel model;
  final int column;
  final bool usePhoneDecks;
  final bool vertical;
  final bool expand;
  final double buttonWidth;
  final double buttonHeight;

  @override
  Widget build(BuildContext context) {
    final decks = usePhoneDecks
        ? model.phoneColumnDecks(column)
        : model.fullColumnDecks(column);
    final selected = usePhoneDecks
        ? model.phoneSlotDeck(column)
        : model.fullSlotDeck(column);

    if (decks.isEmpty) return const SizedBox.shrink();
    final fill = expand && !vertical;
    final keys = <Widget>[];
    for (var i = 0; i < decks.length; i++) {
      final deck = decks[i];
      if (i > 0) {
        keys.add(
          vertical ? const SizedBox(height: 4) : const SizedBox(width: 2),
        );
      }
      final button = DeckButton(
        key: ValueKey('deck-${deck + 1}'),
        label: '${deck + 1}',
        selected: deck == selected,
        width: fill ? null : buttonWidth,
        height: buttonHeight,
        onTap: () => usePhoneDecks
            ? model.setPhoneSlot(column, deck)
            : model.setFullSlot(column, deck),
      );
      keys.add(fill ? Expanded(child: button) : button);
    }
    return vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: keys)
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: keys,
          );
  }
}

/// One numbered key in a [DeckPicker]. A null [width] fills the slot.
class DeckButton extends StatefulWidget {
  const DeckButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.width = 24,
    this.height = 20,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double? width;
  final double height;

  @override
  State<DeckButton> createState() => _DeckButtonState();
}

class _DeckButtonState extends State<DeckButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: keyFace(active: widget.selected, hover: _hover),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            maxLines: 1,
            style: TextStyle(
              fontSize: widget.height >= 28 ? T.s10 : T.s9,
              height: 1.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: widget.selected
                  ? T.text
                  : _hover
                  ? T.text
                  : T.dim,
            ),
          ),
        ),
      ),
    );
  }
}

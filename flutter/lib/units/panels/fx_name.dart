import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/device.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/units/unit_menu.dart';

/// The FX name key plus its dropdown arrow, shared by the full FX panel and the
/// phone's combined mixer strip.
class FxName extends StatefulWidget {
  const FxName({
    required this.model,
    required this.deck,
    required this.scale,
    this.compact = false,
    this.fill = false,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final bool compact;

  /// When true the name key stretches to fill the row, so it lines up with the
  /// beats strip above it.
  final bool fill;
  final ControlScale scale;

  @override
  State<FxName> createState() => _FxNameState();
}

class _FxNameState extends State<FxName> {
  final _anchor = GlobalKey();
  bool _nameHover = false;
  bool _selectHover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.deck.fxOn;
    final compact = widget.compact;
    final s = widget.scale;
    final rowH = s.size(compact ? 18 : 24);
    final nameKey = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _nameHover = true),
      onExit: (_) => setState(() => _nameHover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.model.toggleFx(widget.deck),
        child: Container(
          height: rowH,
          padding: EdgeInsets.symmetric(horizontal: s.size(compact ? 5 : 8)),
          decoration: keyFace(active: on, hover: _nameHover),
          alignment: Alignment.center,
          child: Text(
            fxSlots[widget.deck.fxSlot],
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: Ty.label.copyWith(
              fontSize: s.font(compact ? T.s8 : T.s10),
              color: on ? T.text : _nameHover ? T.text : T.dim,
            ),
          ),
        ),
      ),
    );
    final selectKey = SizedBox(
      width: s.size(compact ? 16 : 20),
      height: rowH,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _selectHover = true),
        onExit: (_) => setState(() => _selectHover = false),
        child: GestureDetector(
          key: _anchor,
          behavior: HitTestBehavior.opaque,
          onTap: () => showChoiceMenu(
            context: context,
            anchorKey: _anchor,
            labels: fxSlots,
            current: widget.deck.fxSlot,
            onSelect: (index) => widget.model.setFxSlot(widget.deck, index),
          ),
          child: Container(
            decoration: keyFace(hover: _selectHover),
            child: Center(
              child: Glyph(
                GlyphKind.dropdown,
                size: s.size(compact ? 7 : 8),
                color: _selectHover ? T.text : T.faint,
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.fill) {
      return Row(
        children: [
          Expanded(child: nameKey),
          SizedBox(width: s.size(4)),
          selectKey,
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        nameKey,
        SizedBox(width: s.size(compact ? 2 : 4)),
        selectKey,
      ],
    );
  }
}

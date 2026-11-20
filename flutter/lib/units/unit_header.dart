import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/units/unit_menu.dart';

/// The row above a unit panel: one tab per enabled unit, with the gear that
/// edits that tab set pinned to the right edge.
class UnitHeader extends StatefulWidget {
  const UnitHeader({
    required this.model,
    required this.deck,
    required this.slot,
    required this.height,
    this.scale,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final ControlSlot slot;
  final double height;
  final ControlScale? scale;

  @override
  State<UnitHeader> createState() => _UnitHeaderState();
}

class _UnitHeaderState extends State<UnitHeader> {
  final _gear = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final options = widget.model.unitOptions(widget.deck, widget.slot);
    final s = widget.scale ?? ControlScale.fallback;
    final gearSize = s.size(18);
    return SizedBox(
      height: widget.height,
      child: Row(
        children: [
          Expanded(
            child: ModeTabs(
              labels: options.map((kind) => kind.tabLabel).toList(),
              selected: options.indexOf(
                widget.model.unitOf(widget.deck, widget.slot),
              ),
              scrollable: true,
              fontSize: T.s11,
              scale: s,
              onSelect: (index) => widget.model.selectUnit(
                widget.deck,
                widget.slot,
                options[index],
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            key: const ValueKey('unit-settings'),
            width: gearSize,
            height: gearSize,
            child: GlyphButton(
              key: _gear,
              glyph: GlyphKind.settings,
              size: gearSize,
              onTap: () => showUnitMenu(
                context: context,
                anchorKey: _gear,
                model: widget.model,
                deck: widget.deck,
                slot: widget.slot,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/format.dart';
import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/core/device.dart';
import 'package:pipefader_gui/core/glyph.dart';

class _MenuPlacement {
  const _MenuPlacement(this.left, this.top, this.width);

  final double left;
  final double top;
  final double width;
}

/// Places a flat menu under its anchor, or above it when there is no room
/// below. Returns null while the anchor is not laid out yet.
_MenuPlacement? _placeMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required double height,
  required double minWidth,
  required double maxWidth,
}) {
  final render = anchorKey.currentContext?.findRenderObject();
  if (render is! RenderBox || !render.attached) return null;
  final origin = render.localToGlobal(Offset.zero);
  final screen = MediaQuery.sizeOf(context);
  final width = render.size.width.clamp(minWidth, maxWidth);

  var left = origin.dx + render.size.width / 2 - width / 2;
  left = left.clamp(8.0, math.max(8.0, screen.width - width - 8.0));
  final below = origin.dy + render.size.height + 6;
  final above = origin.dy - height - 6;
  final top = below + height <= screen.height - 8 || above < 8 ? below : above;
  return _MenuPlacement(left, top, width);
}

/// A small square popup anchored above the tapped label. Material's popup menu
/// brings rounded corners and a shadow; the sketch wants neither, so the menu
/// is an overlay of flat rows.
void showChoiceMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<String> labels,
  required int current,
  required ValueChanged<int> onSelect,
}) {
  const rowHeight = 30.0;
  final placement = _placeMenu(
    context: context,
    anchorKey: anchorKey,
    height: rowHeight * labels.length,
    minWidth: 140,
    maxWidth: 176,
  );
  if (placement == null) return;
  final overlay = Overlay.of(context);

  late final OverlayEntry entry;
  void dismiss() {
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: dismiss,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
            ),
          ),
          Positioned(
            left: placement.left,
            top: placement.top,
            width: placement.width,
            child: Container(
              decoration: panelFace(color: T.surfaceHi),
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: T.s13,
                  color: T.text,
                  decoration: TextDecoration.none,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      _MenuRow(
                        label: labels[i],
                        selected: i == current,
                        height: rowHeight,
                        onTap: () {
                          dismiss();
                          onSelect(i);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
}

/// The gear menu: every legal unit for a slot with a check on the ones already
/// in its tab row. Rows toggle in place, so the menu stays open while the user
/// builds the tab set; tapping the scrim closes it.
void showUnitMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required AppModel model,
  required DeckRuntime deck,
  required ControlSlot slot,
}) {
  final legal = switch (slot) {
    ControlSlot.a => deskUnitA,
    ControlSlot.b => deskUnitB,
    ControlSlot.phone => phoneUnitKinds,
  };
  const rowHeight = 28.0;
  final placement = _placeMenu(
    context: context,
    anchorKey: anchorKey,
    height: rowHeight * legal.length,
    minWidth: 150,
    maxWidth: 190,
  );
  if (placement == null) return;
  final overlay = Overlay.of(context);

  late final OverlayEntry entry;
  void dismiss() {
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: dismiss,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
            ),
          ),
          Positioned(
            left: placement.left,
            top: placement.top,
            width: placement.width,
            child: Container(
              decoration: panelFace(color: T.surfaceHi),
              child: AnimatedBuilder(
                animation: model,
                builder: (context, _) {
                  final enabled = model.unitOptions(deck, slot);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final kind in legal)
                        _UnitOptionRow(
                          key: ValueKey('unit-option-${kind.name}'),
                          label: kind.label,
                          checked: enabled.contains(kind),
                          height: rowHeight,
                          onTap: () => model.toggleUnitOption(deck, slot, kind),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.label,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? T.accent
        : _hover
        ? T.text
        : T.dim;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: widget.height,
          width: double.infinity,
          color: _hover ? T.surface : Colors.transparent,
          alignment: Alignment.center,
          child: Text(
            capitalizeWords(widget.label),
            style: Ty.label.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

class _UnitOptionRow extends StatefulWidget {
  const _UnitOptionRow({
    required this.label,
    required this.checked,
    required this.height,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool checked;
  final double height;
  final VoidCallback onTap;

  @override
  State<_UnitOptionRow> createState() => _UnitOptionRowState();
}

class _UnitOptionRowState extends State<_UnitOptionRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.checked
        ? T.accent
        : _hover
        ? T.text
        : T.dim;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: widget.height,
          color: _hover ? T.surface : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label.toUpperCase(),
                  style: Ty.label.copyWith(color: color),
                ),
              ),
              SizedBox(
                width: 12,
                child: widget.checked
                    ? const Glyph(GlyphKind.check, size: 9, color: T.accent)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

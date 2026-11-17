import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'device.dart';

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
  final render = anchorKey.currentContext?.findRenderObject();
  if (render is! RenderBox || !render.attached) return;
  final overlay = Overlay.of(context);
  final origin = render.localToGlobal(Offset.zero);
  final anchor = render.size;
  final screen = MediaQuery.sizeOf(context);

  const rowHeight = 30.0;
  final width = anchor.width.clamp(140.0, 176.0);
  final height = rowHeight * labels.length;

  var left = origin.dx + anchor.width / 2 - width / 2;
  left = left.clamp(8.0, math.max(8.0, screen.width - width - 8.0));
  final below = origin.dy + anchor.height + 6;
  final above = origin.dy - height - 6;
  final top = below + height <= screen.height - 8 || above < 8 ? below : above;

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
            left: left,
            top: top,
            width: width,
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
            widget.label.toUpperCase(),
            style: Ty.label.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

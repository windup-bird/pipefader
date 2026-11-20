import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/theme.dart';

class Pad extends StatefulWidget {
  const Pad({
    required this.label,
    required this.lit,
    required this.color,
    required this.scale,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool lit;
  final Color color;
  final ControlScale scale;
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
    final color = widget.color;
    // Idle is neutral deep grey with a dim strip; a hit lifts the face to the
    // bright grey and lights the colour strip. No glow, no gradient.
    final face = lit
        ? T.lit
        : _pressed
        ? const Color(0xFF202020)
        : _hover
        ? T.surfaceHi
        : T.surface;
    final stripColor = lit ? color : T.line;
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
          decoration: BoxDecoration(
            color: face,
            border: const Border(top: BorderSide(color: T.highlight, width: 1)),
            boxShadow: const [
              BoxShadow(
                color: T.shadowSoft,
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: Ty.pad.copyWith(
                    fontSize: widget.scale.font(T.s12),
                    color: lit ? T.text : (_hover ? T.text : T.dim),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: LayoutBuilder(
                  builder: (context, constraints) => Container(
                    width: constraints.maxWidth * 0.5,
                    height: widget.scale.size(3, min: 2, max: 5),
                    color: stripColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

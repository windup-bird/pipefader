import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/layout_mode.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/logo.dart';
import 'package:pipefader_gui/layout/app_menu.dart';

/// The header is the mark and nothing else: no name, no toolbar. Tapping the
/// mark opens the layout / controller / output / settings menu.
class Header extends StatelessWidget {
  const Header({
    required this.model,
    required this.mode,
    required this.height,
    super.key,
  });

  final AppModel model;
  final LayoutMode mode;
  final double height;

  @override
  Widget build(BuildContext context) {
    final state = model.logoStatus(mode);
    return SizedBox(
      height: height,
      child: Center(
        child: LogoButton(
          model: model,
          mode: mode,
          size: height * 0.66,
          levels: state.levels,
          leader: state.leader,
        ),
      ),
    );
  }
}

class LogoButton extends StatefulWidget {
  const LogoButton({
    required this.model,
    required this.mode,
    required this.size,
    this.levels = const <double>[1, 1],
    this.leader = -1,
    super.key,
  });

  final AppModel model;
  final LayoutMode mode;
  final double size;

  /// One fader position per deck; empty falls back to the resting mark.
  final List<double> levels;
  final int leader;

  @override
  State<LogoButton> createState() => _LogoButtonState();
}

class _LogoButtonState extends State<LogoButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final box = context.findRenderObject();
          Rect? rect;
          if (box is RenderBox && box.hasSize) {
            // The tap target carries padding; fly from the mark itself so the
            // menu's start size matches what the header is showing.
            final full = box.localToGlobal(Offset.zero) & box.size;
            final count = widget.levels.isEmpty ? 1 : widget.levels.length;
            rect = Rect.fromCenter(
              center: full.center,
              width: LogoFaders.widthFor(widget.size, count),
              height: widget.size,
            );
          }
          showAppMenu(
            context,
            model: widget.model,
            current: widget.model.forcedLayout ?? widget.mode,
            logoRect: rect,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: _hover ? 1.0 : 0.86,
            child: LogoFaders(
              levels: widget.levels,
              leader: widget.leader,
              size: widget.size,
            ),
          ),
        ),
      ),
    );
  }
}

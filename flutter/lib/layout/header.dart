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
          sounding: state.sounding,
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
    this.sounding = const <bool>[false, false],
    this.leader = -1,
    super.key,
  });

  final AppModel model;
  final LayoutMode mode;
  final double size;

  /// One entry per deck; empty falls back to the resting mark.
  final List<bool> sounding;
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
          final rect = box is RenderBox && box.hasSize
              ? box.localToGlobal(Offset.zero) & box.size
              : null;
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
              sounding: widget.sounding,
              leader: widget.leader,
              size: widget.size,
            ),
          ),
        ),
      ),
    );
  }
}

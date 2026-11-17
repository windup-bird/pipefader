import 'package:material_ui/material_ui.dart';

import '../layout/layout_mode.dart';
import '../state/app_model.dart';
import '../theme.dart';
import '../widgets/logo.dart';
import 'app_menu.dart';

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
    return SizedBox(
      height: height,
      child: Center(
        child: LogoButton(model: model, mode: mode, size: height * 0.66),
      ),
    );
  }
}

class LogoButton extends StatefulWidget {
  const LogoButton({
    required this.model,
    required this.mode,
    required this.size,
    super.key,
  });

  final AppModel model;
  final LayoutMode mode;
  final double size;

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
        onTap: () => showAppMenu(
          context,
          model: widget.model,
          current: widget.model.forcedLayout ?? widget.mode,
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: _hover ? 1.0 : 0.86,
            child: LogoMark(
              size: widget.size,
              accent: _hover ? T.accentHi : T.accent,
            ),
          ),
        ),
      ),
    );
  }
}

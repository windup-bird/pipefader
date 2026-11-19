import 'package:material_ui/material_ui.dart';

import '../layout/layout_mode.dart';
import '../state/app_model.dart';
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
    final state = logoStateFor(model, mode);
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

/// The mark's per-deck sounding flags and the leader index for a layout.
class LogoState {
  const LogoState(this.sounding, this.leader);

  final List<bool> sounding;
  final int leader;
}

LogoState logoStateFor(AppModel model, LayoutMode mode) {
  final decks = model.activeDecks(model.deckCountFor(mode));
  var leader = -1;
  final sounding = <bool>[];
  for (var i = 0; i < decks.length; i++) {
    final on = decks[i].playing;
    sounding.add(on);
    if (on && leader < 0) leader = i;
  }
  return LogoState(sounding, leader);
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

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/device.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/core/theme_scope.dart';

/// A horizontal parameter fader: label, track and metal handle. The slot
/// widens while held, like the channel faders.
class ParamBar extends StatefulWidget {
  const ParamBar({
    required this.label,
    required this.value,
    required this.onChanged,
    this.scale,
    super.key,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ControlScale? scale;

  @override
  State<ParamBar> createState() => _ParamBarState();
}

class _ParamBarState extends State<ParamBar> {
  static const _handleW = 9.0;

  bool _active = false;
  bool _hover = false;
  double _value = 0;
  double _lastX = 0;

  @override
  void initState() {
    super.initState();
    _value = widget.value.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(ParamBar old) {
    super.didUpdateWidget(old);
    if (!_active) _value = widget.value.clamp(0.0, 1.0);
  }

  void _setFromDrag(double x, double width, double handleW) {
    final travel = width - handleW;
    if (travel <= 0) return;
    final dx = x - _lastX;
    _lastX = x;
    final value = (_value + dx / travel).clamp(0.0, 1.0);
    if (value == _value) return;
    setState(() => _value = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale ?? ControlScale.fallback;
    final handleW = scale.size(_handleW);
    return Row(
      children: [
        SizedBox(
          width: scale.size(22),
          child: Text(
            widget.label,
            style: Ty.labelSmall.copyWith(fontSize: scale.font(T.s9)),
          ),
        ),
        SizedBox(width: scale.size(5)),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              // Like the crossfader, the slot and the handle share one
              // thickness; the slot only grows to it while held.
              final slotOpen = height - scale.size(4);
              final handleH = slotOpen;
              final handleTop = (height - handleH) / 2;
              final handleX = handleW / 2 + _value * (width - handleW);
              final deckTheme = DeckThemeScope.of(context);
              final fillAccent = deckTheme?.accent ?? T.accent;
              return MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                onEnter: (_) => setState(() => _hover = true),
                onExit: (_) => setState(() => _hover = false),
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    setState(() {
                      _active = true;
                      _lastX = event.localPosition.dx;
                    });
                  },
                  onPointerMove: (event) {
                    if (!_active) return;
                    _setFromDrag(event.localPosition.dx, width, handleW);
                  },
                  onPointerUp: (_) {
                    if (!_active) return;
                    setState(() => _active = false);
                  },
                  onPointerCancel: (_) {
                    if (!_active) return;
                    setState(() => _active = false);
                  },
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      end: _active ? slotOpen : scale.size(3),
                    ),
                    duration: const Duration(milliseconds: 110),
                    curve: Curves.easeOut,
                    builder: (context, slot, _) {
                      return Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: (height - slot) / 2,
                            height: slot,
                            child: DecoratedBox(decoration: slotFace()),
                          ),
                          Positioned(
                            left: 0,
                            top: (height - slot) / 2,
                            width: handleX,
                            height: slot,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: fillAccent),
                            ),
                          ),
                          Positioned(
                            left: handleX - handleW / 2,
                            top: handleTop,
                            width: handleW,
                            height: handleH,
                            child: FaderHandle(
                              vertical: true,
                              active: _active,
                              hover: _hover,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

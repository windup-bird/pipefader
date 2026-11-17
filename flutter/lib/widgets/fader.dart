import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'device.dart';

/// The crossfader: the bar fader turned sideways. Hairline slot, vertical
/// handle, the travelled half lit from the centre out; the slot thickens to the
/// handle's height while held.
class Crossfader extends StatefulWidget {
  const Crossfader({
    required this.value,
    required this.onChanged,
    this.height = 28,
    super.key,
  });

  /// -1 (left) .. +1 (right).
  final double value;
  final ValueChanged<double> onChanged;
  final double height;

  @override
  State<Crossfader> createState() => _CrossfaderState();
}

class _CrossfaderState extends State<Crossfader> {
  static const _duration = Duration(milliseconds: 110);
  static const _handleW = 8.0;

  bool _active = false;
  bool _hover = false;
  double _value = 0;
  double _lastX = 0;

  @override
  void initState() {
    super.initState();
    _value = widget.value.clamp(-1.0, 1.0);
  }

  @override
  void didUpdateWidget(Crossfader old) {
    super.didUpdateWidget(old);
    if (!_active && old.value != widget.value) {
      _value = widget.value.clamp(-1.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final centre = width / 2;
            final half = (width - _handleW) / 2;
            final handleX = centre + _value * half;
            final base = centre;
            final fillLeft = handleX < base ? handleX : base;
            final fillWidth = (handleX - base).abs();
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                setState(() {
                  _active = true;
                  _lastX = event.localPosition.dx;
                });
              },
              onPointerMove: (event) {
                if (!_active) return;
                final dx = event.localPosition.dx - _lastX;
                _lastX = event.localPosition.dx;
                if (half <= 0) return;
                setState(() => _value = (_value + dx / half).clamp(-1.0, 1.0));
              },
              onPointerUp: (_) {
                if (!_active) return;
                setState(() => _active = false);
                widget.onChanged(_value);
              },
              onPointerCancel: (_) {
                if (!_active) return;
                setState(() => _active = false);
                widget.onChanged(_value);
              },
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: _active ? widget.height - 4 : 2),
                duration: _duration,
                curve: Curves.easeOut,
                builder: (context, slotHeight, _) {
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: (widget.height - slotHeight) / 2,
                        height: slotHeight,
                        child: DecoratedBox(decoration: slotFace()),
                      ),
                      Positioned(
                        left: fillLeft,
                        top: (widget.height - slotHeight) / 2,
                        width: fillWidth,
                        height: slotHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [T.accentLo, T.accent],
                            ),
                            boxShadow: _active
                                ? const [
                                    BoxShadow(
                                      color: T.glowAccent,
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                      Positioned(
                        left: handleX - _handleW / 2,
                        top: 2,
                        bottom: 2,
                        width: _handleW,
                        child: DecoratedBox(
                          decoration: handleFace(
                            active: _active,
                            hover: _hover,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

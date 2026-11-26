import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/core/device.dart';

/// The crossfader: a flat slot with a solid handle. The left half carries the
/// left deck's colour and the right half the right deck's, so which way the
/// blend leans reads at a glance. The slot thickens to the handle's height
/// while held.
class Crossfader extends StatefulWidget {
  const Crossfader({
    required this.value,
    required this.onChanged,
    this.leftColor = T.accent,
    this.rightColor = T.accent,
    this.height = 28,
    this.scale,
    super.key,
  });

  /// -1 (left) .. +1 (right).
  final double value;
  final ValueChanged<double> onChanged;

  /// The colour each half burns as the blend moves toward it.
  final Color leftColor;
  final Color rightColor;

  final double height;
  final ControlScale? scale;

  @override
  State<Crossfader> createState() => _CrossfaderState();
}

class _CrossfaderState extends State<Crossfader> {
  static const _duration = Duration(milliseconds: 110);
  static const _handleW = 7.0;

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
    final scale = widget.scale ?? ControlScale.fallback;
    final handleW = scale.size(_handleW);
    final height = scale.size(widget.height);
    // The slot and the handle share one thickness; the slot only grows to it
    // when held, the handle always sits at it.
    final slotOpen = height - scale.size(4);
    final handleH = slotOpen;
    final handleTop = (height - handleH) / 2;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final centre = width / 2;
            final half = (width - handleW) / 2;
            final handleX = centre + _value * half;
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
                final value = (_value + dx / half).clamp(-1.0, 1.0);
                if (value == _value) return;
                setState(() => _value = value);
                widget.onChanged(value);
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
                tween: Tween<double>(end: _active ? slotOpen : scale.size(2)),
                duration: _duration,
                curve: Curves.easeOut,
                builder: (context, slotHeight, _) {
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: (height - slotHeight) / 2,
                        height: slotHeight,
                        child: DecoratedBox(decoration: slotFace()),
                      ),
                      // Only the span from the centre to the handle lights, in
                      // the colour of the side it leans toward.
                      if (_value <= 0)
                        Positioned(
                          left: handleX,
                          top: (height - slotHeight) / 2,
                          width: centre - handleX,
                          height: slotHeight,
                          child: ColoredBox(color: widget.leftColor),
                        )
                      else
                        Positioned(
                          left: centre,
                          top: (height - slotHeight) / 2,
                          width: handleX - centre,
                          height: slotHeight,
                          child: ColoredBox(color: widget.rightColor),
                        ),
                      Positioned(
                        left: handleX - handleW / 2,
                        top: handleTop,
                        height: handleH,
                        width: handleW,
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
            );
          },
        ),
      ),
    );
  }
}

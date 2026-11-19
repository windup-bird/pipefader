import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'cover.dart';
import 'device.dart';

/// A vertical bar fader: a hairline slot that widens to the handle's width
/// while held, a wide horizontal handle, and the travelled length lit in the
/// accent. Channel faders are unipolar, EQs sit around the centre; both use the
/// same shape so the mixer reads as the same instrument.
class BarFader extends StatefulWidget {
  const BarFader({
    required this.value,
    required this.onChanged,
    this.bipolar = false,
    this.handleHeight = 9,
    this.scale,
    super.key,
  });

  /// 0..1 for a channel fader, -1..1 when [bipolar].
  final double value;
  final ValueChanged<double> onChanged;
  final bool bipolar;
  final double handleHeight;
  final ControlScale? scale;

  @override
  State<BarFader> createState() => _BarFaderState();
}

class _BarFaderState extends State<BarFader> {
  static const _duration = Duration(milliseconds: 110);

  bool _active = false;
  bool _hover = false;
  double _value = 0;
  double _lastY = 0;

  @override
  void initState() {
    super.initState();
    _value = _clamp(widget.value);
  }

  @override
  void didUpdateWidget(BarFader old) {
    super.didUpdateWidget(old);
    if (!_active && old.value != widget.value) {
      _value = _clamp(widget.value);
    }
  }

  double _clamp(double value) =>
      widget.bipolar ? value.clamp(-1.0, 1.0) : value.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale ?? ControlScale.fallback;
    final handle = scale.size(widget.handleHeight);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final width = constraints.maxWidth;
          final travel = height - handle;
          final half = travel / 2;
          final centre = height / 2;
          final handleY = widget.bipolar
              ? centre - _value * half
              : height - handle / 2 - _value * travel;
          final base = widget.bipolar ? centre : height;
          final fillTop = handleY < base ? handleY : base;
          final fillHeight = (handleY - base).abs();
          final deckTheme = DeckThemeScope.of(context);
          final fillAccent = deckTheme?.accent ?? T.accent;

          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              setState(() {
                _active = true;
                _lastY = event.localPosition.dy;
              });
            },
            onPointerMove: (event) {
              if (!_active) return;
              final dy = _lastY - event.localPosition.dy;
              _lastY = event.localPosition.dy;
              final span = widget.bipolar ? half : travel;
              if (span <= 0) return;
              setState(() => _value = _clamp(_value + dy / span));
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
              tween: Tween<double>(end: _active ? width : scale.size(2)),
              duration: _duration,
              curve: Curves.easeOut,
              builder: (context, slotWidth, _) {
                // A gauge a touch narrower than the column, shared by the slot
                // and the handle so both read as one instrument.
                final gaugeW = width - scale.size(4);
                final gaugeLeft = (width - gaugeW) / 2;
                final slotW = gaugeW * (slotWidth / width);
                final slotLeft = (width - slotW) / 2;
                return Stack(
                  children: [
                    Positioned(
                      left: slotLeft,
                      top: 0,
                      width: slotW,
                      height: height,
                      child: DecoratedBox(decoration: slotFace()),
                    ),
                    Positioned(
                      left: slotLeft,
                      top: fillTop,
                      width: slotW,
                      height: fillHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: fillAccent),
                      ),
                    ),
                    Positioned(
                      left: gaugeLeft,
                      width: gaugeW,
                      top: handleY - handle / 2,
                      height: handle,
                      child: FaderHandle(active: _active, hover: _hover),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

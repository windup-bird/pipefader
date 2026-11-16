import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// One deck's post-fader level. Linear input, a -48 dB scale on the way out,
/// with a short peak line above the bar.
class LevelMeter extends StatelessWidget {
  const LevelMeter({
    required this.level,
    required this.peak,
    this.width = 8,
    super.key,
  });

  final double level;
  final double peak;
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, double.infinity),
      painter: _MeterPainter(level, peak),
    );
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter(this.level, this.peak);

  final double level;
  final double peak;

  static double _fraction(double linear) {
    if (linear <= 0) return 0;
    final db = 20 * math.log(linear) / math.ln10;
    return ((db + 48) / 48).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = T.surface);
    final fraction = _fraction(level);
    if (fraction <= 0) return;
    final filled = Rect.fromLTWH(
      0,
      size.height * (1 - fraction),
      size.width,
      size.height * fraction,
    );
    canvas.drawRect(
      filled,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [T.accentLo, T.accent],
        ).createShader(Offset.zero & size),
    );

    final peakFraction = _fraction(peak);
    if (peakFraction > 0.01) {
      canvas.drawRect(
        Rect.fromLTWH(0, size.height * (1 - peakFraction), size.width, 2),
        Paint()..color = T.accentHi,
      );
    }
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.level != level || old.peak != peak;
}

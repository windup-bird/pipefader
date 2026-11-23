import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/theme.dart';

/// Stand-in artwork: a dark, blue-family abstract so the deck header has the
/// weight of a real cover without shipping an image. Three compositions keyed
/// off the seed, all square and quiet.
class CoverArt extends StatelessWidget {
  const CoverArt({
    required this.size,
    required this.seed,
    this.color = T.accent,
    this.image,
    super.key,
  });

  final double size;
  final int seed;
  final ui.Image? image;

  /// The deck accent the artwork leans on. Defaults to the global accent when
  /// no deck is around.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(T.radiusCover),
      child: image == null
          ? CustomPaint(
              size: Size.square(size),
              painter: _CoverPainter(seed, color),
            )
          : RawImage(
              image: image,
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
    );
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.seed, this.color);

  final int seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final variant = seed % 3;
    final hue = HSLColor.fromColor(color).hue;
    final deep = HSLColor.fromAHSL(1, hue, 0.42, 0.12).toColor();
    final shade = HSLColor.fromAHSL(1, hue + 4, 0.40, 0.085).toColor();
    final mid = HSLColor.fromAHSL(1, hue, 0.50, 0.28).toColor();
    final glow = HSLColor.fromAHSL(1, hue + 8, 0.62, 0.60).toColor();
    final accent = color;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [deep, shade],
        ).createShader(Offset.zero & size),
    );

    switch (variant) {
      case 0:
        _orb(canvas, size, glow, mid, const Offset(0.66, 0.32), 0.44);
        canvas.drawRect(
          Rect.fromLTWH(0, size.height * 0.84, size.width, size.height * 0.055),
          Paint()..color = accent.withValues(alpha: 0.85),
        );
      case 1:
        final band = Path()
          ..moveTo(size.width * 0.02, size.height * 0.98)
          ..lineTo(size.width * 0.72, size.height * 0.02)
          ..lineTo(size.width * 0.92, size.height * 0.02)
          ..lineTo(size.width * 0.22, size.height * 0.98)
          ..close();
        canvas.drawPath(band, Paint()..color = mid.withValues(alpha: 0.75));
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * 0.10,
            size.height * 0.12,
            size.width * 0.16,
            size.width * 0.16,
          ),
          Paint()..color = accent.withValues(alpha: 0.8),
        );
      default:
        _orb(canvas, size, glow, mid, const Offset(0.34, 0.60), 0.34);
        canvas.drawCircle(
          Offset(size.width * 0.70, size.height * 0.30),
          size.width * 0.24,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, size.width * 0.012)
            ..color = glow.withValues(alpha: 0.55),
        );
        canvas.drawLine(
          Offset(0, size.height * 0.80),
          Offset(size.width, size.height * 0.80),
          Paint()
            ..strokeWidth = 1
            ..color = accent.withValues(alpha: 0.45),
        );
    }
  }

  void _orb(
    Canvas canvas,
    Size size,
    Color glow,
    Color mid,
    Offset at,
    double radius,
  ) {
    final center = Offset(size.width * at.dx, size.height * at.dy);
    final r = size.width * radius;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [glow.withValues(alpha: 0.55), mid.withValues(alpha: 0.12)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_CoverPainter old) =>
      old.seed != seed || old.color != color;
}

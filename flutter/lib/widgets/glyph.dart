import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The few glyphs the sketch needs. Drawn rather than font icons so the weight
/// matches the hairlines and no icon font has to be shipped.
enum GlyphKind { panel, panelRight, search, plus, minus, close }

class Glyph extends StatelessWidget {
  const Glyph(
    this.kind, {
    this.size = 16,
    this.color = T.dim,
    super.key,
  });

  final GlyphKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(kind, color),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.kind, this.color);

  final GlyphKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;
    final center = Offset(size.width / 2, size.height / 2);
    final half = size.shortestSide / 2;

    switch (kind) {
      case GlyphKind.panel:
        final rect = Rect.fromLTRB(2, 2, size.width - 2, size.height - 2);
        canvas.drawRect(rect, paint);
        canvas.drawLine(
          Offset(rect.left + rect.width * 0.34, rect.top),
          Offset(rect.left + rect.width * 0.34, rect.bottom),
          paint,
        );
      case GlyphKind.panelRight:
        final rect = Rect.fromLTRB(2, 2, size.width - 2, size.height - 2);
        canvas.drawRect(rect, paint);
        canvas.drawLine(
          Offset(rect.left + rect.width * 0.66, rect.top),
          Offset(rect.left + rect.width * 0.66, rect.bottom),
          paint,
        );
      case GlyphKind.search:
        canvas.drawCircle(center.translate(-1, -1), half * 0.62, paint);
        canvas.drawLine(
          center.translate(half * 0.34, half * 0.34),
          center.translate(half * 0.72, half * 0.72),
          paint,
        );
      case GlyphKind.plus:
        canvas.drawLine(
          Offset(center.dx - half * 0.55, center.dy),
          Offset(center.dx + half * 0.55, center.dy),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy - half * 0.55),
          Offset(center.dx, center.dy + half * 0.55),
          paint,
        );
      case GlyphKind.minus:
        canvas.drawLine(
          Offset(center.dx - half * 0.55, center.dy),
          Offset(center.dx + half * 0.55, center.dy),
          paint,
        );
      case GlyphKind.close:
        canvas.drawLine(
          center.translate(-half * 0.5, -half * 0.5),
          center.translate(half * 0.5, half * 0.5),
          paint,
        );
        canvas.drawLine(
          center.translate(half * 0.5, -half * 0.5),
          center.translate(-half * 0.5, half * 0.5),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.kind != kind || old.color != color;
}

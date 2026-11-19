import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The few glyphs the sketch needs. Drawn rather than font icons so the weight
/// matches the hairlines and no icon font has to be shipped.
enum GlyphKind {
  panel,
  panelRight,
  search,
  plus,
  minus,
  close,
  dropdown,
  loop,
  jump,
  manualLoop,
  keylock,
  chevronRight,
  chevronLeft,
  chevronUp,
  chevronDown,
  settings,
  check,
  play,
  controller,
  output,
}

class Glyph extends StatelessWidget {
  const Glyph(this.kind, {this.size = 16, this.color = T.dim, super.key});

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
      case GlyphKind.dropdown:
        final path = Path()
          ..moveTo(center.dx - half * 0.72, center.dy - half * 0.36)
          ..lineTo(center.dx + half * 0.72, center.dy - half * 0.36)
          ..lineTo(center.dx, center.dy + half * 0.5)
          ..close();
        canvas.drawPath(path, Paint()..color = color);
      case GlyphKind.loop:
        final r = half * 0.62;
        final rect = Rect.fromCircle(center: center, radius: r);
        canvas.drawArc(rect, math.pi * 0.18, math.pi * 1.58, false, paint);
        final tip = center.translate(r * 0.86, -r * 0.50);
        canvas.drawLine(tip, tip.translate(-r * 0.30, -r * 0.08), paint);
        canvas.drawLine(tip, tip.translate(r * 0.08, -r * 0.30), paint);
      case GlyphKind.jump:
        for (var side = -1; side <= 1; side += 2) {
          final x = center.dx + side * half * 0.30;
          canvas.drawLine(
            Offset(x - half * 0.18, center.dy - half * 0.42),
            Offset(x + half * 0.18, center.dy),
            paint,
          );
          canvas.drawLine(
            Offset(x + half * 0.18, center.dy),
            Offset(x - half * 0.18, center.dy + half * 0.42),
            paint,
          );
        }
      case GlyphKind.manualLoop:
        final r = half * 0.42;
        final left = center.dx - r * 1.55;
        final right = center.dx + r * 1.55;
        canvas.drawLine(
          Offset(left, center.dy - r),
          Offset(left, center.dy + r),
          paint,
        );
        canvas.drawLine(
          Offset(left, center.dy - r),
          Offset(left + r * 0.7, center.dy - r),
          paint,
        );
        canvas.drawLine(
          Offset(left, center.dy + r),
          Offset(left + r * 0.7, center.dy + r),
          paint,
        );
        canvas.drawLine(
          Offset(right, center.dy - r),
          Offset(right, center.dy + r),
          paint,
        );
        canvas.drawLine(
          Offset(right, center.dy - r),
          Offset(right - r * 0.7, center.dy - r),
          paint,
        );
        canvas.drawLine(
          Offset(right, center.dy + r),
          Offset(right - r * 0.7, center.dy + r),
          paint,
        );
      case GlyphKind.keylock:
        final body = Rect.fromLTRB(
          center.dx - half * 0.42,
          center.dy - half * 0.10,
          center.dx + half * 0.42,
          center.dy + half * 0.62,
        );
        canvas.drawRect(body, paint);
        canvas.drawArc(
          Rect.fromLTRB(
            center.dx - half * 0.30,
            center.dy - half * 0.62,
            center.dx + half * 0.30,
            center.dy + half * 0.06,
          ),
          math.pi,
          math.pi,
          false,
          paint,
        );
        canvas.drawLine(
          Offset(center.dx, body.top),
          Offset(center.dx, body.top + body.height * 0.5),
          paint,
        );
      case GlyphKind.chevronRight:
        _chevron(canvas, paint, center, half, 1, 0);
      case GlyphKind.chevronLeft:
        _chevron(canvas, paint, center, half, -1, 0);
      case GlyphKind.chevronUp:
        _chevron(canvas, paint, center, half, 0, -1);
      case GlyphKind.chevronDown:
        _chevron(canvas, paint, center, half, 0, 1);
      case GlyphKind.settings:
        for (var i = 0; i < 3; i++) {
          final y = size.height * (0.28 + 0.22 * i);
          canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), paint);
          final x = size.width * (i == 1 ? 0.64 : 0.38);
          canvas.drawLine(Offset(x, y - 2.5), Offset(x, y + 2.5), paint);
        }
      case GlyphKind.check:
        final check = Path()
          ..moveTo(size.width * 0.22, size.height * 0.52)
          ..lineTo(size.width * 0.42, size.height * 0.72)
          ..lineTo(size.width * 0.78, size.height * 0.30);
        canvas.drawPath(check, paint);
      case GlyphKind.play:
        final play = Path()
          ..moveTo(center.dx - half * 0.38, center.dy - half * 0.60)
          ..lineTo(center.dx + half * 0.56, center.dy)
          ..lineTo(center.dx - half * 0.38, center.dy + half * 0.60)
          ..close();
        canvas.drawPath(play, Paint()..color = color);
      case GlyphKind.controller:
        final body = Rect.fromLTRB(
          center.dx - half * 0.72,
          center.dy - half * 0.40,
          center.dx + half * 0.72,
          center.dy + half * 0.40,
        );
        canvas.drawRect(body, paint);
        canvas.drawCircle(
          Offset(center.dx - half * 0.30, center.dy),
          half * 0.18,
          paint,
        );
        canvas.drawCircle(
          Offset(center.dx + half * 0.30, center.dy),
          half * 0.18,
          paint,
        );
      case GlyphKind.output:
        for (var i = 0; i < 3; i++) {
          final x = center.dx - half * 0.42 + i * half * 0.42;
          canvas.drawLine(
            Offset(x, center.dy - half * 0.52),
            Offset(x, center.dy + half * 0.52),
            paint,
          );
        }
        canvas.drawArc(
          Rect.fromLTRB(
            center.dx + half * 0.12,
            center.dy - half * 0.60,
            center.dx + half * 0.72,
            center.dy + half * 0.60,
          ),
          -math.pi / 2,
          math.pi,
          false,
          paint,
        );
    }
  }

  void _chevron(
    Canvas canvas,
    Paint paint,
    Offset center,
    double half,
    int dx,
    int dy,
  ) {
    final dir = Offset(dx.toDouble(), dy.toDouble());
    final perp = Offset(-dir.dy, dir.dx);
    final tip = center + dir * (half * 0.34);
    final back = center - dir * (half * 0.26);
    final wing = perp * (half * 0.40);
    canvas.drawLine(back + wing, tip, paint);
    canvas.drawLine(back - wing, tip, paint);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.kind != kind || old.color != color;
}

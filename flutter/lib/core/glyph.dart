import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/theme.dart';

/// The few glyphs the sketch needs. Drawn rather than font icons so the weight
/// matches the hairlines and no icon font has to be shipped.
///
/// Every shape is authored on a 24×24 grid with one stroke weight, round caps and
/// round joins; the painter scales that grid to the requested size. Mixing a new
/// glyph in means drawing it on the same grid, not nudging coordinates until it
/// looks right at one size.
enum GlyphKind {
  // Window and navigation.
  panel,
  panelRight,
  search,
  plus,
  minus,
  close,
  dropdown,
  chevronRight,
  chevronLeft,
  chevronUp,
  chevronDown,
  caretRight,
  caretDown,
  check,
  refresh,

  // Menu and settings.
  settings,
  controller,
  output,
  mixer,
  library,
  folder,
  folderFilled,
  usb,
  analyse,
  list,
  track,
  logs,
  audio,
  trash,

  // Deck count.
  decks2,
  decks3,
  decks4,

  // Deck controls.
  loop,
  jump,
  manualLoop,
  keylock,
  play,
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
    final unit = size.shortestSide / 24;
    if (unit <= 0) return;
    canvas.save();
    canvas.scale(unit, unit);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (kind) {
      case GlyphKind.panel:
        _rect(canvas, 3, 4, 21, 20, stroke, radius: 2);
        _line(canvas, 9, 4, 9, 20, stroke);
      case GlyphKind.panelRight:
        _rect(canvas, 3, 4, 21, 20, stroke, radius: 2);
        _line(canvas, 15, 4, 15, 20, stroke);
      case GlyphKind.search:
        canvas.drawCircle(const Offset(10.5, 10.5), 5.5, stroke);
        _line(canvas, 14.8, 14.8, 20, 20, stroke);
      case GlyphKind.plus:
        _line(canvas, 12, 5, 12, 19, stroke);
        _line(canvas, 5, 12, 19, 12, stroke);
      case GlyphKind.minus:
        _line(canvas, 5, 12, 19, 12, stroke);
      case GlyphKind.close:
        _line(canvas, 7, 7, 17, 17, stroke);
        _line(canvas, 17, 7, 7, 17, stroke);
      case GlyphKind.dropdown:
        _polygon(canvas, const [
          Offset(6.5, 9.5),
          Offset(17.5, 9.5),
          Offset(12, 16),
        ], fill);
      case GlyphKind.chevronRight:
        _chevron(canvas, stroke, 1, 0);
      case GlyphKind.chevronLeft:
        // A real back arrow, not a chevron: shaft plus a heavier head.
        final back = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        _line(canvas, 19.5, 12, 5.5, 12, back);
        _polyline(canvas, const [
          Offset(11.5, 5.5),
          Offset(5, 12),
          Offset(11.5, 18.5),
        ], back);
      case GlyphKind.chevronUp:
        _chevron(canvas, stroke, 0, -1);
      case GlyphKind.chevronDown:
        _chevron(canvas, stroke, 0, 1);
      case GlyphKind.caretRight:
        _polygon(canvas, const [
          Offset(9, 6),
          Offset(9, 18),
          Offset(18, 12),
        ], fill);
      case GlyphKind.caretDown:
        _polygon(canvas, const [
          Offset(6, 9),
          Offset(18, 9),
          Offset(12, 18),
        ], fill);
      case GlyphKind.check:
        final bold = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        _polyline(canvas, const [
          Offset(4.5, 12.5),
          Offset(9.5, 18),
          Offset(19.5, 6),
        ], bold);
      case GlyphKind.refresh:
        final rect = Rect.fromCircle(center: const Offset(12, 12), radius: 6.6);
        final start = math.pi * 0.35;
        final sweep = math.pi * 1.5;
        final end = start + sweep;
        final refreshStroke = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(rect, start, sweep, false, refreshStroke);
        final point =
            const Offset(12, 12) + Offset(math.cos(end), math.sin(end)) * 6.6;
        final tangent = Offset(-math.sin(end), math.cos(end));
        final normal = Offset(math.cos(end), math.sin(end));
        _polygon(canvas, [
          point + tangent * 1.8,
          point - tangent * 1.2 + normal * 2.0,
          point - tangent * 1.2 - normal * 2.0,
        ], fill);
      case GlyphKind.settings:
        canvas.drawPath(_gearPath(), fill);
      case GlyphKind.controller:
        _rect(canvas, 3, 7, 21, 17, stroke, radius: 4);
        _line(canvas, 7.5, 12, 10.5, 12, stroke);
        _line(canvas, 9, 10.5, 9, 13.5, stroke);
        canvas.drawCircle(const Offset(15.5, 11), 1.2, fill);
        canvas.drawCircle(const Offset(18, 13.5), 1.2, fill);
      case GlyphKind.output:
        _polyline(canvas, const [
          Offset(4, 10.5),
          Offset(8, 10.5),
          Offset(12, 6),
          Offset(12, 18),
          Offset(8, 13.5),
          Offset(4, 13.5),
          Offset(4, 10.5),
        ], stroke);
        canvas.drawArc(
          const Rect.fromLTRB(12, 7.5, 18, 16.5),
          -math.pi / 2.8,
          math.pi / 1.4,
          false,
          stroke,
        );
        canvas.drawArc(
          const Rect.fromLTRB(13.5, 5, 22, 19),
          -math.pi / 2.8,
          math.pi / 1.4,
          false,
          stroke,
        );
      case GlyphKind.mixer:
        _line(canvas, 7.5, 5, 7.5, 19, stroke);
        _rect(canvas, 5, 8, 10, 11, fill, radius: 1);
        _line(canvas, 16.5, 5, 16.5, 19, stroke);
        _rect(canvas, 14, 13, 19, 16, fill, radius: 1);
        _line(canvas, 3.5, 19, 20.5, 19, stroke);
      case GlyphKind.library:
        _rect(canvas, 5, 7, 8.5, 20, stroke, radius: 1);
        _rect(canvas, 10.25, 4, 13.75, 20, stroke, radius: 1);
        _rect(canvas, 15.5, 9, 19, 20, stroke, radius: 1);
      case GlyphKind.folder:
        _polyline(canvas, const [
          Offset(3, 7),
          Offset(9.5, 7),
          Offset(12, 9.5),
          Offset(21, 9.5),
          Offset(21, 19),
          Offset(3, 19),
          Offset(3, 7),
        ], stroke);
      case GlyphKind.folderFilled:
        _polygon(canvas, const [
          Offset(3, 7),
          Offset(9.5, 7),
          Offset(12, 9.5),
          Offset(21, 9.5),
          Offset(21, 19),
          Offset(3, 19),
        ], fill);
      case GlyphKind.usb:
        // A solid USB stick silhouette: wide body, short plug on the right.
        final usb = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTRB(3, 6.5, 17, 17.5),
              const Radius.circular(1.8),
            ),
          )
          ..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTRB(17, 9, 21, 15),
              const Radius.circular(0.8),
            ),
          );
        canvas.drawPath(usb, fill);
      case GlyphKind.analyse:
        _star(canvas, const Offset(11, 11.5), 6.5, stroke);
        _star(canvas, const Offset(18.5, 6), 2.4, stroke);
      case GlyphKind.list:
        canvas.drawCircle(const Offset(5, 7), 1.2, fill);
        canvas.drawCircle(const Offset(5, 12), 1.2, fill);
        canvas.drawCircle(const Offset(5, 17), 1.2, fill);
        _line(canvas, 8.5, 7, 20, 7, stroke);
        _line(canvas, 8.5, 12, 20, 12, stroke);
        _line(canvas, 8.5, 17, 20, 17, stroke);
      case GlyphKind.track:
        canvas.drawCircle(const Offset(8.5, 17.5), 3, stroke);
        _line(canvas, 11.5, 17.5, 11.5, 5.5, stroke);
        _polyline(canvas, const [
          Offset(11.5, 5.5),
          Offset(19, 7.5),
          Offset(19, 11.5),
        ], stroke);
      case GlyphKind.logs:
        _rect(canvas, 3.5, 4.5, 20.5, 19.5, stroke, radius: 2);
        _polyline(canvas, const [
          Offset(7, 9),
          Offset(10.5, 12),
          Offset(7, 15),
        ], stroke);
        _line(canvas, 13, 15, 17.5, 15, stroke);
      case GlyphKind.audio:
        _line(canvas, 3, 12, 5.5, 12, stroke);
        _line(canvas, 5.5, 12, 8, 6.5, stroke);
        _line(canvas, 8, 6.5, 11, 17.5, stroke);
        _line(canvas, 11, 17.5, 14, 9, stroke);
        _line(canvas, 14, 9, 17, 15, stroke);
        _line(canvas, 17, 15, 19.5, 12, stroke);
        _line(canvas, 19.5, 12, 21, 12, stroke);
      case GlyphKind.trash:
        _line(canvas, 4.5, 7, 19.5, 7, stroke);
        _line(canvas, 9, 4.5, 15, 4.5, stroke);
        _polyline(canvas, const [
          Offset(6.5, 7),
          Offset(7.5, 20),
          Offset(16.5, 20),
          Offset(17.5, 7),
        ], stroke);
        _line(canvas, 10, 10.5, 10, 16.5, stroke);
        _line(canvas, 14, 10.5, 14, 16.5, stroke);
      case GlyphKind.decks2:
        _faders(canvas, 2, stroke, fill);
      case GlyphKind.decks3:
        _faders(canvas, 3, stroke, fill);
      case GlyphKind.decks4:
        _faders(canvas, 4, stroke, fill);
      case GlyphKind.loop:
        canvas.drawArc(
          const Rect.fromLTRB(4.5, 4.5, 19.5, 19.5),
          math.pi * 0.18,
          math.pi * 1.58,
          false,
          stroke,
        );
        _polyline(canvas, const [
          Offset(17.4, 3.4),
          Offset(20.2, 5.2),
          Offset(17.2, 6.8),
        ], stroke);
      case GlyphKind.jump:
        _polyline(canvas, const [
          Offset(5, 7),
          Offset(10, 12),
          Offset(5, 17),
        ], stroke);
        _polyline(canvas, const [
          Offset(12, 7),
          Offset(17, 12),
          Offset(12, 17),
        ], stroke);
      case GlyphKind.manualLoop:
        _polyline(canvas, const [
          Offset(8, 7),
          Offset(5, 7),
          Offset(5, 17),
          Offset(8, 17),
        ], stroke);
        _polyline(canvas, const [
          Offset(16, 7),
          Offset(19, 7),
          Offset(19, 17),
          Offset(16, 17),
        ], stroke);
      case GlyphKind.keylock:
        _rect(canvas, 7.5, 11, 16.5, 19.5, stroke, radius: 1.5);
        canvas.drawArc(
          const Rect.fromLTRB(9, 3.5, 15, 11.5),
          math.pi,
          math.pi,
          false,
          stroke,
        );
        _line(canvas, 12, 14, 12, 16.5, stroke);
      case GlyphKind.play:
        _polygon(canvas, const [
          Offset(8, 5),
          Offset(19, 12),
          Offset(8, 19),
        ], fill);
    }
    canvas.restore();
  }

  void _line(Canvas canvas, double x1, double y1, double x2, double y2, Paint p) =>
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), p);

  void _rect(
    Canvas canvas,
    double left,
    double top,
    double right,
    double bottom,
    Paint p, {
    double radius = 0,
  }) {
    final rect = Rect.fromLTRB(left, top, right, bottom);
    if (radius > 0) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), p);
    } else {
      canvas.drawRect(rect, p);
    }
  }

  void _polyline(Canvas canvas, List<Offset> points, Paint p) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, p);
  }

  void _polygon(Canvas canvas, List<Offset> points, Paint p) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  void _chevron(Canvas canvas, Paint p, int dx, int dy, {double size = 6.5}) {
    final tip = Offset(12 + dx * size, 12 + dy * size);
    final back = Offset(12 - dx * size * 0.55, 12 - dy * size * 0.55);
    final wing = Offset(-dy * size * 0.7, dx * size * 0.7);
    canvas.drawLine(back + wing, tip, p);
    canvas.drawLine(back - wing, tip, p);
  }

  /// Eight square teeth with a round centre hole, filled with the even-odd rule.
  Path _gearPath() {
    const center = Offset(12, 12);
    const outer = 9.2;
    const valley = 6.9;
    const hole = 2.6;
    const teeth = 8;
    final step = math.pi * 2 / teeth;
    final tooth = step * 0.20;
    final root = step * 0.32;
    Offset point(double angle, double radius) =>
        center + Offset(math.cos(angle), math.sin(angle)) * radius;
    final path = Path();
    for (var i = 0; i < teeth; i++) {
      final a = i * step;
      final points = [
        point(a - tooth, outer),
        point(a + tooth, outer),
        point(a + root, valley),
        point(a + step - root, valley),
      ];
      if (i == 0) {
        path.moveTo(points.first.dx, points.first.dy);
      } else {
        path.lineTo(points.first.dx, points.first.dy);
      }
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    path.addOval(Rect.fromCircle(center: center, radius: hole));
    path.fillType = PathFillType.evenOdd;
    return path;
  }

  /// Four-point sparkle used for the browser's analyse action.
  void _star(Canvas canvas, Offset center, double radius, Paint p) {
    final inner = radius * 0.28;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + inner, center.dy - inner)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx + inner, center.dy + inner)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - inner, center.dy + inner)
      ..lineTo(center.dx - radius, center.dy)
      ..lineTo(center.dx - inner, center.dy - inner)
      ..close();
    canvas.drawPath(path, p);
  }

  /// Two to four fader stems, the same shape as the brand mark.
  void _faders(Canvas canvas, int count, Paint stroke, Paint fill) {
    const left = 4.0;
    const right = 20.0;
    final gap = count <= 1 ? 0.0 : (right - left) / (count * 2 - 1);
    final width = gap;
    for (var index = 0; index < count; index++) {
      final x = left + index * width * 2 + width / 2;
      _line(canvas, x, 5.5, x, 18.5, stroke);
      _rect(canvas, x - width * 0.55, 8.5, x + width * 0.55, 11, fill);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.kind != kind || old.color != color;
}

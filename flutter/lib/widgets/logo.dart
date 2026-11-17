import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The mark: two faders read as a TT, no inner lines, even spacing.
class LogoMark extends StatelessWidget {
  const LogoMark({this.size = 28, this.accent = T.accent, super.key});

  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _LogoPainter(accent));
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final barW = s * 0.30;
    final barH = s * 0.10;
    final stemW = s * 0.10;
    final gap = s * 0.12;
    final left = (s - (barW * 2 + gap)) / 2;
    final top = s * 0.18;
    final bottom = s * 0.82;
    final white = Paint()..color = T.text;
    final blue = Paint()..color = accent;

    for (var i = 0; i < 2; i++) {
      final x = left + i * (barW + gap);
      final body = i == 0 ? blue : white;
      canvas.drawRect(Rect.fromLTWH(x, top, barW, barH), body);
      canvas.drawRect(
        Rect.fromLTWH(
          x + barW / 2 - stemW / 2,
          top + barH,
          stemW,
          bottom - top - barH,
        ),
        body,
      );
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.accent != accent;
}

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The mark: two faders read as a TT, inside a square.
class LogoMark extends StatelessWidget {
  const LogoMark({this.size = 28, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _LogoPainter(),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final paint = Paint()..color = T.text;
    final accentPaint = Paint()..color = T.accent;

    final barW = s * 0.36;
    final barH = s * 0.13;
    final stemW = s * 0.11;
    final gap = s * 0.10;
    final left = (s - (barW * 2 + gap)) / 2;
    final top = s * 0.20;
    final bottom = s * 0.84;

    for (var i = 0; i < 2; i++) {
      final x = left + i * (barW + gap);
      final body = i == 0 ? accentPaint : paint;
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
  bool shouldRepaint(_LogoPainter old) => false;
}

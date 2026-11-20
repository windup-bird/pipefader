import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/theme.dart';

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

/// One fader per deck, the mark's two-fader shape scaled out: a thin stem with
/// a wide handle. A sounding deck rides its handle high; a silent one drops it
/// low. When no deck is making sound every handle rests at the top, so the mark
/// still reads as the brand at rest. The leader is the accent, the rest grey.
class LogoFaders extends StatelessWidget {
  const LogoFaders({
    required this.sounding,
    required this.leader,
    this.size = 28,
    super.key,
  });

  /// One entry per deck: true when that deck is producing sound. A sounding
  /// deck puts its handle near the top, a silent one drops it to the bottom.
  final List<bool> sounding;

  /// Index of the leader, or -1 when no deck is playing.
  final int leader;

  final double size;

  @override
  Widget build(BuildContext context) {
    // Fixed fader geometry from the two-deck mark; more decks widen the whole
    // mark instead of squeezing each fader. Height drives the size, width grows
    // with the count.
    final s = size;
    final count = sounding.isEmpty ? 1 : sounding.length;
    final w = s * (_barRatio * count + _gapRatio * (count - 1));
    return CustomPaint(
      size: Size(w, s),
      painter: _LogoFadersPainter(sounding, leader),
    );
  }

  /// Handle width and gap as fractions of the height, taken from the two-deck
  /// mark so every deck count reuses that proportion.
  static const double _barRatio = 0.39;
  static const double _gapRatio = 0.12;
}

class _LogoFadersPainter extends CustomPainter {
  _LogoFadersPainter(this.sounding, this.leader);

  final List<bool> sounding;
  final int leader;

  @override
  void paint(Canvas canvas, Size size) {
    final count = sounding.isEmpty ? 1 : sounding.length;
    final s = size.height;
    final anySounding = sounding.any((on) => on);
    // Fixed proportions: each fader keeps the two-deck width, the gaps stay
    // even, and the group is centred in the (wider) box.
    final faderW = s * LogoFaders._barRatio;
    final gap = s * LogoFaders._gapRatio;
    final totalW = faderW * count + gap * (count - 1);
    final left = (size.width - totalW) / 2;
    final top = s * 0.16;
    final bottom = s * 0.84;
    final stemW = faderW * 0.26;
    final handleH = faderW * 0.30;
    final travel = bottom - top - handleH;

    for (var i = 0; i < count; i++) {
      final x = left + i * (faderW + gap);
      final color = i == leader ? T.accent : T.faint;
      final centreX = x + faderW / 2;
      // The stem: a thin vertical bar the full height.
      canvas.drawRect(
        Rect.fromLTWH(centreX - stemW / 2, top, stemW, bottom - top),
        Paint()..color = color.withValues(alpha: i == leader ? 0.5 : 0.32),
      );
      // The handle: a wide horizontal bar. Sounding rides near the top; when
      // no deck is making sound every handle rests at the top as a mark.
      final on = !anySounding || (sounding.isEmpty ? true : sounding[i]);
      final handleTop = on ? top : top + travel;
      canvas.drawRect(
        Rect.fromLTWH(x, handleTop, faderW, handleH),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_LogoFadersPainter old) =>
      old.leader != leader ||
      old.sounding.length != sounding.length ||
      !_sameSounding(old.sounding, sounding);

  bool _sameSounding(List<bool> a, List<bool> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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

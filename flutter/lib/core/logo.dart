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
/// a wide handle. Each handle follows its deck's channel fader, from the bottom
/// at 0 to the top at 1, so the mark reads as the mixer rather than the
/// transport. The leader is the accent, the rest grey.
class LogoFaders extends StatelessWidget {
  const LogoFaders({
    required this.levels,
    required this.leader,
    this.size = 28,
    super.key,
  });

  /// One entry per deck: 0 puts the handle at the bottom, anything above 0 at
  /// the top. An empty list draws a single resting fader at the top.
  final List<double> levels;

  /// Index of the leader, or -1 when no deck is playing.
  final int leader;

  final double size;

  @override
  Widget build(BuildContext context) {
    // Fixed fader geometry from the two-deck mark; more decks widen the whole
    // mark instead of squeezing each fader. Height drives the size, width grows
    // with the count.
    final s = size;
    final count = levels.isEmpty ? 1 : levels.length;
    final w = widthFor(s, count);
    final target = _Levels(levels);
    return TweenAnimationBuilder<_Levels>(
      tween: _LevelsTween(begin: target, end: target),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => CustomPaint(
        size: Size(w, s),
        painter: _LogoFadersPainter(animated.values, leader),
      ),
    );
  }

  /// The natural width of [count] faders at [size] high. The menu's fly-in target uses the same
  /// number as the painter, so the mark does not jump when the animation lands.
  static double widthFor(double size, int count) =>
      size * (_barRatio * count + _gapRatio * (count - 1));

  /// Handle width and gap as fractions of the height, taken from the two-deck
  /// mark so every deck count reuses that proportion.
  static const double _barRatio = 0.39;
  static const double _gapRatio = 0.12;
}

/// The tween compares by value, so a model tick that leaves the faders alone
/// does not restart the chase animation.
@immutable
class _Levels {
  const _Levels(this.values);

  final List<double> values;

  @override
  bool operator ==(Object other) {
    if (other is! _Levels || other.values.length != values.length) {
      return false;
    }
    for (var i = 0; i < values.length; i++) {
      if (values[i] != other.values[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(values);
}

/// Chases a moving fader instead of snapping. A deck count change cannot be
/// interpolated across lengths, so the new list lands in one step.
class _LevelsTween extends Tween<_Levels> {
  _LevelsTween({super.begin, super.end});

  @override
  _Levels lerp(double t) {
    final from = begin?.values;
    final to = end?.values;
    if (from == null) return _Levels(to ?? const <double>[]);
    if (to == null) return _Levels(from);
    if (from.length != to.length) return _Levels(to);
    return _Levels([
      for (var i = 0; i < to.length; i++)
        from[i] + (to[i] - from[i]) * t,
    ]);
  }
}

class _LogoFadersPainter extends CustomPainter {
  _LogoFadersPainter(this.levels, this.leader);

  final List<double> levels;
  final int leader;

  @override
  void paint(Canvas canvas, Size size) {
    final count = levels.isEmpty ? 1 : levels.length;
    final s = size.height;
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
      // The handle: a wide horizontal bar at the deck's fader position.
      final level = levels.isEmpty ? 1.0 : levels[i].clamp(0.0, 1.0);
      final handleTop = top + travel * (1 - level);
      canvas.drawRect(
        Rect.fromLTWH(x, handleTop, faderW, handleH),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_LogoFadersPainter old) =>
      old.leader != leader ||
      old.levels.length != levels.length ||
      !_sameLevels(old.levels, levels);

  bool _sameLevels(List<double> a, List<double> b) {
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

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';

/// The scrolling waveform: two channels around a centre line, three bands
/// layered from the centre out, the beat grid over the top, playhead pinned to
/// the middle — the terminal's view, at pixel resolution.
// Keep the configured band hues, but blend them toward the UI's muted palette.
Color _bandColor(int? argb, Color tint) => argb == null || argb == 0
    ? tint
    : Color.lerp(tint, Color(argb), T.waveTintStrength)!;

class Waveform extends StatelessWidget {
  const Waveform({
    required this.deck,
    required this.framesPerPixel,
    this.palette,
    super.key,
  });

  final DeckRuntime deck;
  final double framesPerPixel;
  final WavePaletteData? palette;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _WaveformPainter(
        framesPerPixel: framesPerPixel,
        frame: deck.frame,
        view: deck.view,
        overlay: deck.wave,
        strip: deck.strip,
        palette: palette,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.framesPerPixel,
    required this.frame,
    required this.view,
    required this.overlay,
    required this.strip,
    required this.palette,
  });

  final double framesPerPixel;
  final int frame;
  final DeckView view;
  final WaveOverlay? overlay;
  final WaveStripData? strip;
  final WavePaletteData? palette;

  Color _color(int argb, Color fallback) =>
      palette == null ? fallback : Color(argb);

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (width <= 0 || height <= 0) return;
    final centre = height / 2;
    final fpp = math.max(framesPerPixel, 1.0);
    final hints = overlay;
    final start = hints?.startFrame ?? (frame - width / 2 * fpp);

    // TUI order: loop wash, beat grid, waveform, cue lines, playhead. Each
    // later layer wins, so the waveform never hides a cue.
    if (hints != null) {
      _paintLoop(canvas, size, hints);
      _paintBeats(canvas, size, hints);
    }

    canvas.drawLine(
      Offset(0, centre),
      Offset(width, centre),
      Paint()
        ..color = _color(palette?.center ?? 0, T.text.withValues(alpha: 0.06)),
    );

    final strip = this.strip;
    if (strip != null &&
        (strip.framesPerPixel - fpp).abs() < 0.01 &&
        strip.columns > 1) {
      _paintStrip(canvas, size, strip, start, fpp);
    } else {
      _paintWave(canvas, size, frame, fpp, start);
    }

    if (hints != null) _paintCues(canvas, size, hints);

    final playheadX = width / 2;
    final playhead = _color(palette?.playhead ?? 0, T.playhead);
    canvas.drawRect(
      Rect.fromLTWH(playheadX - 3, 0, 6, height),
      Paint()..color = playhead.withValues(alpha: 0.10),
    );
    canvas.drawRect(
      Rect.fromLTWH(playheadX - 0.5, 0, 1, height),
      Paint()..color = playhead,
    );
  }

  void _paintLoop(Canvas canvas, Size size, WaveOverlay hints) {
    final start = hints.loopStart;
    final end = hints.loopEnd;
    if (start == null || end == null) return;
    final left = math.min(start, end).clamp(0.0, size.width);
    final right = math.max(start, end).clamp(0.0, size.width);
    if (right <= left) return;
    canvas.drawRect(
      Rect.fromLTRB(left, 0, right, size.height),
      Paint()..color = _color(palette?.loopWash ?? 0, const Color(0x55464646)),
    );
  }

  void _paintBeats(Canvas canvas, Size size, WaveOverlay hints) {
    final beatPaint = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.butt
      ..color = _color(palette?.beat ?? 0, T.beat);
    for (final x in hints.beats) {
      if (x < 0 || x > size.width) continue;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), beatPaint);
    }
    final barPaint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt
      ..color = _color(palette?.bar ?? 0, T.bar);
    for (final x in hints.bars) {
      if (x < 0 || x > size.width) continue;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), barPaint);
    }
  }

  void _paintCues(Canvas canvas, Size size, WaveOverlay hints) {
    final armed = hints.loopArmed;
    if (armed != null && armed >= 0 && armed <= size.width) {
      canvas.drawLine(
        Offset(armed, 0),
        Offset(armed, size.height),
        Paint()
          ..strokeWidth = 1
          ..color = T.accent.withValues(alpha: 0.8),
      );
    }
    final cue = hints.cue;
    if (cue != null && cue >= 0 && cue <= size.width) {
      canvas.drawLine(
        Offset(cue, 0),
        Offset(cue, size.height),
        Paint()
          ..strokeWidth = 2
          ..color = _color(palette?.memoryCue ?? 0, T.text),
      );
    }
    for (final hot in hints.hotCues) {
      if (hot.column < 0 || hot.column > size.width) continue;
      canvas.drawLine(
        Offset(hot.column, 0),
        Offset(hot.column, size.height),
        Paint()
          ..strokeWidth = 2
          ..color = palette != null
              ? Color(palette!.hotCues[hot.slot % palette!.hotCues.length])
              : T.padCueColors[hot.slot % T.padCueColors.length],
      );
    }
  }

  void _paintStrip(
    Canvas canvas,
    Size size,
    WaveStripData strip,
    double viewStart,
    double fpp,
  ) {
    final width = size.width;
    final centre = size.height / 2;
    final extent = centre - 3;
    final x0 = (strip.startFrame - viewStart) / fpp;
    final leftLow = Path();
    final leftMid = Path();
    final leftHigh = Path();
    final rightLow = Path();
    final rightMid = Path();
    final rightHigh = Path();
    var started = false;
    var lastX = 0.0;
    for (var i = 0; i < strip.columns; i++) {
      final x = x0 + i;
      if (x < -1) continue;
      if (x > width + 1) break;
      if (!started) {
        leftLow.moveTo(x, centre);
        leftMid.moveTo(x, centre);
        leftHigh.moveTo(x, centre);
        rightLow.moveTo(x, centre);
        rightMid.moveTo(x, centre);
        rightHigh.moveTo(x, centre);
        started = true;
      }
      leftLow.lineTo(x, centre - strip.leftLow[i] * extent);
      leftMid.lineTo(x, centre - strip.leftMid[i] * extent);
      leftHigh.lineTo(x, centre - strip.leftHigh[i] * extent);
      rightLow.lineTo(x, centre + strip.rightLow[i] * extent);
      rightMid.lineTo(x, centre + strip.rightMid[i] * extent);
      rightHigh.lineTo(x, centre + strip.rightHigh[i] * extent);
      lastX = x;
    }
    if (!started) return;
    leftLow
      ..lineTo(lastX, centre)
      ..close();
    leftMid
      ..lineTo(lastX, centre)
      ..close();
    leftHigh
      ..lineTo(lastX, centre)
      ..close();
    rightLow
      ..lineTo(lastX, centre)
      ..close();
    rightMid
      ..lineTo(lastX, centre)
      ..close();
    rightHigh
      ..lineTo(lastX, centre)
      ..close();

    final low = _bandColor(palette?.low, T.waveLo);
    final mid = _bandColor(palette?.mid, T.waveMid);
    final high = _bandColor(palette?.high, T.waveHi);
    canvas.drawPath(leftLow, Paint()..color = low);
    canvas.drawPath(rightLow, Paint()..color = low);
    canvas.drawPath(leftMid, Paint()..color = mid);
    canvas.drawPath(rightMid, Paint()..color = mid);
    canvas.drawPath(leftHigh, Paint()..color = high);
    canvas.drawPath(rightHigh, Paint()..color = high);
  }

  void _paintWave(
    Canvas canvas,
    Size size,
    int frame,
    double fpp,
    double start,
  ) {
    if (view.totalFrames <= 0 || view.bpm <= 0) return;
    if (frame < 0 || frame > view.totalFrames) return;
    final peaks = view.peaks;
    if (peaks.length < 2) return;
    final width = size.width;
    final centre = size.height / 2;
    final extent = centre - 3;
    final bucketFrames = view.totalFrames / peaks.length;

    final leftLow = Path()..moveTo(0, centre);
    final leftMid = Path()..moveTo(0, centre);
    final leftHigh = Path()..moveTo(0, centre);
    final rightLow = Path()..moveTo(0, centre);
    final rightMid = Path()..moveTo(0, centre);
    final rightHigh = Path()..moveTo(0, centre);

    for (var x = 0.0; x <= width; x += 1) {
      final source = start + x * fpp;
      if (source < 0 || source > view.totalFrames) {
        leftLow.lineTo(x, centre);
        leftMid.lineTo(x, centre);
        leftHigh.lineTo(x, centre);
        rightLow.lineTo(x, centre);
        rightMid.lineTo(x, centre);
        rightHigh.lineTo(x, centre);
        continue;
      }
      final from = (source / bucketFrames).floor().clamp(0, peaks.length - 1);
      final to = math
          .min(peaks.length, ((source + fpp) / bucketFrames).ceil())
          .clamp(from + 1, peaks.length);
      var lLow = 0.0, lMid = 0.0, lHigh = 0.0;
      var rLow = 0.0, rMid = 0.0, rHigh = 0.0;
      for (var i = from; i < to; i++) {
        lLow = math.max(lLow, peaks.leftLow[i]);
        lMid = math.max(lMid, peaks.leftMid[i]);
        lHigh = math.max(lHigh, peaks.leftHigh[i]);
        rLow = math.max(rLow, peaks.rightLow[i]);
        rMid = math.max(rMid, peaks.rightMid[i]);
        rHigh = math.max(rHigh, peaks.rightHigh[i]);
      }
      leftLow.lineTo(x, centre - lLow * extent);
      leftMid.lineTo(x, centre - lMid * extent);
      leftHigh.lineTo(x, centre - lHigh * extent);
      rightLow.lineTo(x, centre + rLow * extent);
      rightMid.lineTo(x, centre + rMid * extent);
      rightHigh.lineTo(x, centre + rHigh * extent);
    }
    leftLow
      ..lineTo(width, centre)
      ..close();
    leftMid
      ..lineTo(width, centre)
      ..close();
    leftHigh
      ..lineTo(width, centre)
      ..close();
    rightLow
      ..lineTo(width, centre)
      ..close();
    rightMid
      ..lineTo(width, centre)
      ..close();
    rightHigh
      ..lineTo(width, centre)
      ..close();

    final low = _bandColor(palette?.low, T.waveLo);
    final mid = _bandColor(palette?.mid, T.waveMid);
    final high = _bandColor(palette?.high, T.waveHi);
    canvas.drawPath(leftLow, Paint()..color = low);
    canvas.drawPath(rightLow, Paint()..color = low);
    canvas.drawPath(leftMid, Paint()..color = mid);
    canvas.drawPath(rightMid, Paint()..color = mid);
    canvas.drawPath(leftHigh, Paint()..color = high);
    canvas.drawPath(rightHigh, Paint()..color = high);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.frame != frame ||
      old.framesPerPixel != framesPerPixel ||
      old.view != view ||
      old.overlay != overlay ||
      old.strip != strip ||
      old.palette != palette;
}

/// The whole track at a glance, under the title: the two channels are folded
/// onto each other, the result normalised to the loudest column and pushed
/// through the TUI's S-curve, then the three bands are stacked. Played is lit,
/// the rest stays a quiet silhouette.
class Overview extends StatelessWidget {
  const Overview({
    required this.deck,
    required this.frame,
    this.cueFrame = 0,
    this.loopIn = 0,
    this.loopOut = 0,
    this.hotCueFrames = const <int, int>{},
    this.palette,
    super.key,
  });

  final DeckView deck;
  final double frame;
  final int cueFrame;
  final int loopIn;
  final int loopOut;
  final Map<int, int> hotCueFrames;
  final WavePaletteData? palette;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _OverviewPainter(
        deck,
        frame,
        cueFrame: cueFrame,
        loopIn: loopIn,
        loopOut: loopOut,
        hotCueFrames: hotCueFrames,
        palette: palette,
      ),
    );
  }
}

class _OverviewPainter extends CustomPainter {
  _OverviewPainter(
    this.deck,
    this.frame, {
    this.cueFrame = 0,
    this.loopIn = 0,
    this.loopOut = 0,
    this.hotCueFrames = const <int, int>{},
    this.palette,
  });

  final DeckView deck;
  final double frame;
  final int cueFrame;
  final int loopIn;
  final int loopOut;
  final Map<int, int> hotCueFrames;
  final WavePaletteData? palette;

  Color _color(int argb, Color fallback) =>
      palette == null ? fallback : Color(argb);

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (width <= 0 || height <= 0) return;
    final peaks = deck.peaks;
    final columns = width.round().clamp(1, 2048);

    final low = Float32List(columns);
    final mid = Float32List(columns);
    final high = Float32List(columns);
    var loudest = 0.0;

    for (var x = 0; x < columns; x++) {
      final from = (x / columns * peaks.length).floor().clamp(
        0,
        peaks.length - 1,
      );
      final to = math
          .min(peaks.length, ((x + 1) / columns * peaks.length).ceil())
          .clamp(from + 1, peaks.length);
      var l = 0.0, m = 0.0, h = 0.0;
      for (var i = from; i < to; i++) {
        l = math.max(l, math.max(peaks.leftLow[i], peaks.rightLow[i]));
        m = math.max(m, math.max(peaks.leftMid[i], peaks.rightMid[i]));
        h = math.max(h, math.max(peaks.leftHigh[i], peaks.rightHigh[i]));
      }
      low[x] = l;
      mid[x] = m;
      high[x] = h;
      loudest = math.max(loudest, l + m + h);
    }
    if (loudest <= 0) return;

    double curve(int x) {
      final value = ((low[x] + mid[x] + high[x]) / loudest).clamp(0.0, 1.0);
      return value * value * (3.0 - 2.0 * value);
    }

    final played = (frame / deck.totalFrames).clamp(0.0, 1.0) * width;
    final step = width / columns;
    final lowH = Float32List(columns);
    final midH = Float32List(columns);
    final highH = Float32List(columns);
    for (var x = 0; x < columns; x++) {
      final sum = low[x] + mid[x] + high[x];
      if (sum <= 0) continue;
      final h = curve(x) * height;
      lowH[x] = h * low[x] / sum;
      midH[x] = h * mid[x] / sum;
      highH[x] = h * high[x] / sum;
    }

    // Three stacked silhouettes, built once and filled twice: dim for the whole
    // track, colour behind the playhead. Paths instead of one rect per column
    // keep a four-deck desk at sixty frames a second.
    final lowPath = Path()..moveTo(0, height);
    for (var x = 0; x < columns; x++) {
      lowPath.lineTo(x * step, height - lowH[x]);
    }
    lowPath
      ..lineTo(width, height)
      ..close();

    final midPath = Path()..moveTo(0, height - lowH[0]);
    for (var x = 0; x < columns; x++) {
      midPath.lineTo(x * step, height - lowH[x] - midH[x]);
    }
    for (var x = columns - 1; x >= 0; x--) {
      midPath.lineTo(x * step, height - lowH[x]);
    }
    midPath.close();

    final highPath = Path()..moveTo(0, height - lowH[0] - midH[0]);
    for (var x = 0; x < columns; x++) {
      highPath.lineTo(x * step, height - lowH[x] - midH[x] - highH[x]);
    }
    for (var x = columns - 1; x >= 0; x--) {
      highPath.lineTo(x * step, height - lowH[x] - midH[x]);
    }
    highPath.close();

    canvas.drawPath(lowPath, Paint()..color = T.surfaceMid);
    canvas.drawPath(midPath, Paint()..color = T.surfaceMid);
    canvas.drawPath(highPath, Paint()..color = T.surfaceMid);

    if (played > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, played, height));
      canvas.drawPath(lowPath, Paint()..color = _bandColor(palette?.low, T.waveLo));
      canvas.drawPath(midPath, Paint()..color = _bandColor(palette?.mid, T.waveMid));
      canvas.drawPath(highPath, Paint()..color = _bandColor(palette?.high, T.waveHi));
      canvas.restore();
    }

    canvas.drawRect(
      Rect.fromLTWH(played - 0.5, 0, 1, height),
      Paint()..color = T.accentHi,
    );

    final total = deck.totalFrames;
    if (total <= 0) return;
    double xOf(int source) =>
        (source / total).clamp(0.0, 1.0) * width;
    if (loopOut > loopIn) {
      canvas.drawRect(
        Rect.fromLTRB(xOf(loopIn), 0, xOf(loopOut), height),
        Paint()..color = _color(palette?.loopWash ?? 0, const Color(0x55464646)),
      );
    }
    if (cueFrame > 0) {
      canvas.drawLine(
        Offset(xOf(cueFrame), 0),
        Offset(xOf(cueFrame), height),
        Paint()
          ..strokeWidth = 2
          ..color = _color(palette?.memoryCue ?? 0, T.text),
      );
    }
    for (final entry in hotCueFrames.entries) {
      final x = xOf(entry.value);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, height),
        Paint()
          ..strokeWidth = 2
          ..color = palette != null
              ? Color(palette!.hotCues[entry.key % palette!.hotCues.length])
              : T.padCueColors[entry.key % T.padCueColors.length],
      );
    }
  }

  @override
  bool shouldRepaint(_OverviewPainter old) =>
      old.frame != frame ||
      old.deck != deck ||
      old.cueFrame != cueFrame ||
      old.loopIn != loopIn ||
      old.loopOut != loopOut ||
      old.hotCueFrames != hotCueFrames ||
      old.palette != palette;
}

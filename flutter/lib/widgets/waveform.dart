import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../model/deck.dart';
import '../state/app_model.dart';
import '../theme.dart';

/// The scrolling waveform: two channels around a centre line, three bands
/// layered from the centre out, the beat grid over the top, playhead pinned to
/// the middle — the terminal's view, at pixel resolution.
class Waveform extends StatelessWidget {
  const Waveform({required this.deck, required this.framesPerPixel, super.key});

  final DeckRuntime deck;
  final double framesPerPixel;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _WaveformPainter(deck: deck, framesPerPixel: framesPerPixel),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.deck, required this.framesPerPixel});

  final DeckRuntime deck;
  final double framesPerPixel;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (width <= 0 || height <= 0) return;
    final centre = height / 2;
    final frame = deck.frame;
    final view = deck.view;
    final fpp = math.max(framesPerPixel, 1.0);
    final start = frame - width / 2 * fpp;

    _paintWave(canvas, size, frame, fpp, start);
    _paintBeats(canvas, size, frame.toDouble(), fpp, view);

    canvas.drawLine(
      Offset(0, centre),
      Offset(width, centre),
      Paint()
        ..color = T.text.withValues(alpha: 0.06)
        ..strokeWidth = 1,
    );

    final playheadX = width / 2;
    canvas.drawRect(
      Rect.fromLTWH(playheadX - 3, 0, 6, height),
      Paint()..color = T.playhead.withValues(alpha: 0.10),
    );
    canvas.drawRect(
      Rect.fromLTWH(playheadX - 0.5, 0, 1, height),
      Paint()..color = T.playhead,
    );
  }

  void _paintWave(
    Canvas canvas,
    Size size,
    int frame,
    double fpp,
    double start,
  ) {
    final view = deck.view;
    if (frame < 0 || frame > view.totalFrames) return;
    final peaks = view.peaks;
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

    canvas.drawPath(leftLow, Paint()..color = T.waveLo);
    canvas.drawPath(rightLow, Paint()..color = T.waveLo);
    canvas.drawPath(leftMid, Paint()..color = T.waveMid);
    canvas.drawPath(rightMid, Paint()..color = T.waveMid);
    canvas.drawPath(leftHigh, Paint()..color = T.waveHi);
    canvas.drawPath(rightHigh, Paint()..color = T.waveHi);
  }

  void _paintBeats(
    Canvas canvas,
    Size size,
    double frame,
    double fpp,
    DeckView view,
  ) {
    final beatFrames = view.beatFrames;
    final width = size.width;
    final start = frame - width / 2 * fpp;
    final end = frame + width / 2 * fpp;
    var index = ((start - view.firstBeat) / beatFrames).floor();
    final paint = Paint()..strokeWidth = 1;
    while (true) {
      final beat = view.firstBeat + index * beatFrames;
      if (beat > end) break;
      if (beat >= start) {
        final x = (beat - frame) / fpp + width / 2;
        final bar = index % 4 == 0;
        paint.color = T.text.withValues(alpha: bar ? 0.16 : 0.07);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      index++;
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.deck.frame != deck.frame ||
      old.framesPerPixel != framesPerPixel ||
      old.deck.view != deck.view;
}

/// The whole track at a glance, under the title: the two channels are folded
/// onto each other, the result normalised to the loudest column and pushed
/// through the TUI's S-curve, then the three bands are stacked. Played is lit,
/// the rest stays a quiet silhouette.
class Overview extends StatelessWidget {
  const Overview({required this.deck, required this.frame, super.key});

  final DeckView deck;
  final double frame;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _OverviewPainter(deck, frame),
    );
  }
}

class _OverviewPainter extends CustomPainter {
  _OverviewPainter(this.deck, this.frame);

  final DeckView deck;
  final double frame;

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
      canvas.drawPath(lowPath, Paint()..color = T.waveLo);
      canvas.drawPath(midPath, Paint()..color = T.waveMid);
      canvas.drawPath(highPath, Paint()..color = T.waveHi);
      canvas.restore();
    }

    canvas.drawRect(
      Rect.fromLTWH(played - 0.5, 0, 1, height),
      Paint()..color = T.accentHi,
    );
  }

  @override
  bool shouldRepaint(_OverviewPainter old) =>
      old.frame != frame || old.deck != deck;
}

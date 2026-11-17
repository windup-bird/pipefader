import 'dart:math' as math;
import 'dart:typed_data';

/// A wave's three bands per channel, normalised to 0..1 and sampled evenly over
/// the whole track. The same shape [library::Waveform] hands the terminal.
class Peaks {
  const Peaks({
    required this.leftLow,
    required this.leftMid,
    required this.leftHigh,
    required this.rightLow,
    required this.rightMid,
    required this.rightHigh,
  });

  final Float32List leftLow;
  final Float32List leftMid;
  final Float32List leftHigh;
  final Float32List rightLow;
  final Float32List rightMid;
  final Float32List rightHigh;

  int get length => leftLow.length;
}

/// Deterministic stand-in for the analyser: a sectioned envelope, a decaying
/// pulse after every beat and a little grain, so the silhouette has the rhythm
/// of a 4/4 track instead of reading as a ribbon of noise.
Peaks buildPeaks({
  required int seed,
  required double seconds,
  required double bpm,
  int buckets = 16384,
}) {
  final rnd = math.Random(seed);
  final bucketsPerBeat = buckets / (seconds * bpm / 60.0);
  final low = Float32List(buckets);
  // One gain per beat, so bars differ instead of repeating the same pulse.
  final beats = (buckets / bucketsPerBeat).ceil() + 2;
  final beatGain = List<double>.generate(
    beats,
    (_) => 0.62 + 0.38 * rnd.nextDouble(),
  );
  final beatDecay = List<double>.generate(
    beats,
    (_) => 3.6 + 1.8 * rnd.nextDouble(),
  );
  for (var i = 0; i < buckets; i++) {
    final t = i / (buckets - 1);
    final env = _envelope(t) * (0.86 + 0.14 * math.sin(i * 0.0007 + seed));
    final phase = bucketsPerBeat <= 0
        ? 0.0
        : (i % bucketsPerBeat) / bucketsPerBeat;
    final beat = bucketsPerBeat <= 0 ? 0 : (i / bucketsPerBeat).floor();
    final pulse =
        0.26 +
        0.74 *
            math.exp(-phase * beatDecay[beat.clamp(0, beatDecay.length - 1)]);
    final hat = phase > 0.47 && phase < 0.56 ? 0.18 : 0.0;
    final gain = beatGain[beat.clamp(0, beatGain.length - 1)];
    final grain = 0.88 + 0.12 * rnd.nextDouble();
    final floor = 0.05 + 0.05 * rnd.nextDouble();
    low[i] = (env * (pulse * gain + hat) * grain + floor * env).clamp(0.0, 1.0);
  }

  final mid = Float32List(buckets);
  final high = Float32List(buckets);
  for (var i = 0; i < buckets; i++) {
    final midGain = 0.28 + 0.26 * rnd.nextDouble();
    final highGain = 0.04 + 0.12 * rnd.nextDouble();
    mid[i] = low[i] * midGain;
    high[i] = mid[i] * highGain;
  }

  return Peaks(
    leftLow: _smooth(low, 1),
    leftMid: _smooth(mid, 1),
    leftHigh: _smooth(high, 1),
    rightLow: _widen(_smooth(low, 1), 0.93),
    rightMid: _widen(_smooth(mid, 1), 0.90),
    rightHigh: _widen(_smooth(high, 1), 0.86),
  );
}

Float32List _smooth(Float32List input, int window) {
  final out = Float32List(input.length);
  for (var i = 0; i < input.length; i++) {
    var sum = 0.0;
    var count = 0;
    for (var d = -window; d <= window; d++) {
      final j = i + d;
      if (j < 0 || j >= input.length) continue;
      sum += input[j];
      count++;
    }
    out[i] = sum / count;
  }
  return out;
}

Float32List _widen(Float32List input, double factor) {
  final out = Float32List(input.length);
  for (var i = 0; i < input.length; i++) {
    out[i] = (input[i] * factor).clamp(0.0, 1.0);
  }
  return out;
}

double _envelope(double t) {
  if (t < 0.10) return 0.22 + t * 1.6;
  if (t < 0.26) return 0.38 + (t - 0.10) / 0.16 * 0.34;
  if (t < 0.30) return 0.72 + (t - 0.26) / 0.04 * 0.26;
  if (t < 0.58) return 0.98;
  if (t < 0.62) return 0.55;
  if (t < 0.66) return 0.55 + (t - 0.62) / 0.04 * 0.45;
  if (t < 0.90) return 1.0;
  if (t < 0.96) return 1.0 - (t - 0.90) / 0.06 * 0.70;
  return 0.30;
}

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

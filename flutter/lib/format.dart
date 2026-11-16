/// Formatting shared by the deck header, the browser and the control band.
String clock(int frames, int sampleRate) {
  final total = frames / sampleRate;
  final minutes = total ~/ 60;
  final seconds = total - minutes * 60;
  final whole = seconds.floor();
  final millis = ((seconds - whole) * 1000).floor();
  return '$minutes:${whole.toString().padLeft(2, '0')}.'
      '${millis.toString().padLeft(3, '0')}';
}

/// The browser writes durations as `4:32`; a fraction of a second is noise in a
/// list.
String shortClock(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}

String bpmText(double bpm) => bpm.toStringAsFixed(1);

String tempoText(double tempo) {
  final percent = (tempo - 1.0) * 100.0;
  final sign = percent >= 0 ? '+' : '';
  return '$sign${percent.toStringAsFixed(1)}%';
}

/// Formatting shared by the deck header, the browser and the control band.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/theme.dart';

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

/// The BPM readout leans green when the deck is sped up, red when slowed, with
/// the strength of the tint following how far tempo has moved from 1.0.
Color bpmColor(double tempo) {
  final delta = tempo - 1.0;
  if (delta.abs() < 0.0005) return T.text;
  final strength = (delta.abs() / 0.08).clamp(0.0, 1.0).toDouble();
  final target = delta > 0 ? T.error : T.padJumpColor;
  return Color.lerp(T.text, target, 0.4 + 0.6 * strength)!;
}

/// Capitalize first letter of each word, except for special all-caps words.
/// Title case without the deck-control exceptions. The menu uses this so a settings row can say
/// "Cue" rather than the transport key's "CUE".
String titleCaseWords(String text) {
  return text
      .split(' ')
      .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

String capitalizeWords(String text) {
  const allCaps = {'cue', 'bpm', 'pad', 'tab'};
  return text
      .split(' ')
      .map((word) {
        if (allCaps.contains(word.toLowerCase())) {
          return word.toUpperCase();
        }
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/theme.dart';

/// The four deck colours, in deck order. Blue, green, cyan, orange — spread far
/// enough apart to read apart on the dark surface.
const List<Color> deckColors = <Color>[
  Color(0xFF4C8DFF),
  Color(0xFF35D07F),
  Color(0xFF21D0E8),
  Color(0xFFFF8A3D),
];

/// A deck's colour identity, taken from its slot number so deck 1 is always blue
/// and deck 2 green, whatever track is loaded.
class DeckTheme {
  const DeckTheme(this.index);

  final int index;

  Color get accent => deckColors[index % deckColors.length];

  /// A deeper shade of the accent, for the low end of a progress fill.
  Color get accentDeep => HSLColor.fromColor(accent)
      .withLightness(
        (HSLColor.fromColor(accent).lightness * 0.62).clamp(0.0, 1.0),
      )
      .toColor();
}

/// Makes a deck's [DeckTheme] available to every control it owns, so keys,
/// faders and tabs light in that deck's colour instead of the global accent.
class DeckThemeScope extends InheritedWidget {
  const DeckThemeScope({required this.theme, required super.child, super.key});

  final DeckTheme theme;

  static DeckTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DeckThemeScope>()?.theme;

  /// The accent a control should use: the enclosing deck's colour, or the
  /// global accent when a control sits outside any deck.
  static Color accentOf(BuildContext context) =>
      maybeOf(context)?.accent ?? T.accent;

  /// The theme a control belongs to, or null outside a deck scope.
  static DeckTheme? of(BuildContext context) => maybeOf(context);

  @override
  bool updateShouldNotify(DeckThemeScope old) => old.theme.index != theme.index;
}

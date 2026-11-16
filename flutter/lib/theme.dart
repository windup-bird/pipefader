import 'package:material_ui/material_ui.dart';

/// The whole skin: colours, type and geometry.
///
/// Nothing outside this file names a colour, a gap or a corner. A new skin is a
/// new set of these constants, nothing else.
abstract final class T {
  // Page: neutral charcoal, one grey per band. No colour cast — the accent is
  // the only blue in the room.
  static const bg = Color(0xFF161616);
  /// Header, deck info and the control strip.
  static const band = Color(0xFF1B1B1B);
  /// The waveform strip, the darkest band.
  static const wave = Color(0xFF0B0B0B);
  /// The browser sits between the two.
  static const browser = Color(0xFF131313);
  static const surface = Color(0xFF242424);
  static const surfaceHi = Color(0xFF2E2E2E);
  static const surfaceMid = Color(0xFF202020);
  static const handle = Color(0xFF565656);
  static const handleHi = Color(0xFF6E6E6E);
  static const line = Color(0xFF333333);
  static const track = Color(0xFF3A3A3A);
  static const hair = Color(0x1AFFFFFF);

  // Type.
  static const text = Color(0xFFEDEDED);
  static const dim = Color(0xFFA8A8A8);
  static const faint = Color(0xFF757575);

  // Accent.
  static const accent = Color(0xFF3B82F6);
  static const accentLo = Color(0xFF1F4FA8);
  static const accentHi = Color(0xFFCFE2FF);
  static const error = Color(0xFFE5484D);
  static const warn = Color(0xFFF0A93B);

  // Waveform.
  static const waveLo = Color(0xFF24579F);
  static const waveMid = Color(0xFF3B82F6);
  static const waveHi = Color(0xFFDCE9FF);
  static const playhead = Color(0xFFFF4D4F);
  static const beat = Color(0x2AAAAAAA);
  static const bar = Color(0x55AAAAAA);

  // Geometry.
  static const radiusCover = 4.0;
  static const gap = 8.0;
  static const gapS = 4.0;
  static const gapL = 16.0;

  // Type sizes, referenced by [Ty].
  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];
}

/// Type tokens. Sizes are deliberately few: a label, a value, a title and a clock.
abstract final class Ty {
  static const _tab = T._tabular;

  static const label = TextStyle(
    fontSize: 10,
    height: 1.0,
    color: T.dim,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
  );
  static const labelSmall = TextStyle(
    fontSize: 9,
    height: 1.0,
    color: T.faint,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
  );
  static const artist = TextStyle(
    fontSize: 10,
    height: 1.0,
    color: T.dim,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
  );
  static const title = TextStyle(
    fontSize: 18,
    height: 1.05,
    color: T.text,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );
  static const num = TextStyle(
    fontSize: 12,
    height: 1.0,
    color: T.text,
    fontWeight: FontWeight.w600,
    fontFeatures: _tab,
  );
  static const numDim = TextStyle(
    fontSize: 12,
    height: 1.0,
    color: T.dim,
    fontWeight: FontWeight.w500,
    fontFeatures: _tab,
  );
  static const clock = TextStyle(
    fontSize: 12,
    height: 1.0,
    color: T.text,
    fontWeight: FontWeight.w600,
    fontFeatures: _tab,
    letterSpacing: 0.2,
  );
  static const bpm = TextStyle(
    fontSize: 22,
    height: 1.0,
    color: T.text,
    fontWeight: FontWeight.w700,
    fontFeatures: _tab,
    letterSpacing: -0.3,
  );
  static const pad = TextStyle(
    fontSize: 12,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
  static const key = TextStyle(
    fontSize: 15,
    height: 1.0,
    color: T.text,
    fontWeight: FontWeight.w600,
    fontFeatures: _tab,
    letterSpacing: 0.4,
  );
  static const button = TextStyle(
    fontSize: 10,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
  );
}

ThemeData buildTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: T.accent,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: T.bg,
    canvasColor: T.bg,
    dividerColor: T.line,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        fontSize: 13,
        height: 1.2,
        color: T.text,
        decoration: TextDecoration.none,
      ),
    ),
    visualDensity: VisualDensity.standard,
  );
}

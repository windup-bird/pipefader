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

  /// The browser's own header, a shade above its body.
  static const browserBar = Color(0xFF1E1E1E);

  /// The browser's raised column (the list of playlists), a step between the
  /// body and the header so columns read as layers.
  static const browserCol = Color(0xFF171717);
  static const surface = Color(0xFF242424);
  static const surfaceLo = Color(0xFF1E1E1E);
  static const surfaceHi = Color(0xFF2E2E2E);
  static const surfaceMid = Color(0xFF202020);

  /// The bright grey a lit key or pad takes: high contrast against the deep
  /// idle grey, with no colour cast of its own.
  static const lit = Color(0xFF4A4A4A);
  static const litHi = Color(0xFF565656);

  /// The short grip line down the middle of a fader handle: brighter than the
  /// face, so it reads as a polished ridge rather than a groove.
  static const handleGrip = Color(0xFFEDEDED);
  static const line = Color(0xFF333333);

  /// The hairline that separates bands and side-by-side units: pure black, one
  /// pixel, so the shared grey reads as separate faces.
  static const sep = Color(0xFF000000);
  static const track = Color(0xFF151515);
  static const hair = Color(0x1AFFFFFF);

  // Light and shade. Hardware reads as a solid object because its top edge
  // catches the light and its body casts a little shadow; both are tokens so a
  // skin can flatten them in one place.
  static const highlight = Color(0x1CFFFFFF);
  static const shadow = Color(0x8C000000);
  static const shadowSoft = Color(0x4D000000);
  static const glowAccent = Color(0x553B82F6);
  static const scrim = Color(0xB3000000);
  static const glass = Color(0xC4141414);

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

  // Pad colors: 8 for CUE mode, single color for LOOP/JUMP.
  static const padCueColors = <Color>[
    Color(0xFFE5484D), // red
    Color(0xFFF0A93B), // orange
    Color(0xFFF7C544), // yellow
    Color(0xFF6EE7B7), // mint
    Color(0xFF3B82F6), // blue
    Color(0xFF9B7EDE), // purple
    Color(0xFFEC4899), // pink
    Color(0xFFFF6B9D), // rose
  ];
  static const padLoopColor = Color(0xFF3B82F6); // blue
  static const padJumpColor = Color(0xFF6EE7B7); // green

  // Waveform.
  static const waveLo = Color(0xFF35465D);
  static const waveMid = Color(0xFF67809F);
  static const waveHi = Color(0xFFBBCADF);
  static const waveTintStrength = 0.45;
  static const playhead = Color(0xFFFF4D4F);
  // Opaque TUI grid greys. The old translucent whites washed out to ~#333/#5C
  // over the near-black waveform band, which made the grid nearly invisible.
  static const beat = Color(0xFF6E6E6E);
  static const bar = Color(0xFFA0A0A0);

  // Geometry.
  static const radiusCover = 4.0;
  static const gap = 8.0;
  static const gapS = 4.0;
  static const gapL = 16.0;

  // Type sizes (px). Single source of truth for every font size in the app.
  static const s8 = 8.0;
  static const s9 = 9.0;
  static const s10 = 10.0;
  static const s11 = 11.0;
  static const s12 = 12.0;
  static const s12_5 = 12.5;
  static const s13 = 13.0;
  static const s14 = 14.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s22 = 22.0;

  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];
}

/// Type tokens. Sizes are deliberately few: a label, a value, a title and a clock.
///
/// The app uses the platform's UI font. Tracking is kept tight on body text so it does not read as
/// a monospaced face; only small section labels keep the wide, hardware-legend spacing.
abstract final class Ty {
  static const _tab = T._tabular;

  static const body = TextStyle(
    fontSize: T.s13,
    height: 1.25,
    color: T.text,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const bodySmall = TextStyle(
    fontSize: T.s11,
    height: 1.2,
    color: T.dim,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const section = TextStyle(
    fontSize: T.s10,
    height: 1.0,
    color: T.dim,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
  static const pageTitle = TextStyle(
    fontSize: T.s16,
    height: 1.0,
    color: T.text,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );
  static const label = TextStyle(
    fontSize: T.s10,
    height: 1.0,
    color: T.dim,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );
  static const labelSmall = TextStyle(
    fontSize: T.s9,
    height: 1.0,
    color: T.faint,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );
  static const artist = TextStyle(
    fontSize: T.s8,
    height: 1.0,
    color: T.dim,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
  );
  static const title = TextStyle(
    fontSize: T.s16,
    height: 1.0,
    color: T.text,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );
  static const num = TextStyle(
    fontSize: T.s12,
    height: 1.0,
    color: T.text,
    fontWeight: FontWeight.w600,
    fontFeatures: _tab,
    letterSpacing: 0,
  );
  static const numericBig = TextStyle(
    fontSize: T.s16,
    height: 1.0,
    color: T.text,
    fontWeight: FontWeight.w600,
    fontFeatures: _tab,
    letterSpacing: 0,
  );
  static const meta = TextStyle(
    fontSize: T.s9,
    height: 1.0,
    color: T.dim,
    fontWeight: FontWeight.w500,
    fontFeatures: _tab,
  );
  static const value = TextStyle(
    fontSize: T.s16,
    height: 1.0,
    color: T.text,
    fontWeight: FontWeight.w600,
    fontFeatures: _tab,
  );
  static const bpm = TextStyle(
    fontSize: T.s22,
    height: 1.0,
    color: T.text,
    fontWeight: FontWeight.w700,
    fontFeatures: _tab,
    letterSpacing: -0.3,
  );
  static const pad = TextStyle(
    fontSize: T.s12,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
  static const key = TextStyle(
    fontSize: T.s16,
    height: 1.0,
    color: T.text,
    fontWeight: FontWeight.w600,
    fontFeatures: _tab,
    letterSpacing: 0.4,
  );
  static const button = TextStyle(
    fontSize: T.s10,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  static const phoneBpm = TextStyle(
    fontSize: T.s20,
    height: 1.0,
    color: T.text,
    fontWeight: FontWeight.w700,
    fontFeatures: _tab,
    letterSpacing: -0.4,
  );
  static const phoneMeta = TextStyle(
    fontSize: T.s9,
    height: 1.0,
    color: T.faint,
    fontWeight: FontWeight.w600,
    fontFeatures: _tab,
  );
  static const menuRow = TextStyle(
    fontSize: T.s12,
    height: 1.0,
    color: T.text,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
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
      bodyMedium: Ty.body,
    ),
    visualDensity: VisualDensity.standard,
  );
}

/// One scale shared by every control in a band. [base] is the height the
/// design was drawn at; sizes and fonts follow the real height but are clamped
/// so a short band stays readable and a tall one stays compact.
class ControlScale {
  const ControlScale(this.height, {this.base = 128});

  final double height;
  final double base;

  static const fallback = ControlScale(128);

  double get factor => (height / base).clamp(0.72, 1.3).toDouble();

  double size(double value, {double min = 3, double max = 400}) =>
      (value * factor).clamp(min, max).toDouble();

  double font(double value) => (value * factor).clamp(T.s8, 30.0).toDouble();

  /// The waveform overlay was drawn for a 30px row.
  factory ControlScale.wave(double height) => ControlScale(height, base: 30);
}

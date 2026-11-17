import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The face of a hardware key: a shallow vertical gradient, a cast shadow and,
/// when active, a blue glow. No radius and no outline, so a row of keys reads as
/// a machined panel rather than a web card.
BoxDecoration keyFace({
  bool active = false,
  bool pressed = false,
  bool hover = false,
  bool enabled = true,
  bool glass = false,
}) {
  if (!enabled) {
    return BoxDecoration(
      color: T.surface.withValues(alpha: 0.45),
      boxShadow: const [
        BoxShadow(color: T.shadowSoft, offset: Offset(0, 1), blurRadius: 1),
      ],
    );
  }
  if (active) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF5B9BFB), T.accentLo],
      ),
      boxShadow: const [
        BoxShadow(color: T.glowAccent, blurRadius: 10, spreadRadius: 1),
        BoxShadow(color: T.shadowSoft, offset: Offset(0, 1), blurRadius: 2),
      ],
    );
  }
  if (pressed) {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1B1B1B), Color(0xFF262626)],
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0xAA000000),
          offset: Offset(0, 2),
          blurRadius: 4,
        ),
      ],
    );
  }
  if (glass) {
    return BoxDecoration(
      color: hover
          ? T.surfaceHi.withValues(alpha: 0.92)
          : T.surface.withValues(alpha: 0.62),
      boxShadow: const [
        BoxShadow(color: T.shadowSoft, offset: Offset(0, 1), blurRadius: 3),
      ],
    );
  }
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: hover
          ? const [Color(0xFF383838), Color(0xFF262626)]
          : const [T.surfaceHi, T.surface],
    ),
    boxShadow: const [
      BoxShadow(color: T.shadowSoft, offset: Offset(0, 1), blurRadius: 2),
    ],
  );
}

/// The track a fader runs in: dark, inset, no border.
BoxDecoration slotFace() => const BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [T.track, Color(0xFF232323)],
  ),
  boxShadow: [
    BoxShadow(
      color: Color(0xCC000000),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ],
);

/// A metal handle: lit along its top edge, dark underneath.
BoxDecoration handleFace({bool active = false, bool hover = false}) {
  final top = active
      ? T.accentHi
      : hover
      ? T.text
      : T.handleHi;
  final bottom = active
      ? T.accent
      : hover
      ? T.handleHi
      : T.handle;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, bottom],
    ),
    boxShadow: active
        ? const [BoxShadow(color: T.glowAccent, blurRadius: 8)]
        : const [
            BoxShadow(color: T.shadow, offset: Offset(0, 2), blurRadius: 3),
          ],
  );
}

/// The panel an overlay or a menu sits on: flat, dark, with a cast shadow.
BoxDecoration panelFace({Color color = T.surfaceMid}) => BoxDecoration(
  color: color,
  boxShadow: const [
    BoxShadow(
      color: Color(0xB3000000),
      offset: Offset(0, 10),
      blurRadius: 28,
      spreadRadius: 2,
    ),
  ],
);

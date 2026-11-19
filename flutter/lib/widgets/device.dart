import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The face of a hardware key: a flat fill, a top highlight and a soft cast
/// shadow. Idle sits a step above the page; active lifts to the bright grey
/// with the same highlight and shadow, so the two states share an edge.
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
    // Active reuses the idle face's top highlight and soft cast shadow; only
    // the fill lifts to the bright grey. No glow, no extra inset.
    return BoxDecoration(
      color: T.lit,
      border: const Border(top: BorderSide(color: T.highlight, width: 1)),
      boxShadow: const [
        BoxShadow(color: T.shadowSoft, offset: Offset(0, 1), blurRadius: 2),
      ],
    );
  }
  if (pressed) {
    return const BoxDecoration(
      color: Color(0xFF202020),
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
    color: hover ? T.surfaceHi : T.surface,
    border: const Border(top: BorderSide(color: T.highlight, width: 1)),
    boxShadow: const [
      BoxShadow(color: T.shadowSoft, offset: Offset(0, 1), blurRadius: 2),
    ],
  );
}

/// The track a fader runs in: a flat dark slot, no gradient, no border.
BoxDecoration slotFace() => const BoxDecoration(color: T.track);

/// A solid fader handle: bright grey face with a short darker grip line down
/// the middle, lit along its top edge and casting a shadow. [vertical] picks a
/// tall handle (crossfader, param bar); otherwise a wide channel handle. The
/// grip runs about a third of the handle's long axis.
class FaderHandle extends StatelessWidget {
  const FaderHandle({
    this.vertical = false,
    this.active = false,
    this.hover = false,
    super.key,
  });

  final bool vertical;
  final bool active;
  final bool hover;

  @override
  Widget build(BuildContext context) {
    // The face takes the same grey a lit pad uses, so the handle reads as one
    // piece with the rest of the panel; hover lifts one step.
    final face = hover ? T.litHi : T.lit;
    return Container(
      decoration: BoxDecoration(
        color: face,
        border: const Border(top: BorderSide(color: T.highlight, width: 1)),
        boxShadow: const [
          BoxShadow(color: T.shadow, offset: Offset(0, 2), blurRadius: 3),
        ],
      ),
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, c) {
          // Grip line: a third of the long axis, one pixel thick.
          final w = vertical ? 1.0 : c.maxWidth / 3;
          final h = vertical ? c.maxHeight / 3 : 1.0;
          return Center(
            child: SizedBox(
              width: w,
              height: h,
              child: const ColoredBox(color: T.handleGrip),
            ),
          );
        },
      ),
    );
  }
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

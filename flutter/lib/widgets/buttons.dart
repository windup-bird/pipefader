import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'device.dart';
import 'glyph.dart';

/// The one button shape: a flat key, no radius, no border. Idle sits a shade
/// above the page the way a hardware button sits above a faceplate; active
/// takes the accent.
class PanelButton extends StatefulWidget {
  const PanelButton({
    required this.label,
    required this.onTap,
    this.active = false,
    this.width,
    this.height,
    this.style,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool active;
  final double? width;
  final double? height;
  final TextStyle? style;

  @override
  State<PanelButton> createState() => _PanelButtonState();
}

class _PanelButtonState extends State<PanelButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final enabled = widget.onTap != null;
    final foreground = active
        ? T.bg
        : !enabled
        ? T.faint
        : _hover
        ? T.text
        : T.dim;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap!();
              }
            : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: keyFace(
            active: active,
            pressed: _pressed,
            hover: _hover,
            enabled: enabled,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: (widget.style ?? Ty.button).copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}

/// A key with label and an optional small suffix, sized for the beat bar. The
/// suffix carries the unit so "4" reads as "4 beats" without a second label.
class GlassKey extends StatefulWidget {
  const GlassKey({
    required this.label,
    this.suffix,
    required this.onTap,
    this.active = false,
    this.height = 24,
    super.key,
  });

  final String label;
  final String? suffix;
  final VoidCallback? onTap;
  final bool active;
  final double height;

  @override
  State<GlassKey> createState() => _GlassKeyState();
}

class _GlassKeyState extends State<GlassKey> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final foreground = widget.active
        ? T.bg
        : !enabled
        ? T.faint
        : _hover
        ? Colors.white
        : T.text;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap!();
              }
            : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: keyFace(
            active: widget.active,
            pressed: _pressed,
            hover: _hover,
            enabled: enabled,
            glass: true,
          ),
          alignment: Alignment.center,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: widget.label,
                  style: TextStyle(
                    fontSize: T.s10,
                    height: 1.0,
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                if (widget.suffix != null)
                  TextSpan(
                    text: ' ${widget.suffix}',
                    style: TextStyle(
                      fontSize: T.s8,
                      height: 1.0,
                      color: widget.active
                          ? T.bg.withValues(alpha: 0.72)
                          : T.dim,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }
}

/// A square key whose face is a drawn glyph.
class GlyphButton extends StatefulWidget {
  const GlyphButton({
    required this.glyph,
    required this.onTap,
    this.size = 26,
    this.active = false,
    this.glass = false,
    super.key,
  });

  final GlyphKind glyph;
  final VoidCallback? onTap;
  final double size;
  final bool active;
  final bool glass;

  @override
  State<GlyphButton> createState() => _GlyphButtonState();
}

class _GlyphButtonState extends State<GlyphButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final foreground = widget.active
        ? T.bg
        : !enabled
        ? T.faint
        : _hover
        ? T.text
        : T.dim;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap!();
              }
            : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: keyFace(
            active: widget.active,
            pressed: _pressed,
            hover: _hover,
            enabled: enabled,
            glass: widget.glass,
          ),
          alignment: Alignment.center,
          child: Glyph(
            widget.glyph,
            size: widget.size * 0.55,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

/// A key that acts while the pointer is held, like a pitch bend. It lights
/// only for the duration of the press.
class HoldKey extends StatefulWidget {
  const HoldKey({
    required this.label,
    required this.onDown,
    required this.onUp,
    super.key,
  });

  final String label;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  State<HoldKey> createState() => _HoldKeyState();
}

class _HoldKeyState extends State<HoldKey> {
  bool _held = false;

  void _down() {
    if (_held) return;
    setState(() => _held = true);
    widget.onDown();
  }

  void _up() {
    if (!_held) return;
    setState(() => _held = false);
    widget.onUp();
  }

  @override
  Widget build(BuildContext context) {
    final active = _held;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: Container(
          decoration: keyFace(active: active),
          alignment: Alignment.center,
          child: Text(
            widget.label.toUpperCase(),
            style: Ty.button.copyWith(color: active ? T.bg : T.dim),
          ),
        ),
      ),
    );
  }
}

/// A row of small switch labels (pad modes) with the selected one in the
/// accent colour and no other chrome.
class ModeTabs extends StatelessWidget {
  const ModeTabs({
    required this.labels,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < labels.length; i++)
          _ModeTab(
            label: labels[i],
            selected: i == selected,
            onTap: () => onSelect(i),
          ),
      ],
    );
  }
}

class _ModeTab extends StatefulWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ModeTab> createState() => _ModeTabState();
}

class _ModeTabState extends State<_ModeTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? T.accent
        : _hover
        ? T.text
        : T.faint;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Text(
            widget.label.toUpperCase(),
            style: Ty.labelSmall.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

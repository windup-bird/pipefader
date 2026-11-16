import 'package:material_ui/material_ui.dart';

import '../theme.dart';
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
    final background = active
        ? T.accent
        : !enabled
            ? T.surface.withValues(alpha: 0.5)
            : _pressed
                ? T.surfaceHi
                : _hover
                    ? const Color(0xFF171B22)
                    : T.surface;
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
          color: background,
          alignment: Alignment.center,
          child: Text(
            widget.label.toUpperCase(),
            style: (widget.style ?? Ty.button).copyWith(color: foreground),
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
    super.key,
  });

  final GlyphKind glyph;
  final VoidCallback? onTap;
  final double size;
  final bool active;

  @override
  State<GlyphButton> createState() => _GlyphButtonState();
}

class _GlyphButtonState extends State<GlyphButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final background = widget.active
        ? T.accent
        : !enabled
            ? Colors.transparent
            : _pressed
                ? T.surfaceHi
                : _hover
                    ? T.surface
                    : Colors.transparent;
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
          color: background,
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

/// A row of small switch labels (pad modes, beat modes) with the selected one
/// in the accent colour and no other chrome.
class ModeTabs extends StatelessWidget {
  const ModeTabs({
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.alignment = MainAxisAlignment.center,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
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

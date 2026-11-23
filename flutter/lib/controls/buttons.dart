import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/device.dart';
import 'package:pipefader_gui/core/format.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/core/theme_scope.dart';

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
    this.scale,
    this.rawLabel = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool active;
  final double? width;
  final double? height;
  final TextStyle? style;
  final ControlScale? scale;

  /// Leave the label alone instead of applying the deck-control capitalization. Menu keys use
  /// this so `Cue` stays title case instead of becoming the transport key's `CUE`.
  final bool rawLabel;

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
    final scale = widget.scale ?? ControlScale.fallback;
    final style =
        widget.style ?? Ty.button.copyWith(fontSize: scale.font(T.s10));
    final foreground = active
        ? T.text
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
          width: widget.width == null ? null : scale.size(widget.width!),
          height: widget.height == null ? null : scale.size(widget.height!),
          decoration: keyFace(
            active: active,
            pressed: _pressed,
            hover: _hover,
            enabled: enabled,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.rawLabel ? widget.label : capitalizeWords(widget.label),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: style.copyWith(color: foreground),
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
    this.fill = false,
    this.glyph,
    this.scale,
    super.key,
  });

  final String label;
  final String? suffix;
  final GlyphKind? glyph;
  final VoidCallback? onTap;
  final bool active;
  final double height;
  final bool fill;
  final ControlScale? scale;

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
        ? T.text
        : !enabled
        ? T.faint
        : _hover
        ? Colors.white
        : T.text;
    final scale = widget.scale ?? ControlScale.fallback;
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
          height: widget.fill ? double.infinity : scale.size(widget.height),
          padding: EdgeInsets.symmetric(horizontal: scale.size(3)),
          decoration: keyFace(
            active: widget.active,
            pressed: _pressed,
            hover: _hover,
            enabled: enabled,
            glass: true,
          ),
          alignment: Alignment.center,
          child: widget.glyph == null
              ? Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: widget.label,
                        style: TextStyle(
                          fontSize: scale.font(T.s9) * 0.9,
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
                          text: '\u2009${widget.suffix}',
                          style: TextStyle(
                            fontSize: scale.font(T.s8) * 0.9,
                            height: 1.0,
                            color: widget.active
                                ? T.text.withValues(alpha: 0.72)
                                : T.dim,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Glyph(
                        widget.glyph!,
                        size: scale.size(12),
                        color: foreground,
                      ),
                      SizedBox(width: scale.size(3)),
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: scale.font(T.s9) * 0.9,
                          height: 1.0,
                          color: foreground,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
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
    this.scale,
    super.key,
  });

  final GlyphKind glyph;
  final VoidCallback? onTap;
  final double size;
  final bool active;
  final bool glass;
  final ControlScale? scale;

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
        ? T.text
        : !enabled
        ? T.faint
        : _hover
        ? T.text
        : T.dim;
    final scale = widget.scale ?? ControlScale.fallback;
    final size = scale.size(widget.size);
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
          width: size,
          height: size,
          decoration: keyFace(
            active: widget.active,
            pressed: _pressed,
            hover: _hover,
            enabled: enabled,
            glass: widget.glass,
          ),
          alignment: Alignment.center,
          child: Glyph(widget.glyph, size: size * 0.55, color: foreground),
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
    this.scale,
    super.key,
  });

  final String label;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final ControlScale? scale;

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
            capitalizeWords(widget.label),
            style: Ty.button.copyWith(
              fontSize: (widget.scale ?? ControlScale.fallback).font(T.s10),
              color: active ? T.text : T.dim,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of small switch labels with the selected one in the accent colour and
/// no other chrome. Set [scrollable] when a slot has more tabs than fit.
class ModeTabs extends StatelessWidget {
  const ModeTabs({
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.scrollable = false,
    this.fontSize = T.s9,
    this.scale,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool scrollable;
  final double fontSize;
  final ControlScale? scale;

  @override
  Widget build(BuildContext context) {
    final s = scale ?? ControlScale.fallback;
    final scaledFont = s.font(fontSize);
    final tabs = Row(
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < labels.length; i++)
          _ModeTab(
            label: labels[i],
            selected: i == selected,
            fontSize: scaledFont,
            scale: s,
            onTap: () => onSelect(i),
          ),
      ],
    );
    if (!scrollable) return tabs;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: tabs,
        ),
      ),
    );
  }
}

class _ModeTab extends StatefulWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.fontSize,
    required this.scale,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double fontSize;
  final ControlScale scale;
  final VoidCallback onTap;

  @override
  State<_ModeTab> createState() => _ModeTabState();
}

class _ModeTabState extends State<_ModeTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? DeckThemeScope.accentOf(context)
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
          padding: EdgeInsets.symmetric(
            horizontal: widget.scale.size(widget.fontSize >= T.s11 ? 4 : 7),
            vertical: widget.scale.size(3),
          ),
          child: Text(
            widget.label.toUpperCase(),
            style: Ty.labelSmall.copyWith(
              fontSize: widget.fontSize,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

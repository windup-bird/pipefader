import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/format.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/state/menu_state.dart';

/// The back arrow + title row every subpage shares.
class MenuPageHeader extends StatelessWidget {
  const MenuPageHeader({
    required this.title,
    required this.onBack,
    this.trailing,
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        children: [
          GlyphButton(glyph: GlyphKind.chevronLeft, size: 22, onTap: onBack),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titleCaseWords(title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ty.label.copyWith(color: T.text, fontSize: T.s11),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// One navigation row in the root menu: glyph, label, chevron.
class MenuActionRow extends StatefulWidget {
  const MenuActionRow({
    required this.label,
    required this.glyph,
    required this.onTap,
    super.key,
  });

  final String label;
  final GlyphKind glyph;
  final VoidCallback onTap;

  @override
  State<MenuActionRow> createState() => _MenuActionRowState();
}

class _MenuActionRowState extends State<MenuActionRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 36,
          color: _hover ? T.surface : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Glyph(widget.glyph, size: 15, color: _hover ? T.accent : T.dim),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titleCaseWords(widget.label),
                  style: Ty.menuRow.copyWith(color: _hover ? T.text : T.dim),
                ),
              ),
              Glyph(
                GlyphKind.chevronRight,
                size: 12,
                color: _hover ? T.accent : T.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of flat keys, horizontal (a segmented choice) or vertical (a category column).
class MenuChoice extends StatelessWidget {
  const MenuChoice({
    required this.options,
    required this.selected,
    required this.onSelect,
    this.axis = Axis.horizontal,
    this.height = 28,
    this.fontSize = T.s9,
    this.enabled = true,
    this.gap = 4,
    this.keys,
    super.key,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;
  final Axis axis;
  final double height;
  final double fontSize;
  final bool enabled;
  final double gap;

  /// Optional stable keys, one per option, so tests and shortcuts can address a label by name.
  final List<Key>? keys;

  @override
  Widget build(BuildContext context) {
    Widget keyAt(int index) => PanelButton(
      key: keys == null ? null : keys![index],
      label: titleCaseWords(options[index]),
      rawLabel: true,
      active: index == selected,
      height: height,
      onTap: enabled ? () => onSelect(index) : null,
      style: Ty.button.copyWith(fontSize: fontSize, letterSpacing: 0.5),
    );

    if (axis == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            SizedBox(width: double.infinity, child: keyAt(i)),
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: keyAt(i)),
        ],
      ],
    );
  }
}

/// The refresh key shared by Output and MIDI. It spins while `menu.refreshing`.
class MenuRefreshButton extends StatefulWidget {
  const MenuRefreshButton({required this.menu, required this.onTap, super.key});

  final MenuState menu;
  final VoidCallback onTap;

  @override
  State<MenuRefreshButton> createState() => _MenuRefreshButtonState();
}

class _MenuRefreshButtonState extends State<MenuRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    widget.menu.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(MenuRefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menu != widget.menu) {
      oldWidget.menu.removeListener(_sync);
      widget.menu.addListener(_sync);
      _sync();
    }
  }

  void _sync() {
    if (widget.menu.refreshing) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating) {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    widget.menu.removeListener(_sync);
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _spin,
      child: GlyphButton(
        glyph: GlyphKind.refresh,
        size: 24,
        onTap: widget.menu.refreshing ? null : widget.onTap,
      ),
    );
  }
}

class MenuSectionLabel extends StatelessWidget {
  const MenuSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(titleCaseWords(text), style: Ty.labelSmall),
  );
}

class MenuStatusLine extends StatelessWidget {
  const MenuStatusLine({this.error, this.note, super.key});

  final String? error;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final text = error ?? note;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Ty.meta.copyWith(
          color: error == null ? T.faint : T.error,
          height: 1.25,
        ),
      ),
    );
  }
}

/// A flat selectable row with a check on the current item. Used by MIDI inputs and map entries.
class MenuSelectRow extends StatefulWidget {
  const MenuSelectRow({
    required this.label,
    required this.selected,
    this.note,
    this.onTap,
    super.key,
  });

  final String label;
  final String? note;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<MenuSelectRow> createState() => _MenuSelectRowState();
}

class _MenuSelectRowState extends State<MenuSelectRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final color = widget.selected
        ? T.accent
        : _hover && enabled
        ? T.text
        : T.dim;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: 32,
          color: _hover && enabled ? T.surface : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.menuRow.copyWith(fontSize: T.s10, color: color),
                ),
              ),
              if (widget.note != null)
                Flexible(
                  child: Text(
                    widget.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: Ty.meta.copyWith(color: T.faint),
                  ),
                ),
              SizedBox(
                width: 16,
                child: widget.selected
                    ? const Glyph(GlyphKind.check, size: 10, color: T.accent)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/device.dart';
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
      height: 40,
      child: Row(
        children: [
          GlyphButton(glyph: GlyphKind.chevronLeft, size: 26, onTap: onBack),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              titleCaseWords(title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ty.pageTitle,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A page header that stays put while the body scrolls. The overlay gives every page a bounded
/// height; this frame keeps the back/title/refresh row outside the scroll view.
class MenuPageFrame extends StatelessWidget {
  const MenuPageFrame({required this.header, required this.child, super.key});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 14),
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            key: const ValueKey('menu-page-scroll'),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// One full-width choice row: a key face, a label, an optional second line, and a trailing mark
/// (a check on the current item, or a small action). Every list page uses this instead of drawing
/// its own hover row.
class MenuListRow extends StatelessWidget {
  const MenuListRow({
    required this.label,
    required this.onTap,
    this.note,
    this.selected = false,
    this.trailing,
    super.key,
  });

  final String label;
  final String? note;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return PanelButton(
      label: label,
      rawLabel: true,
      subLabel: note,
      active: selected,
      height: 46,
      onTap: onTap,
      trailing:
          trailing ??
          (selected ? const Glyph(GlyphKind.check, size: 20, color: T.text) : null),
      style: Ty.menuRow.copyWith(fontSize: T.s12),
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

  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.menu.refreshing;
    final foreground = !enabled ? T.faint : (_hover ? T.text : T.dim);
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
                widget.onTap();
              }
            : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: Container(
          width: 28,
          height: 28,
          decoration: keyFace(
            pressed: _pressed,
            hover: _hover,
            enabled: enabled,
          ),
          alignment: Alignment.center,
          child: RotationTransition(
            turns: _spin,
            child: Glyph(GlyphKind.refresh, size: 16, color: foreground),
          ),
        ),
      ),
    );
  }
}

class MenuSectionLabel extends StatelessWidget {
  const MenuSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(titleCaseWords(text), style: Ty.section),
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

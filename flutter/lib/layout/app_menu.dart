import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/core/format.dart';
import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/device.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/core/logo.dart';
import 'package:pipefader_gui/core/layout_mode.dart';

/// The menu behind the logo: a bigger mark, the four layouts, the deck count
/// for the current family, then controller / output / settings. It hangs from
/// the top centre, over a dimmed page.
void showAppMenu(
  BuildContext context, {
  required AppModel model,
  required LayoutMode current,
}) {
  final overlay = Overlay.of(context);
  final screen = MediaQuery.sizeOf(context);
  late final OverlayEntry entry;
  var closed = false;

  void dismiss() {
    if (closed) return;
    closed = true;
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => _AppMenu(
      model: model,
      current: current,
      screen: screen,
      onDismiss: dismiss,
      onInfo: (title, rows) {
        dismiss();
        _showInfoPanel(overlay, screen, title, rows);
      },
    ),
  );
  overlay.insert(entry);
}

class _AppMenu extends StatelessWidget {
  const _AppMenu({
    required this.model,
    required this.current,
    required this.screen,
    required this.onDismiss,
    required this.onInfo,
  });

  final AppModel model;
  final LayoutMode current;
  final Size screen;
  final VoidCallback onDismiss;
  final void Function(String, List<String>) onInfo;

  @override
  Widget build(BuildContext context) {
    final width = math.min(440.0, screen.width - 24);
    final top = math.max(48.0, screen.height * 0.06);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: ColoredBox(color: T.scrim),
          ),
        ),
        Positioned(
          left: (screen.width - width) / 2,
          top: top,
          width: width,
          child: AnimatedBuilder(
            animation: model,
            builder: (context, _) {
              final selected = model.forcedLayout ?? current;
              final options = deckOptionsFor(selected);
              final count = model.deckCountFor(selected);
              return DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: T.s13,
                  color: T.text,
                  decoration: TextDecoration.none,
                ),
                child: DecoratedBox(
                  decoration: panelFace(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LogoMark(size: 46),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            for (
                              var i = 0;
                              i < LayoutMode.values.length;
                              i++
                            ) ...[
                              if (i > 0) const SizedBox(width: 4),
                              Expanded(
                                child: _Chip(
                                  key: ValueKey(
                                    'layout-${LayoutMode.values[i].name}',
                                  ),
                                  label: LayoutMode.values[i].label,
                                  selected: LayoutMode.values[i] == selected,
                                  small: true,
                                  onTap: () {
                                    model.setLayout(LayoutMode.values[i]);
                                    onDismiss();
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const SizedBox(
                              width: 52,
                              child: Text('Decks', style: Ty.labelSmall),
                            ),
                            for (var i = 0; i < options.length; i++) ...[
                              if (i > 0) const SizedBox(width: 4),
                              SizedBox(
                                width: 34,
                                child: _Chip(
                                  key: ValueKey('decks-${options[i]}'),
                                  label: '${options[i]}',
                                  selected: options[i] == count,
                                  onTap: () {
                                    if (selected.usesFullDecks) {
                                      model.setFullDecks(options[i]);
                                    } else {
                                      model.setPhoneDecks(options[i]);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        _ActionRow(
                          key: const ValueKey('menu-controller'),
                          label: 'controller',
                          glyph: GlyphKind.controller,
                          onTap: () => onInfo('CONTROLLER', const [
                            'NO CONTROLLER CONNECTED',
                            'MIDI IN  —',
                            'MAP  —',
                          ]),
                        ),
                        _ActionRow(
                          key: const ValueKey('menu-output'),
                          label: 'output',
                          glyph: GlyphKind.output,
                          onTap: () => onInfo('OUTPUT', const [
                            'MAIN  44.1 kHz',
                            'BOOTH  OFF',
                            'HEADPHONES  OFF',
                          ]),
                        ),
                        _ActionRow(
                          key: const ValueKey('menu-settings'),
                          label: 'settings',
                          glyph: GlyphKind.settings,
                          onTap: () => onInfo('SETTINGS', const [
                            'TEMPO RANGE  ±8%',
                            'KEYLOCK  ON',
                            'WAVEFORM  3-BAND',
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

void _showInfoPanel(
  OverlayState overlay,
  Size screen,
  String title,
  List<String> rows,
) {
  final width = math.min(360.0, screen.width - 32);
  late final OverlayEntry entry;
  var closed = false;

  void dismiss() {
    if (closed) return;
    closed = true;
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: dismiss,
            child: ColoredBox(color: T.scrim),
          ),
        ),
        Center(
          child: SizedBox(
            width: width,
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                fontSize: T.s13,
                color: T.text,
                decoration: TextDecoration.none,
              ),
              child: DecoratedBox(
                decoration: panelFace(color: T.surfaceHi),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              capitalizeWords(title),
                              style: Ty.label.copyWith(
                                color: T.text,
                                fontSize: T.s11,
                              ),
                            ),
                          ),
                          GlyphButton(
                            glyph: GlyphKind.close,
                            size: 22,
                            onTap: dismiss,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (final row in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(width: 4, height: 4, color: T.accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  capitalizeWords(row),
                                  style: const TextStyle(
                                    fontSize: T.s11,
                                    color: T.dim,
                                    height: 1.2,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  overlay.insert(entry);
}

class _Chip extends StatefulWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.small = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool small;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
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
        child: Container(
          height: 28,
          decoration: keyFace(active: widget.selected, hover: _hover),
          alignment: Alignment.center,
          child: Text(
            capitalizeWords(widget.label),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: Ty.labelSmall.copyWith(
              fontSize: T.s9,
              letterSpacing: widget.small ? 0.4 : 0.8,
              color: widget.selected
                  ? T.text
                  : _hover
                  ? T.text
                  : T.dim,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatefulWidget {
  const _ActionRow({
    required this.label,
    required this.glyph,
    required this.onTap,
    super.key,
  });

  final String label;
  final GlyphKind glyph;
  final VoidCallback onTap;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
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
        child: Container(
          height: 36,
          color: _hover ? T.surface : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Glyph(widget.glyph, size: 15, color: _hover ? T.accent : T.dim),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  capitalizeWords(widget.label),
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

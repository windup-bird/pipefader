import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/device.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/core/layout_mode.dart';
import 'package:pipefader_gui/core/logo.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/menu/logs_page.dart';
import 'package:pipefader_gui/layout/menu/menu_widgets.dart';
import 'package:pipefader_gui/layout/menu/midi_page.dart';
import 'package:pipefader_gui/layout/menu/output_page.dart';
import 'package:pipefader_gui/layout/menu/settings_page.dart';
import 'package:pipefader_gui/state/app_model.dart';

enum _MenuPage { root, midi, output, settings, logs }

/// The menu behind the logo. It is always attached to the top edge and centred; the mark flies
/// from the header's actual rect into the panel, then back on close.
void showAppMenu(
  BuildContext context, {
  required AppModel model,
  required LayoutMode current,
  Rect? logoRect,
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  var removed = false;

  void dismiss() {
    if (removed) return;
    removed = true;
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => _AppMenuOverlay(
      model: model,
      current: current,
      logoRect: logoRect,
      onDismiss: dismiss,
    ),
  );
  overlay.insert(entry);
  unawaited(model.menu.ensureLoaded());
}

class _AppMenuOverlay extends StatefulWidget {
  const _AppMenuOverlay({
    required this.model,
    required this.current,
    required this.onDismiss,
    this.logoRect,
  });

  final AppModel model;
  final LayoutMode current;
  final Rect? logoRect;
  final VoidCallback onDismiss;

  @override
  State<_AppMenuOverlay> createState() => _AppMenuOverlayState();
}

class _AppMenuOverlayState extends State<_AppMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _open;
  late final Animation<double> _curve;
  late final Listenable _repaint;
  _MenuPage _page = _MenuPage.root;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _open = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _curve = CurvedAnimation(
      parent: _open,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _repaint = Listenable.merge([widget.model, widget.model.menu, _open]);
    _open.forward();
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _open.reverse().whenComplete(() {
      if (mounted) widget.onDismiss();
    });
  }

  void _openPage(_MenuPage page) {
    if (_page == page) return;
    unawaited(widget.model.menu.ensureLoaded());
    setState(() => _page = page);
  }

  void _back() {
    if (_page == _MenuPage.root) {
      _close();
    } else {
      setState(() => _page = _MenuPage.root);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    final width = math.min(440.0, screen.width - 24);
    final left = (screen.width - width) / 2;
    final maxHeight = math.max(120.0, screen.height - top);

    return AnimatedBuilder(
      animation: _repaint,
      builder: (context, _) {
        final status = widget.model.logoStatus(widget.current);
        final count = status.sounding.isEmpty ? 1 : status.sounding.length;
        final target = Rect.fromCenter(
          center: Offset(screen.width / 2, top + 16 + 23),
          width: LogoFaders.widthFor(46, count),
          height: 46,
        );
        final source = widget.logoRect ?? target;
        final mark = Rect.lerp(source, target, _curve.value)!;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: FadeTransition(
                  opacity: _open,
                  child: ColoredBox(color: T.scrim),
                ),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: width,
              child: FadeTransition(
                opacity: _open,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.02),
                    end: Offset.zero,
                  ).animate(_curve),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: DecoratedBox(
                      decoration: panelFace(),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(
                            fontSize: T.s13,
                            color: T.text,
                            decoration: TextDecoration.none,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 46),
                              const SizedBox(height: 16),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 180),
                                alignment: Alignment.topCenter,
                                curve: Curves.easeOutCubic,
                                child: TweenAnimationBuilder<double>(
                                  key: ValueKey(_page),
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 150),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) => Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(8 * (1 - value), 0),
                                      child: child,
                                    ),
                                  ),
                                  child: _pageBody(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: mark,
              child: IgnorePointer(
                child: Center(
                  child: LogoFaders(
                    sounding: status.sounding,
                    leader: status.leader,
                    size: mark.height,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pageBody() => switch (_page) {
    _MenuPage.root => _RootMenu(
      model: widget.model,
      current: widget.current,
      onOpen: _openPage,
      onClose: _close,
    ),
    _MenuPage.midi => MenuMidiPage(menu: widget.model.menu, onBack: _back),
    _MenuPage.output => MenuOutputPage(menu: widget.model.menu, onBack: _back),
    _MenuPage.settings => MenuSettingsPage(
      menu: widget.model.menu,
      onBack: _back,
    ),
    _MenuPage.logs => MenuLogsPage(onBack: _back),
  };
}

class _RootMenu extends StatelessWidget {
  const _RootMenu({
    required this.model,
    required this.current,
    required this.onOpen,
    required this.onClose,
  });

  final AppModel model;
  final LayoutMode current;
  final ValueChanged<_MenuPage> onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final selected = model.forcedLayout ?? current;
    final options = deckOptionsFor(selected);
    final count = model.deckCountFor(selected);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuChoice(
          options: [for (final mode in LayoutMode.values) mode.label],
          keys: [
            for (final mode in LayoutMode.values)
              ValueKey('layout-${mode.name}'),
          ],
          selected: selected.index,
          height: 28,
          fontSize: T.s8,
          onSelect: (index) {
            model.setLayout(LayoutMode.values[index]);
            onClose();
          },
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: 236,
            child: MenuChoice(
              options: [for (final option in options) '$option Decks'],
              keys: [for (final option in options) ValueKey('decks-$option')],
              selected: options.indexOf(count),
              height: 30,
              fontSize: T.s9,
              onSelect: (index) {
                if (selected.usesFullDecks) {
                  model.setFullDecks(options[index]);
                } else {
                  model.setPhoneDecks(options[index]);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        MenuActionRow(
          key: const ValueKey('menu-midi'),
          label: 'Midi / Map',
          glyph: GlyphKind.controller,
          onTap: () => onOpen(_MenuPage.midi),
        ),
        MenuActionRow(
          key: const ValueKey('menu-output'),
          label: 'Output',
          glyph: GlyphKind.output,
          onTap: () => onOpen(_MenuPage.output),
        ),
        MenuActionRow(
          key: const ValueKey('menu-settings'),
          label: 'Settings',
          glyph: GlyphKind.settings,
          onTap: () => onOpen(_MenuPage.settings),
        ),
        MenuActionRow(
          key: const ValueKey('menu-logs'),
          label: 'Logs',
          glyph: GlyphKind.panel,
          onTap: () => onOpen(_MenuPage.logs),
        ),
        if (model.menu.loading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Reading profile',
              style: Ty.labelSmall.copyWith(color: T.faint),
            ),
          ),
      ],
    );
  }
}

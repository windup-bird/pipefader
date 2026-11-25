import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/device.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/core/i18n.dart';
import 'package:pipefader_gui/core/layout_metrics.dart';
import 'package:pipefader_gui/core/layout_mode.dart';
import 'package:pipefader_gui/core/logo.dart';
import 'package:pipefader_gui/core/platform/app_restart.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/menu/controller_page.dart';
import 'package:pipefader_gui/layout/menu/logs_page.dart';
import 'package:pipefader_gui/layout/menu/mixer_page.dart';
import 'package:pipefader_gui/layout/menu/output_page.dart';
import 'package:pipefader_gui/layout/menu/preferences_page.dart';
import 'package:pipefader_gui/state/app_model.dart';

enum _MenuPage { root, controller, output, mixer, preferences, logs }

/// Which page the menu opens on. The browser's "Library settings" choice uses `preferences`;
/// the logo always opens `root`.
enum AppMenuTarget { root, preferences }

/// The menu behind the logo. It is always attached to the top edge and centred; the mark flies
/// from the header's actual rect into the panel, then back on close.
void showAppMenu(
  BuildContext context, {
  required AppModel model,
  required LayoutMode current,
  Rect? logoRect,
  AppMenuTarget target = AppMenuTarget.root,
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
      target: target,
      onDismiss: dismiss,
    ),
  );
  overlay.insert(entry);
  unawaited(model.menu.ensureLoaded());
}

/// Opens the menu directly on Preferences. The browser's Add-source sheet uses it for the
/// "Library settings" choice.
void showPreferencesMenu(BuildContext context, {required AppModel model}) {
  showAppMenu(
    context,
    model: model,
    current: model.currentLayout,
    target: AppMenuTarget.preferences,
  );
}

class _AppMenuOverlay extends StatefulWidget {
  const _AppMenuOverlay({
    required this.model,
    required this.current,
    required this.onDismiss,
    this.logoRect,
    this.target = AppMenuTarget.root,
  });

  final AppModel model;
  final LayoutMode current;
  final Rect? logoRect;
  final AppMenuTarget target;
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
  _MenuPage? _returnTo;
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
    if (widget.target == AppMenuTarget.preferences) {
      _page = _MenuPage.preferences;
    }
    _open.forward();
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    if (widget.model.menu.restartRequired) {
      final restart = await showDialog<bool>(
        context: context,
        barrierColor: T.scrim,
        builder: (context) => _RestartPrompt(
          onLater: () => Navigator.of(context).pop(false),
          onRestart: () => Navigator.of(context).pop(true),
        ),
      );
      if (restart == true) {
        await restartApp();
      }
    }
    _dismiss();
  }

  void _dismiss() {
    if (_closing) return;
    _closing = true;
    _open.reverse().whenComplete(() {
      if (mounted) widget.onDismiss();
    });
  }

  void _openPage(_MenuPage page) {
    if (_page == page) return;
    unawaited(widget.model.menu.ensureLoaded());
    setState(() {
      _page = page;
      _returnTo = null;
    });
  }

  void _openLogs() {
    unawaited(widget.model.menu.ensureLoaded());
    setState(() {
      _returnTo = _page;
      _page = _MenuPage.logs;
    });
  }

  void _back() {
    if (_page == _MenuPage.root) {
      unawaited(_close());
    } else if (_returnTo != null) {
      final parent = _returnTo!;
      setState(() {
        _page = parent;
        _returnTo = null;
      });
    } else {
      setState(() => _page = _MenuPage.root);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    final width = math.min(menuMaxWidth, screen.width - 24);
    final left = (screen.width - width) / 2;
    final maxHeight = math.max(120.0, screen.height - top);

    return AnimatedBuilder(
      animation: _repaint,
      builder: (context, _) {
        final status = widget.model.logoStatus(widget.current);
        final count = status.sounding.isEmpty ? 1 : status.sounding.length;
        final target = Rect.fromCenter(
          center: Offset(screen.width / 2, top + menuTopGap + 23),
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
                onTap: () => unawaited(_close()),
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
                    child: Material(
                      type: MaterialType.transparency,
                      child: DecoratedBox(
                        decoration: panelFace(),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            menuHPad,
                            menuTopGap,
                            menuHPad,
                            menuBottomGap,
                          ),
                          child: DefaultTextStyle.merge(
                            style: Ty.body,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 46),
                                const SizedBox(height: 16),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: AnimatedSize(
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
      onClose: () => unawaited(_close()),
    ),
    _MenuPage.controller => MenuControllerPage(
      menu: widget.model.menu,
      onBack: _back,
    ),
    _MenuPage.output => MenuOutputPage(menu: widget.model.menu, onBack: _back),
    _MenuPage.mixer => MenuMixerPage(menu: widget.model.menu, onBack: _back),
    _MenuPage.preferences => MenuPreferencesPage(
      menu: widget.model.menu,
      onBack: _back,
      onOpenLogs: _openLogs,
    ),
    _MenuPage.logs => MenuLogsPage(onBack: _back),
  };
}

/// The root: layout tiles, deck tiles, then one full-width key per destination page.
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
    final l10n = L10nScope.of(context);
    final selected = model.forcedLayout ?? current;
    final options = deckOptionsFor(selected);
    final count = model.deckCountFor(selected);
    return SingleChildScrollView(
      key: const ValueKey('menu-root-scroll'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var index = 0; index < LayoutMode.values.length; index++) ...[
              if (index > 0) const SizedBox(width: T.gap),
              Expanded(
                child: PanelButton(
                  key: ValueKey('layout-${LayoutMode.values[index].name}'),
                  label: l10n.layout(LayoutMode.values[index].name),
                  rawLabel: true,
                  glyph: _layoutGlyph(LayoutMode.values[index]),
                  iconAxis: Axis.vertical,
                  glyphSize: 28,
                  active: LayoutMode.values[index] == selected,
                  height: menuTileH,
                  onTap: () {
                    model.setLayout(LayoutMode.values[index]);
                    onClose();
                  },
                  style: Ty.button.copyWith(fontSize: T.s10),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var index = 0; index < options.length; index++) ...[
              if (index > 0) const SizedBox(width: T.gap),
              Expanded(
                child: PanelButton(
                  key: ValueKey('decks-${options[index]}'),
                  label: l10n.decks(options[index]),
                  rawLabel: true,
                  glyph: _decksGlyph(options[index]),
                  iconAxis: Axis.vertical,
                  glyphSize: 26,
                  active: options[index] == count,
                  height: menuDeckH,
                  onTap: () {
                    if (selected.usesFullDecks) {
                      model.setFullDecks(options[index]);
                    } else {
                      model.setPhoneDecks(options[index]);
                    }
                  },
                  style: Ty.button.copyWith(fontSize: T.s10),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: menuSectionGap),
        _MenuRow(
          key: const ValueKey('menu-controller'),
          glyph: GlyphKind.controller,
          label: l10n.controller,
          onTap: () => onOpen(_MenuPage.controller),
        ),
        const SizedBox(height: T.gap),
        _MenuRow(
          key: const ValueKey('menu-output'),
          glyph: GlyphKind.output,
          label: l10n.output,
          onTap: () => onOpen(_MenuPage.output),
        ),
        const SizedBox(height: T.gap),
        _MenuRow(
          key: const ValueKey('menu-mixer'),
          glyph: GlyphKind.mixer,
          label: l10n.mixer,
          onTap: () => onOpen(_MenuPage.mixer),
        ),
        const SizedBox(height: T.gap),
        _MenuRow(
          key: const ValueKey('menu-preferences'),
          glyph: GlyphKind.settings,
          label: l10n.preferences,
          onTap: () => onOpen(_MenuPage.preferences),
        ),
        if (model.menu.loading)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              l10n.readingProfile,
              style: Ty.bodySmall.copyWith(color: T.faint),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.glyph,
    required this.label,
    required this.onTap,
    super.key,
  });

  final GlyphKind glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PanelButton(
      label: label,
      rawLabel: true,
      glyph: glyph,
      glyphSize: 20,
      height: menuRowH,
      onTap: onTap,
      style: Ty.menuRow.copyWith(fontSize: T.s13),
    );
  }
}

GlyphKind _layoutGlyph(LayoutMode mode) => switch (mode) {
  LayoutMode.full => GlyphKind.layoutFull,
  LayoutMode.landscape => GlyphKind.layoutLandscape,
  LayoutMode.stacked => GlyphKind.layoutStacked,
  LayoutMode.allInOne => GlyphKind.layoutAllInOne,
};

GlyphKind _decksGlyph(int count) => switch (count) {
  2 => GlyphKind.decks2,
  3 => GlyphKind.decks3,
  _ => GlyphKind.decks4,
};

class _RestartPrompt extends StatelessWidget {
  const _RestartPrompt({required this.onLater, required this.onRestart});

  final VoidCallback onLater;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final canRestart =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return Center(
      child: SizedBox(
        width: math.min(360.0, MediaQuery.sizeOf(context).width - 32),
        child: Material(
          type: MaterialType.transparency,
          child: DecoratedBox(
          decoration: panelFace(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.restartTitle, style: Ty.pageTitle),
                const SizedBox(height: 10),
                Text(
                  canRestart ? l10n.restartBody : l10n.restartManual,
                  style: Ty.bodySmall.copyWith(height: 1.35),
                ),
                const SizedBox(height: 18),
                if (canRestart)
                  Row(
                    children: [
                      Expanded(
                        child: PanelButton(
                          label: l10n.restartLater,
                          rawLabel: true,
                          height: 40,
                          onTap: onLater,
                          style: Ty.menuRow.copyWith(fontSize: T.s11),
                        ),
                      ),
                      const SizedBox(width: T.gap),
                      Expanded(
                        child: PanelButton(
                          label: l10n.restartNow,
                          rawLabel: true,
                          active: true,
                          height: 40,
                          onTap: onRestart,
                          style: Ty.menuRow.copyWith(fontSize: T.s11),
                        ),
                      ),
                    ],
                  )
                else
                  PanelButton(
                    label: l10n.ok,
                    rawLabel: true,
                    active: true,
                    height: 40,
                    onTap: onLater,
                    style: Ty.menuRow.copyWith(fontSize: T.s11),
                  ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

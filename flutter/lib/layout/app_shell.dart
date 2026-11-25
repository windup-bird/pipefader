import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/i18n.dart';
import 'package:pipefader_gui/core/storage_permission.dart';
import 'package:pipefader_gui/core/volume_events.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/all_in_one_layout.dart';
import 'package:pipefader_gui/layout/full_layout.dart';
import 'package:pipefader_gui/layout/landscape_layout.dart';
import 'package:pipefader_gui/core/layout_mode.dart';
import 'package:pipefader_gui/layout/stacked_layout.dart';

/// The page: owns the clock, picks one of the four layouts and hosts the phone
/// browser overlay. Every section below is full-bleed; the layouts decide how
/// the bands share the space.
class AppShell extends StatefulWidget {
  const AppShell({this.model, super.key});

  /// Tests inject a model to pin the layout or the deck count.
  final AppModel? model;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AppModel _model = widget.model ?? AppModel();
  late final bool _ownsModel = widget.model == null;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshStorage());
    }
  }

  Future<void> _refreshStorage() async {
    final wasGranted = _model.storageGranted;
    final granted = await hasStoragePermission();
    if (!mounted) return;
    _model.setStorageGranted(granted);
    if (granted && !wasGranted) {
      unawaited(syncExistingVolumes());
      unawaited(flushVolumeEvents());
    }
  }

  Future<void> _grantStorage() async {
    await requestStoragePermission();
    if (!mounted) return;
    await _refreshStorage();
  }

  void _onTick(Duration elapsed) {
    final delta = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _model.advance(delta);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    if (_ownsModel) _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: T.bg,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _model,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final mode =
                  _model.forcedLayout ??
                  autoLayout(size, fullDecks: _model.fullDecks);
              final count = _model.deckCountFor(mode);
              _model.currentLayout = mode;
              final page = switch (mode) {
                LayoutMode.full => FullLayout(model: _model, deckCount: count),
                LayoutMode.landscape => LandscapeLayout(
                  model: _model,
                  deckCount: count,
                ),
                LayoutMode.stacked => StackedLayout(
                  model: _model,
                  deckCount: count,
                ),
                LayoutMode.allInOne => AllInOneLayout(
                  model: _model,
                  deckCount: count,
                ),
              };
              final l10n = L10nScope.of(context);
              final error = _model.engineError;
              final status = error != null
                  ? l10n.engineOffline(error)
                  : (_model.engineStarting ? l10n.startingEngine : null);
              return Stack(
                children: [
                  Positioned.fill(child: page),
                  if (status != null || !_model.storageGranted)
                    Positioned(
                      top: 6,
                      left: 12,
                      right: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (status != null)
                            IgnorePointer(
                              child: Center(
                                child: _EngineStatus(
                                  text: status,
                                  error: error != null,
                                ),
                              ),
                            ),
                          if (status != null && !_model.storageGranted)
                            const SizedBox(height: 4),
                          if (!_model.storageGranted)
                            _StoragePrompt(
                              text: l10n.storagePermission,
                              onTap: _grantStorage,
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A small status chip above the page: booting, or why the engine is offline.
class _EngineStatus extends StatelessWidget {
  const _EngineStatus({required this.text, required this.error});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: error ? T.error : T.bg,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: T.s10,
          color: error ? T.bg : T.dim,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// The storage grant is separate from the engine: the library stays empty until the user allows
/// the app to walk the media root, so the prompt stays visible on every page.
class _StoragePrompt extends StatelessWidget {
  const _StoragePrompt({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('storage-permission'),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        color: T.surface,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: T.s10,
            color: T.warn,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../state/app_model.dart';
import '../theme.dart';
import 'all_in_one_layout.dart';
import 'full_layout.dart';
import 'landscape_layout.dart';
import 'layout_mode.dart';
import 'stacked_layout.dart';

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
    with SingleTickerProviderStateMixin {
  late final AppModel _model = widget.model ?? AppModel();
  late final bool _ownsModel = widget.model == null;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final delta = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _model.advance(delta);
  }

  @override
  void dispose() {
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
              return Stack(children: [Positioned.fill(child: page)]);
            },
          ),
        ),
      ),
    );
  }
}

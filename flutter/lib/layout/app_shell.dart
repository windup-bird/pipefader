import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../state/app_model.dart';
import '../theme.dart';
import 'browser_pane.dart';
import 'control_band.dart';
import 'deck_info.dart';
import 'header.dart';
import 'waveform_row.dart';

/// The page: header, deck rows, waveforms, the control band and the browser.
/// Every section is a full-bleed band with its own grey so the rows read apart:
/// the waveform strip is the darkest, the browser sits between it and the
/// header/deck/control grey.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  final AppModel _model = AppModel();
  final ScrollController _controlScroll = ScrollController();
  final ScrollController _pageScroll = ScrollController();
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
    _controlScroll.dispose();
    _pageScroll.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: T.band,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _model,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (width >= 760) {
                return _wide(constraints);
              }
              return _stacked(constraints);
            },
          ),
        ),
      ),
    );
  }

  Widget _wide(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final roomy = width >= 1080;
    final hpad = roomy ? 20.0 : 14.0;
    final headerH = roomy ? 56.0 : 52.0;
    const base = 72.0;
    const browserMin = 150.0;
    final room = height - headerH - 14 - browserMin;
    var deckH = base;
    if (room < 5 * deckH) deckH = (room / 5).clamp(64.0, deckH);
    final waveH = deckH;
    final controlH = deckH * 2;
    final bandsHeight = headerH + 14 + 5 * deckH;
    final scrollable = height - bandsHeight < 110;

    final bands = <Widget>[
      ColoredBox(
        color: T.band,
        child: Column(
          children: [
            Header(height: headerH),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hpad),
              child: Row(
                children: [
                  Expanded(
                    child: DeckInfo(
                      model: _model,
                      deck: _model.decks[0],
                      height: deckH,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: DeckInfo(
                      model: _model,
                      deck: _model.decks[1],
                      height: deckH,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ColoredBox(
        color: T.wave,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hpad),
              child: Column(
                children: [
                  WaveformRow(
                    model: _model,
                    deck: _model.decks[0],
                    height: waveH,
                  ),
                  const SizedBox(height: 6),
                  WaveformRow(
                    model: _model,
                    deck: _model.decks[1],
                    height: waveH,
                  ),
                ],
              ),
            ),
            Positioned(
              left: hpad + 6,
              top: 8,
              child: WaveZoomKeys(model: _model),
            ),
          ],
        ),
      ),
      SizedBox(
        height: controlH,
        child: ColoredBox(
          color: T.band,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hpad, vertical: 10),
            child: ControlBand(model: _model, height: controlH - 20),
          ),
        ),
      ),
    ];
    final browser = _browserBand(hpad);

    if (scrollable) {
      return Scrollbar(
        controller: _pageScroll,
        thumbVisibility: true,
        thickness: 3,
        radius: Radius.zero,
        child: SingleChildScrollView(
          controller: _pageScroll,
          child: Column(
            children: [...bands, SizedBox(height: 300, child: browser)],
          ),
        ),
      );
    }
    return Column(children: [...bands, Expanded(child: browser)]);
  }

  Widget _stacked(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    const hpad = 12.0;
    const headerH = 46.0;
    const deckH = 68.0;
    const waveH = 56.0;
    final controlH = width >= 620 ? 184.0 : 172.0;

    final bands = <Widget>[
      ColoredBox(
        color: T.band,
        child: Column(
          children: [
            const Header(height: headerH),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: hpad),
              child: DeckInfo(
                model: _model,
                deck: _model.decks[0],
                height: deckH,
              ),
            ),
          ],
        ),
      ),
      ColoredBox(
        color: T.wave,
        child: Stack(
          children: [
            WaveformRow(
              model: _model,
              deck: _model.decks[0],
              height: waveH,
            ),
            Positioned(
              left: hpad + 6,
              top: 6,
              child: WaveZoomKeys(model: _model),
            ),
          ],
        ),
      ),
      ColoredBox(
        color: T.band,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: hpad),
          child: DeckInfo(
            model: _model,
            deck: _model.decks[1],
            height: deckH,
          ),
        ),
      ),
      ColoredBox(
        color: T.wave,
        child: WaveformRow(
          model: _model,
          deck: _model.decks[1],
          height: waveH,
        ),
      ),
      SizedBox(
        height: controlH,
        child: ColoredBox(
          color: T.band,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: hpad, vertical: 10),
            child: Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    controller: _controlScroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 980,
                      child: ControlBand(model: _model, height: controlH - 20),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 3,
                  child: _ScrollHint(controller: _controlScroll),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
    final browser = _browserBand(hpad);

    final fixed = headerH + 6 + deckH + waveH + deckH + waveH + controlH;
    if (fixed + 80 > height) {
      return Scrollbar(
        controller: _pageScroll,
        thumbVisibility: true,
        thickness: 3,
        radius: Radius.zero,
        child: SingleChildScrollView(
          controller: _pageScroll,
          child: Column(
            children: [...bands, SizedBox(height: 300, child: browser)],
          ),
        ),
      );
    }
    return Column(children: [...bands, Expanded(child: browser)]);
  }

  Widget _browserBand(double hpad) {
    return Container(
      color: T.browser,
      padding: EdgeInsets.fromLTRB(hpad, 0, hpad, 10),
      child: BrowserPane(model: _model),
    );
  }
}

/// A thin bar under a horizontally scrolled band: when the band is wider than
/// the page, this is the only cue that it can be dragged.
class _ScrollHint extends StatefulWidget {
  const _ScrollHint({required this.controller});

  final ScrollController controller;

  @override
  State<_ScrollHint> createState() => _ScrollHintState();
}

class _ScrollHintState extends State<_ScrollHint> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    // The controller has no clients on the first build, so re-check once the
    // scrollable has laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (!controller.hasClients) return const SizedBox.shrink();
    final position = controller.position;
    if (!position.hasContentDimensions) return const SizedBox.shrink();
    final extent = position.maxScrollExtent;
    if (extent <= 0) return const SizedBox.shrink();
    final viewport = position.viewportDimension;
    final fraction = (viewport / (viewport + extent)).clamp(0.0, 1.0);
    final progress = (position.pixels / extent).clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final thumb = width * fraction;
      return Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: T.surface)),
          Positioned(
            left: (width - thumb) * progress,
            width: thumb,
            top: 0,
            bottom: 0,
            child: const ColoredBox(color: T.dim),
          ),
        ],
      );
    });
  }
}

import 'package:material_ui/material_ui.dart';

import '../state/app_model.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/glyph.dart';
import '../widgets/waveform.dart';
import 'beat_bar.dart';

/// One deck's scrolling waveform. The beat controls sit over the left edge and
/// the shared zoom keys live once for the whole band, on the right.
class WaveformRow extends StatelessWidget {
  const WaveformRow({
    required this.model,
    required this.deck,
    this.showBeatBar = true,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final bool showBeatBar;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final beatBar =
              showBeatBar &&
              constraints.maxWidth >= 240 &&
              constraints.maxHeight >= 34;
          return Stack(
            children: [
              Positioned.fill(
                child: ValueListenableBuilder<int>(
                  valueListenable: model.clock,
                  builder: (context, _, _) => Waveform(
                    deck: deck,
                    framesPerPixel: model.framesPerPixel,
                  ),
                ),
              ),
              if (beatBar)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: BeatBar(model: model, deck: deck),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The one zoom pair, stacked and laid over the right edge of the waveforms.
class ZoomKeys extends StatelessWidget {
  const ZoomKeys({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlyphButton(
          glyph: GlyphKind.plus,
          size: 24,
          glass: true,
          onTap: () => model.zoom(inward: true),
        ),
        const SizedBox(height: 4),
        GlyphButton(
          glyph: GlyphKind.minus,
          size: 24,
          glass: true,
          onTap: () => model.zoom(inward: false),
        ),
      ],
    );
  }
}

/// A dark band behind a stack of waveforms, with the zoom pair centred on the
/// right edge.
class WaveformBand extends StatelessWidget {
  const WaveformBand({
    required this.model,
    required this.decks,
    this.rowGap = 6,
    this.hpad = 16,
    this.showBeatBars = true,
    super.key,
  });

  final AppModel model;
  final List<DeckRuntime> decks;
  final double rowGap;
  final double hpad;
  final bool showBeatBars;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: T.wave,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hpad),
              child: Column(
                children: [
                  for (var i = 0; i < decks.length; i++) ...[
                    if (i > 0) SizedBox(height: rowGap),
                    Expanded(
                      child: WaveformRow(
                        model: model,
                        deck: decks[i],
                        showBeatBar: showBeatBars,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(child: ZoomKeys(model: model)),
          ),
        ],
      ),
    );
  }
}

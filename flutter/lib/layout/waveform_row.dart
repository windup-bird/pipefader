import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/units/waveform.dart';
import 'package:pipefader_gui/layout/beat_bar.dart';

/// One deck's scrolling waveform. The beat controls sit over the left edge and
/// the shared zoom keys live once for the whole band, on the right.
class WaveformRow extends StatelessWidget {
  const WaveformRow({
    required this.model,
    required this.deck,
    this.showBeatBar = true,
    this.stacked = false,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final bool showBeatBar;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth.isFinite && constraints.maxWidth > 0) {
            model.setWaveView(constraints.maxWidth, model.framesPerPixel);
          }
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
                    palette: model.wavePalette,
                  ),
                ),
              ),
              if (beatBar)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: BeatBar(
                      model: model,
                      deck: deck,
                      rowHeight: constraints.maxHeight,
                      rowWidth: constraints.maxWidth,
                      stacked: stacked,
                    ),
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
  const ZoomKeys({required this.model, this.scale, super.key});

  final AppModel model;
  final ControlScale? scale;

  @override
  Widget build(BuildContext context) {
    final s = scale ?? ControlScale.wave(30);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlyphButton(
          glyph: GlyphKind.plus,
          size: 24,
          scale: s,
          glass: true,
          onTap: () => model.zoom(inward: true),
        ),
        SizedBox(height: s.size(4)),
        GlyphButton(
          glyph: GlyphKind.minus,
          size: 24,
          scale: s,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowH =
            (constraints.maxHeight - rowGap * (decks.length - 1)) /
            decks.length;
        final scale = ControlScale.wave(rowH);
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
                child: Center(
                  child: ZoomKeys(model: model, scale: scale),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

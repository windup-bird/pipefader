import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../state/app_model.dart';
import '../theme.dart';
import '../widgets/cover.dart';
import '../widgets/waveform.dart';

/// One deck's identity: cover, artist and title over the whole-track overview,
/// with the clock, key, tempo and bpm on the right. The two info rows are 1:2
/// high, the overview takes the remaining height.
class DeckInfo extends StatelessWidget {
  const DeckInfo({
    required this.model,
    required this.deck,
    required this.height,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final compact = width < 560;
          final showTempo = width >= 486;
          final showKey = width >= 420;
          final cover = height;
          final clockWidth = compact ? 100.0 : 116.0;
          final top = height * 0.6;
          final row1 = top / 3;
          final row2 = top - row1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoverArt(size: cover, seed: deck.view.coverSeed),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: top,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: row1,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      deck.view.artist.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Ty.artist,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: row2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      deck.view.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Ty.title,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: clockWidth,
                            child: ValueListenableBuilder<int>(
                              valueListenable: model.clock,
                              builder: (context, _, _) => Column(
                                children: [
                                  SizedBox(
                                    height: row1,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        clock(deck.frame, deck.view.sampleRate),
                                        style: Ty.meta,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: row2,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '-${clock(deck.view.totalFrames - deck.frame, deck.view.sampleRate)}',
                                        style: Ty.value,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (showKey)
                            SizedBox(
                              width: 52,
                              child: Column(
                                children: [
                                  SizedBox(height: row1),
                                  SizedBox(
                                    height: row2,
                                    child: Center(
                                      child: Text(deck.view.key, style: Ty.key),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (showTempo)
                            SizedBox(
                              width: 64,
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: row1,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        tempoText(deck.tempo),
                                        style: Ty.meta.copyWith(
                                          color: deck.tempo == 1.0
                                              ? T.dim
                                              : T.accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: row2,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        bpmText(deck.bpm),
                                        style: Ty.value.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: height - top,
                      child: ValueListenableBuilder<int>(
                        valueListenable: model.clock,
                        builder: (context, _, _) => Overview(
                          deck: deck.view,
                          frame: deck.frame.toDouble(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

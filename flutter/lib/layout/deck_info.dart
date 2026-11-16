import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../state/app_model.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/cover.dart';
import '../widgets/waveform.dart';

/// One deck's identity: cover, artist and title over the whole-track overview,
/// with the clock, key, tempo and sync on the right. Three rows in 1:2:3.
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
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 560;
        final showSync = width >= 560;
        final showTempo = width >= 486;
        final showKey = width >= 420;
        final cover = height;
        final clockWidth = compact ? 92.0 : 108.0;
        final top = height / 2;

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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: top / 3,
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
                                height: top * 2 / 3,
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
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: top / 3,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      clock(deck.frame, deck.view.sampleRate),
                                      style: Ty.clock,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: top * 2 / 3,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '-${clock(deck.view.totalFrames - deck.frame, deck.view.sampleRate)}',
                                      style: Ty.numDim,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (showKey)
                          SizedBox(
                            width: 44,
                            child: Center(
                              child: Text(deck.view.key, style: Ty.key),
                            ),
                          ),
                        if (showTempo)
                          SizedBox(
                            width: 58,
                            child: ValueListenableBuilder<int>(
                              valueListenable: model.clock,
                              builder: (context, _, _) => Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    height: top / 3,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        tempoText(deck.tempo),
                                        style: Ty.num.copyWith(
                                          fontSize: 10,
                                          color: deck.tempo == 1.0
                                              ? T.dim
                                              : T.accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: top * 2 / 3,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        bpmText(deck.bpm),
                                        style: Ty.num.copyWith(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (showSync)
                          SizedBox(
                            width: 62,
                            child: Center(
                              child: PanelButton(
                                label: 'sync',
                                active: deck.sync,
                                width: 58,
                                height: 26,
                                onTap: () => model.toggleSync(deck),
                              ),
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
      }),
    );
  }
}

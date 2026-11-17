import 'package:material_ui/material_ui.dart';

import '../state/app_model.dart';
import '../theme.dart';
import 'control_band.dart';
import 'deck_info.dart';
import 'header.dart';
import 'layout_mode.dart';
import 'waveform_row.dart';

const double _headerH = 48;
const double _deckH = 68;
const double _controlH = 170;
const double _minWaveRowH = 60;
const double _deckWaveGap = 6;
const double _waveControlGap = 8;

/// The all-in-one face: the desk without the browser and without the transport
/// columns. Waveforms take the space the browser would have used; the bottom
/// band is only the pad and FX hint.
class AllInOneLayout extends StatelessWidget {
  const AllInOneLayout({
    required this.model,
    required this.deckCount,
    super.key,
  });

  final AppModel model;
  final int deckCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final hpad = width >= 1200 ? 24.0 : 16.0;
        final decks = model.activeDecks(deckCount);
        final content = Column(
          children: [
            ColoredBox(
              color: T.band,
              child: SizedBox(
                height: _headerH,
                child: Header(
                  model: model,
                  mode: LayoutMode.allInOne,
                  height: _headerH,
                ),
              ),
            ),
            ColoredBox(
              color: T.band,
              child: SizedBox(
                height: _deckH,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hpad),
                  child: Row(
                    children: [
                      for (var i = 0; i < decks.length; i++) ...[
                        if (i > 0) const SizedBox(width: T.gapL),
                        Expanded(
                          child: DeckInfo(
                            model: model,
                            deck: decks[i],
                            height: _deckH,
                            secondsOnly: deckCount > 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: _deckWaveGap),
            Expanded(
              child: WaveformBand(model: model, decks: decks, hpad: hpad),
            ),
            const SizedBox(height: _waveControlGap),
            SizedBox(
              height: _controlH,
              child: Padding(
                padding: EdgeInsets.fromLTRB(hpad, T.gapS, hpad, T.gap),
                child: AllInOneControlBand(model: model),
              ),
            ),
          ],
        );
        const chrome =
            _headerH + _deckH + _deckWaveGap + _controlH + _waveControlGap;
        final minHeight = chrome + deckCount * _minWaveRowH;
        if (constraints.maxHeight >= minHeight) return content;
        return SingleChildScrollView(
          child: SizedBox(height: minHeight, child: content),
        );
      },
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../state/app_model.dart';
import '../theme.dart';
import 'browser_pane.dart';
import 'control_band.dart';
import 'deck_info.dart';
import 'header.dart';
import 'layout_mode.dart';
import 'waveform_row.dart';

const double _minBrowserH = 160;
const double _fallbackBrowserH = 260;

/// The desk face: header, one info row for every deck, a stack of waveforms, a
/// fixed control band and the browser taking the rest. The panels keep their
/// heights; only the browser reacts to the window.
class FullLayout extends StatelessWidget {
  const FullLayout({required this.model, required this.deckCount, super.key});

  final AppModel model;
  final int deckCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final roomy = width >= 1200;
        final hpad = roomy ? 24.0 : 16.0;
        final waveBandH = fullWaveBandH(deckCount);
        final chrome = fullChromeH(deckCount);
        final fits = height - chrome >= _minBrowserH;
        final decks = model.activeDecks(deckCount);

        final fixed = <Widget>[
          ColoredBox(
            color: T.band,
            child: SizedBox(
              height: fullHeaderH,
              child: Header(
                model: model,
                mode: LayoutMode.full,
                height: fullHeaderH,
              ),
            ),
          ),
          // No rule between the header and the deck row: they share one face.
          ColoredBox(
            color: T.band,
            child: SizedBox(
              height: fullDeckH,
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
                          height: fullDeckH,
                          secondsOnly: deckCount > 2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: waveBandH,
            child: WaveformBand(model: model, decks: decks, hpad: hpad),
          ),
          ColoredBox(
            color: T.band,
            child: SizedBox(
              height: fullControlH,
              child: Padding(
                padding: EdgeInsets.fromLTRB(hpad, T.gap, hpad, T.gap),
                child: ControlBand(model: model),
              ),
            ),
          ),
          // The only band rule: two black pixels between the control strip and
          // the browser.
          const SizedBox(height: 2, child: ColoredBox(color: T.sep)),
        ];

        final browser = ColoredBox(
          color: T.browser,
          child: BrowserPane(model: model),
        );

        if (fits) {
          return Column(
            children: [
              ...fixed,
              Expanded(child: browser),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              ...fixed,
              SizedBox(height: _fallbackBrowserH, child: browser),
            ],
          ),
        );
      },
    );
  }
}

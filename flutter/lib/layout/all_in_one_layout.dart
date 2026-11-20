import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/browser_view.dart';
import 'package:pipefader_gui/layout/control_band.dart';
import 'package:pipefader_gui/layout/deck_info.dart';
import 'package:pipefader_gui/layout/header.dart';
import 'package:pipefader_gui/core/layout_metrics.dart';
import 'package:pipefader_gui/core/layout_mode.dart';
import 'package:pipefader_gui/layout/waveform_row.dart';

/// The all-in-one face: the desk without the transport columns. Waveforms take
/// the space the browser would have used; the bottom band is only the pad and
/// FX hint. Tapping a cover raises the same phone browser landscape uses.
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

        final header = ColoredBox(
          color: T.band,
          child: SizedBox(
            height: allInOneHeaderH,
            child: Header(
              model: model,
              mode: LayoutMode.allInOne,
              height: allInOneHeaderH,
            ),
          ),
        );

        // The deck identity row: shared by the normal and browsing pages. The
        // outer parent (Expanded or SizedBox) gives it its height.
        final deckRow = ColoredBox(
          color: T.band,
          child: LayoutBuilder(
            builder: (context, c) => Padding(
              padding: EdgeInsets.symmetric(horizontal: hpad),
              child: Row(
                children: [
                  for (var i = 0; i < decks.length; i++) ...[
                    if (i > 0) const SizedBox(width: T.gapL),
                    Expanded(
                      child: DeckInfo(
                        model: model,
                        deck: decks[i],
                        height: c.maxHeight,
                        secondsOnly: deckCount > 2,
                        onCoverTap: model.openBrowserOverlay,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        if (model.browserOverlayOpen) {
          return BrowsingView(
            model: model,
            deck: decks.first,
            header: header,
            infoRow: deckRow,
            infoHeight: (constraints.maxHeight * allInOneDeckFlex / 100)
                .clamp(browsingInfoMinH, browsingInfoMaxH)
                .toDouble(),
          );
        }

        final content = Column(
          children: [
            header,
            Expanded(flex: allInOneDeckFlex, child: deckRow),
            const SizedBox(height: allInOneWaveGap),
            Expanded(
              flex: allInOneWaveFlex,
              child: WaveformBand(model: model, decks: decks, hpad: hpad),
            ),
            const SizedBox(height: allInOneControlGap),
            Expanded(
              flex: allInOneControlFlex,
              child: Padding(
                padding: EdgeInsets.fromLTRB(hpad, T.gapS, hpad, T.gap),
                child: AllInOneControlBand(model: model),
              ),
            ),
          ],
        );
        if (constraints.maxHeight >= allInOneMinHeight) return content;
        return SingleChildScrollView(
          child: SizedBox(height: allInOneMinHeight, child: content),
        );
      },
    );
  }
}

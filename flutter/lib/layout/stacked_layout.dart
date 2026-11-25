import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/browser_pane.dart';
import 'package:pipefader_gui/layout/control_phone.dart';
import 'package:pipefader_gui/layout/deck_info.dart';
import 'package:pipefader_gui/layout/header.dart';
import 'package:pipefader_gui/core/layout_metrics.dart';
import 'package:pipefader_gui/core/layout_mode.dart';
import 'package:pipefader_gui/layout/waveform_row.dart';

/// Tall and narrow: one deck section after another, then the touch blocks.
/// The control takes about a third of the height; if the sections cannot hold
/// their minimum, the page scrolls instead of squeezing the waveforms out.
class StackedLayout extends StatelessWidget {
  const StackedLayout({
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
        final hpad = constraints.maxWidth >= 700 ? 18.0 : 10.0;
        final controlH = (constraints.maxHeight * stackedControlShare)
            .clamp(stackedMinControlH, stackedMaxControlH)
            .toDouble();
        final decks = model.activeDecks(deckCount);
        final available = constraints.maxHeight - stackedHeaderH - controlH;
        final fits = available >= deckCount * stackedMinSectionH;

        final header = ColoredBox(
          color: T.band,
          child: SizedBox(
            height: stackedHeaderH,
            child: Header(
              model: model,
              mode: LayoutMode.stacked,
              height: stackedHeaderH,
            ),
          ),
        );
        final control = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 2, child: ColoredBox(color: T.sep)),
            SizedBox(
              height: controlH,
              child: ColoredBox(
                color: T.band,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hpad, 2, hpad, 2),
                  child: PhoneControlColumn(model: model),
                ),
              ),
            ),
          ],
        );

        // Browsing keeps the deck identities stacked at the top and gives the
        // rest to the single-column browser; waveforms and controls hide.
        if (model.browserOverlayOpen) {
          // Keep the same info height the normal (control-bearing) layout would give each
          // section. The browser then takes the space the waveforms and control band had; the
          // deck identity rows never change their internal scale.
          final sectionH = (available / deckCount).clamp(
            stackedMinSectionH,
            double.infinity,
          );
          final infoH = stackedInfoForSection(sectionH.toDouble());
          return ColoredBox(
            color: T.band,
            child: Column(
              children: [
                header,
                for (final deck in decks)
                  SizedBox(
                    height: infoH + stackedInfoPadY * 2,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        hpad,
                        stackedInfoPadY,
                        hpad,
                        stackedInfoPadY,
                      ),
                      child: DeckInfo(
                        model: model,
                        deck: deck,
                        height: infoH,
                        secondsOnly: deckCount > 2,
                        onCoverTap: model.closeBrowserOverlay,
                      ),
                    ),
                  ),
                Expanded(
                  child: PhoneBrowserPane(model: model, deck: decks.first),
                ),
              ],
            ),
          );
        }

        if (fits) {
          return Column(
            children: [
              header,
              Expanded(
                child: Column(
                  children: [
                    for (final deck in decks)
                      Expanded(
                        child: _DeckSection(
                          model: model,
                          deck: deck,
                          hpad: hpad,
                          secondsOnly: deckCount > 2,
                        ),
                      ),
                  ],
                ),
              ),
              control,
            ],
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              header,
              for (final deck in decks)
                SizedBox(
                  height: stackedMinSectionH,
                  child: _DeckSection(
                    model: model,
                    deck: deck,
                    hpad: hpad,
                    secondsOnly: deckCount > 2,
                  ),
                ),
              control,
            ],
          ),
        );
      },
    );
  }
}

class _DeckSection extends StatelessWidget {
  const _DeckSection({
    required this.model,
    required this.deck,
    required this.hpad,
    required this.secondsOnly,
  });

  final AppModel model;
  final DeckRuntime deck;
  final double hpad;
  final bool secondsOnly;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final infoH = stackedInfoForSection(constraints.maxHeight);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: T.band,
              child: SizedBox(
                height: infoH,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    hpad,
                    stackedInfoPadY,
                    hpad,
                    stackedInfoPadY,
                  ),
                  child: DeckInfo(
                    model: model,
                    deck: deck,
                    height: infoH - stackedInfoPadY * 2,
                    secondsOnly: secondsOnly,
                    onCoverTap: model.openBrowserOverlay,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ColoredBox(
                color: T.wave,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hpad),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: WaveformRow(
                          model: model,
                          deck: deck,
                          stacked: true,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Center(child: ZoomKeys(model: model)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

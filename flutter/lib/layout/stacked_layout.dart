import 'package:material_ui/material_ui.dart';

import '../state/app_model.dart';
import '../theme.dart';
import 'control_phone.dart';
import 'browser_pane.dart';
import 'deck_info.dart';
import 'header.dart';
import 'layout_mode.dart';
import 'waveform_row.dart';

const double _headerH = 40;
const double _controlShare = 0.34;
const double _minControlH = 196;
const double _maxControlH = 300;
const double _minSectionH = 150;

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
        final controlH = (constraints.maxHeight * _controlShare)
            .clamp(_minControlH, _maxControlH)
            .toDouble();
        final decks = model.activeDecks(deckCount);
        final available = constraints.maxHeight - _headerH - controlH;
        final fits = available >= deckCount * _minSectionH;

        final header = ColoredBox(
          color: T.band,
          child: SizedBox(
            height: _headerH,
            child: Header(
              model: model,
              mode: LayoutMode.stacked,
              height: _headerH,
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
          return ColoredBox(
            color: T.band,
            child: Column(
              children: [
                header,
                for (final deck in decks)
                  SizedBox(
                    height: _maxInfoH + _infoPadY * 2,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        hpad,
                        _infoPadY,
                        hpad,
                        _infoPadY,
                      ),
                      child: DeckInfo(
                        model: model,
                        deck: deck,
                        height: _maxInfoH,
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
                  height: _minSectionH,
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

const double _infoShare = 0.23;
const double _minInfoH = 38;
const double _maxInfoH = 74;
const double _infoPadY = 2;

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
        final infoH = (constraints.maxHeight * _infoShare)
            .clamp(_minInfoH, _maxInfoH)
            .toDouble();
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
                    _infoPadY,
                    hpad,
                    _infoPadY,
                  ),
                  child: DeckInfo(
                    model: model,
                    deck: deck,
                    height: infoH - _infoPadY * 2,
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

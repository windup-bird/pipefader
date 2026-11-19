import 'package:material_ui/material_ui.dart';

import '../state/app_model.dart';
import '../theme.dart';
import 'control_phone.dart';
import 'browser_pane.dart';
import 'deck_info.dart';
import 'header.dart';
import 'layout_mode.dart';
import 'waveform_row.dart';

const int _topFlex = 13;
const int _waveFlex = 43;
const int _controlFlex = 44;
const double _minHeight = 320;
const double _smallHeaderH = 32;
const double _logoSize = 32;

/// Short and wide: deck info across the top (the mark sits between a pair),
/// waveforms across the middle, touch blocks across the bottom. The browser is
/// not on the page; tapping a cover raises it.
class LandscapeLayout extends StatelessWidget {
  const LandscapeLayout({
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
        final hpad = width >= 1000 ? 20.0 : 12.0;
        final decks = model.activeDecks(deckCount);
        final three = deckCount >= 3;
        final browsing = model.browserOverlayOpen;

        final Widget? header = three
            ? SizedBox(
                height: _smallHeaderH,
                child: Header(
                  model: model,
                  mode: LayoutMode.landscape,
                  height: _smallHeaderH,
                ),
              )
            : null;
        final Widget infoRow = Padding(
          padding: EdgeInsets.fromLTRB(hpad, 4, hpad, 2),
          child: _DeckInfoRow(
            model: model,
            decks: decks,
            three: three,
            deckCount: deckCount,
          ),
        );

        // Browsing keeps every deck info on screen and gives the rest to the
        // browser; the waveforms and control band step out of the way.
        final content = browsing
            ? Column(
                children: [
                  ?header,
                  SizedBox(
                    height: (constraints.maxHeight * _topFlex / 100).clamp(
                      56.0,
                      120.0,
                    ),
                    child: infoRow,
                  ),
                  Expanded(
                    child: PhoneBrowserPane(model: model, deck: decks.first),
                  ),
                ],
              )
            : Column(
                children: [
                  ?header,
                  Expanded(flex: _topFlex, child: infoRow),
                  Expanded(
                    flex: _waveFlex,
                    child: WaveformBand(
                      model: model,
                      decks: decks,
                      rowGap: 4,
                      hpad: hpad,
                    ),
                  ),
                  Expanded(
                    flex: _controlFlex,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hpad, 4, hpad, 4),
                      child: PhoneControlRow(model: model),
                    ),
                  ),
                ],
              );

        final page = ColoredBox(color: T.band, child: content);
        if (constraints.maxHeight >= _minHeight || browsing) return page;
        return SingleChildScrollView(
          child: SizedBox(height: _minHeight, child: page),
        );
      },
    );
  }
}

/// The deck identities across the top: a pair bracketing the mark, or one per
/// deck on a three-deck rig.
class _DeckInfoRow extends StatelessWidget {
  const _DeckInfoRow({
    required this.model,
    required this.decks,
    required this.three,
    required this.deckCount,
  });

  final AppModel model;
  final List<DeckRuntime> decks;
  final bool three;
  final int deckCount;

  @override
  Widget build(BuildContext context) {
    if (three) {
      return Row(
        children: [
          for (var i = 0; i < decks.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => DeckInfo(
                  model: model,
                  deck: decks[i],
                  height: c.maxHeight,
                  secondsOnly: deckCount > 2,
                  onCoverTap: model.openBrowserOverlay,
                ),
              ),
            ),
          ],
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => DeckInfo(
              model: model,
              deck: decks[0],
              height: c.maxHeight,
              secondsOnly: deckCount > 2,
              onCoverTap: model.openBrowserOverlay,
            ),
          ),
        ),
        SizedBox(
          width: 72,
          child: Center(
            child: Builder(
              builder: (context) {
                final state = logoStateFor(model, LayoutMode.landscape);
                return LogoButton(
                  model: model,
                  mode: LayoutMode.landscape,
                  size: _logoSize,
                  sounding: state.sounding,
                  leader: state.leader,
                );
              },
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => DeckInfo(
              model: model,
              deck: decks[1],
              height: c.maxHeight,
              secondsOnly: deckCount > 2,
              onCoverTap: model.openBrowserOverlay,
            ),
          ),
        ),
      ],
    );
  }
}

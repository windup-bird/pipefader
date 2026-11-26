import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/browser_view.dart';
import 'package:pipefader_gui/layout/control_phone.dart';
import 'package:pipefader_gui/layout/deck_info.dart';
import 'package:pipefader_gui/layout/header.dart';
import 'package:pipefader_gui/core/layout_metrics.dart';
import 'package:pipefader_gui/core/layout_mode.dart';
import 'package:pipefader_gui/layout/waveform_row.dart';

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
                height: landscapeSmallHeaderH,
                child: Header(
                  model: model,
                  mode: LayoutMode.landscape,
                  height: landscapeSmallHeaderH,
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

        if (browsing) {
          return BrowsingView(
            model: model,
            deck: decks.first,
            header: header,
            infoRow: infoRow,
            infoHeight: (constraints.maxHeight * landscapeTopFlex / 100)
                .clamp(browsingInfoMinH, browsingInfoMaxH)
                .toDouble(),
          );
        }

        final page = ColoredBox(
          color: T.band,
          child: Column(
            children: [
              ?header,
              Expanded(flex: landscapeTopFlex, child: infoRow),
              Expanded(
                flex: landscapeWaveFlex,
                child: WaveformBand(
                  model: model,
                  decks: decks,
                  rowGap: 4,
                  hpad: hpad,
                ),
              ),
              Expanded(
                flex: landscapeControlFlex,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hpad, 4, hpad, 4),
                  child: PhoneControlRow(model: model),
                ),
              ),
            ],
          ),
        );
        if (constraints.maxHeight >= landscapeMinHeight) return page;
        return SingleChildScrollView(
          child: SizedBox(height: landscapeMinHeight, child: page),
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
                final state = model.logoStatus(LayoutMode.landscape);
                return LogoButton(
                  model: model,
                  mode: LayoutMode.landscape,
                  size: landscapeLogoSize,
                  levels: state.levels,
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

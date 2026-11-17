import 'package:material_ui/material_ui.dart';

/// The four faces of the front-end. [allInOne] is only ever chosen from the
/// header menu; the other three can also be derived from the viewport.
enum LayoutMode { full, landscape, stacked, allInOne }

extension LayoutModeLabel on LayoutMode {
  String get label => switch (this) {
    LayoutMode.full => 'full',
    LayoutMode.landscape => 'landscape',
    LayoutMode.stacked => 'stacked',
    LayoutMode.allInOne => 'all-in-one',
  };

  bool get isPhone =>
      this == LayoutMode.landscape || this == LayoutMode.stacked;

  bool get usesFullDecks =>
      this == LayoutMode.full || this == LayoutMode.allInOne;
}

// Full keeps its panels on fixed heights and lets the browser eat the rest, so
// the desk does not jump around when the window grows. Every other layout has
// no browser and is laid out with flex instead.
const double fullHeaderH = 44;
const double fullDeckH = 64;
const double fullControlH = 128;
const double fullGap = 8;

double fullWaveH(int decks) => decks > 2 ? 50 : 58;

double fullWaveBandH(int decks) => fullWaveH(decks) * decks + 6.0 * (decks - 1);

/// Everything in a full page except the browser.
double fullChromeH(int decks) =>
    fullHeaderH +
    fullGap +
    fullDeckH +
    fullGap +
    fullWaveBandH(decks) +
    fullGap +
    fullControlH;

int deckCountForLayout(
  LayoutMode mode, {
  required int fullDecks,
  required int phoneDecks,
}) => mode.usesFullDecks ? fullDecks : phoneDecks;

/// Auto layout, in the order the plan gives it:
///
/// * portrait → stacked, whatever the size;
/// * otherwise, if a full page would leave the browser less than a third of
///   the height, landscape;
/// * otherwise full.
///
/// The caller may override this from the header menu.
LayoutMode autoLayout(Size size, {required int fullDecks}) {
  if (size.height > size.width) return LayoutMode.stacked;
  final browser = size.height - fullChromeH(fullDecks);
  if (browser < size.height / 3) return LayoutMode.landscape;
  return LayoutMode.full;
}

/// The layout family a deck count belongs to, used to offer 2/4 vs 2/3 in the
/// menu.
List<int> deckOptionsFor(LayoutMode mode) =>
    mode.usesFullDecks ? const [2, 4] : const [2, 3];

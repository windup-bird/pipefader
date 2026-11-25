// 布局分段的唯一尺寸来源。
//
// full 的 header/deck/control 定死，browser 吃剩余；其余布局用 flex 共享
// 可用空间。这里只放「布局分段」尺寸，控件自身的行高、键宽等仍归各自控件。

// ── full ──
const double fullHeaderH = 44;
const double fullDeckH = 64;
const double fullControlH = 128;
const double fullGap = 8;
const double fullMinBrowserH = 160;
const double fullFallbackBrowserH = 260;

/// 控制带里共享的键高：unit 名称、sync、deck picker 对齐用。
double controlKeyHeight(double height) =>
    (height * 0.23).clamp(22.0, 34.0).toDouble();

double fullWaveH(int decks) => decks > 2 ? 50 : 58;

double fullWaveBandH(int decks) =>
    fullWaveH(decks) * decks + 6.0 * (decks - 1);

/// full 页里除 browser 外的全部高度。
double fullChromeH(int decks) =>
    fullHeaderH +
    fullGap +
    fullDeckH +
    fullGap +
    fullWaveBandH(decks) +
    fullGap +
    fullControlH;

// ── landscape ──
const int landscapeTopFlex = 13;
const int landscapeWaveFlex = 43;
const int landscapeControlFlex = 44;
const double landscapeMinHeight = 320;
const double landscapeSmallHeaderH = 32;
const double landscapeLogoSize = 32;

/// browsing 时顶部保留的 deck 身份行高度上下界，landscape 与 all-in-one 共用。
const double browsingInfoMinH = 56;
const double browsingInfoMaxH = 120;

/// The info row's height inside one deck section. The browsing layout keeps this number, so
/// opening the browser changes the height below the identity rows, not their internal scale.
double stackedInfoForSection(double sectionHeight) =>
    (sectionHeight * stackedInfoShare)
        .clamp(stackedMinInfoH, stackedMaxInfoH)
        .toDouble();

// ── stacked ──
const double stackedHeaderH = 40;
const double stackedControlShare = 0.34;
const double stackedMinControlH = 196;
const double stackedMaxControlH = 300;
const double stackedMinSectionH = 150;
const double stackedInfoShare = 0.23;
const double stackedMinInfoH = 38;
const double stackedMaxInfoH = 74;
const double stackedInfoPadY = 2;

// ── all-in-one ──
const double allInOneHeaderH = 48;
const int allInOneDeckFlex = 8;
const int allInOneWaveFlex = 72;
const int allInOneControlFlex = 20;
const double allInOneWaveGap = 6;
const double allInOneControlGap = 8;
const double allInOneMinHeight = 360;

// ── menu ──
// The panel is wider than the old 440 so the full-width action keys and the
// four layout tiles have room; phones still clamp to the viewport.
const double menuMaxWidth = 560;
const double menuHPad = 20;
const double menuTopGap = 16;
const double menuBottomGap = 18;
const double menuTileH = 78;
const double menuDeckH = 66;
const double menuRowH = 50;
const double menuListRowH = 46;
const double menuSectionGap = 14;

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/cover.dart';
import 'package:pipefader_gui/core/format.dart';
import 'package:pipefader_gui/core/i18n.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/core/theme_scope.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/model/library.dart';
import 'package:pipefader_gui/units/tempo_control.dart';
import 'package:pipefader_gui/units/waveform.dart';

const double _keyWidth = 30;
const double _timeSecondsWidth = 48;
const double _timeFullWidth = 84;
const double _tempoSecondsWidth = 46;
const double _tempoNarrowWidth = 48;
const double _tempoWidth = 56;
const double _minKeyWidth = 190;
const double _minKeylockWidth = 230;
const double _minTempoWidth = 260;
const double _coverInset = 4;

/// One deck's identity. The plan's grid is 1:2:2: the cover spans the first two
/// rows, the third row is the whole-track overview directly under the cover.
/// Type scales with the row height and the title column gives way first, so the
/// key / tempo / time block keeps its place on a four-deck desk.
class DeckInfo extends StatelessWidget {
  const DeckInfo({
    required this.model,
    required this.deck,
    required this.height,
    this.secondsOnly = false,
    this.onCoverTap,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final double height;

  /// On a three or four deck desk the clock drops the milliseconds.
  final bool secondsOnly;

  final VoidCallback? onCoverTap;

  @override
  Widget build(BuildContext context) {
    final deckTheme = DeckTheme(deck.index);
    final accent = deckTheme.accent;
    final content = ColoredBox(
      color: T.band,
      child: DeckThemeScope(
        theme: deckTheme,
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final row1H = height / 5;
              final row2H = height * 2 / 5;
              final topH = row1H + row2H;
              final overviewH = height - topH;
              final showTempo = width >= _minTempoWidth;
              final showKey = width >= _minKeyWidth;
              final showKeylock = showKey && width >= _minKeylockWidth;
              final tempoW = secondsOnly
                  ? _tempoSecondsWidth
                  : (width < 360 ? _tempoNarrowWidth : _tempoWidth);
              final timeW = secondsOnly ? _timeSecondsWidth : _timeFullWidth;

              double typeSize(
                double row,
                double share,
                double min,
                double max,
              ) => (row * share).clamp(min, max).toDouble();

              final titleSize = typeSize(row2H, 0.80, 8, 15);
              final artistSize = typeSize(row1H, 0.86, 6, 8);
              final keySize = typeSize(row2H, 0.78, 9, 15);
              final bpmSize = typeSize(row2H, 0.76, 9, 15);
              final timeSize = typeSize(row2H, 0.76, 8, 15);
              final metaSize = typeSize(row1H, 0.88, 6, 9);
              final lockSize = (row1H - 2).clamp(6.0, 11.0).toDouble();

              Widget cell(double h, Alignment alignment, Widget? child) =>
                  SizedBox(
                    height: h,
                    child: Align(alignment: alignment, child: child),
                  );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: topH,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onCoverTap,
                          child: MouseRegion(
                            cursor: onCoverTap == null
                                ? MouseCursor.defer
                                : SystemMouseCursors.click,
                            child: Padding(
                              padding: const EdgeInsets.all(_coverInset),
                              child: CoverArt(
                                size: topH - _coverInset * 2,
                                seed: deck.view.coverSeed,
                                color: accent,
                                image: deck.cover,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    cell(
                                      row1H,
                                      Alignment.centerLeft,
                                      Text(
                                        deck.view.artist.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Ty.artist.copyWith(
                                          fontSize: artistSize,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                    cell(
                                      row2H,
                                      Alignment.centerLeft,
                                      Text(
                                        deck.view.title == 'No Track'
                                            ? L10nScope.of(context).noTrack
                                            : deck.view.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Ty.title.copyWith(
                                          fontSize: titleSize,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (showKey) ...[
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: _keyWidth,
                                  child: Column(
                                    children: [
                                      cell(
                                        row1H,
                                        Alignment.centerRight,
                                        showKeylock
                                            ? _Keylock(
                                                on: deck.keylock,
                                                size: lockSize,
                                                onTap: () =>
                                                    model.toggleKeylock(deck),
                                              )
                                            : null,
                                      ),
                                      cell(
                                        row2H,
                                        Alignment.centerRight,
                                        Text(
                                          deck.view.key,
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.clip,
                                          style: Ty.key.copyWith(
                                            fontSize: keySize,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (showTempo)
                                SizedBox(
                                  width: tempoW,
                                  child: TempoControl(
                                    model: model,
                                    deck: deck,
                                    child: Column(
                                      children: [
                                        cell(
                                          row1H,
                                          Alignment.centerRight,
                                          Text(
                                            tempoText(deck.tempo),
                                            maxLines: 1,
                                            style: Ty.meta.copyWith(
                                              fontSize: metaSize,
                                              color: deck.tempo == 1.0
                                                  ? T.dim
                                                  : accent,
                                            ),
                                          ),
                                        ),
                                        cell(
                                          row2H,
                                          Alignment.centerRight,
                                          Text(
                                            bpmText(deck.bpm),
                                            maxLines: 1,
                                            style: Ty.num.copyWith(
                                              fontSize: bpmSize,
                                              fontWeight: FontWeight.w700,
                                              color: bpmColor(deck.tempo),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              SizedBox(
                                width: timeW,
                                child: ValueListenableBuilder<int>(
                                  valueListenable: model.clock,
                                  builder: (context, _, _) {
                                    final rate = deck.view.sampleRate;
                                    // Floor the elapsed seconds but round the
                                    // remainder up, so the countdown does not show
                                    // 0:00 before the track actually ends.
                                    final elapsed = secondsOnly
                                        ? shortClock(deck.frame ~/ rate)
                                        : clock(deck.frame, rate);
                                    final remaining = secondsOnly
                                        ? '-${shortClock(((deck.view.totalFrames - deck.frame) / rate).ceil())}'
                                        : '-${clock(deck.view.totalFrames - deck.frame, rate)}';
                                    return Column(
                                      children: [
                                        cell(
                                          row1H,
                                          Alignment.centerRight,
                                          Text(
                                            elapsed,
                                            maxLines: 1,
                                            style: Ty.meta.copyWith(
                                              fontSize: metaSize,
                                            ),
                                          ),
                                        ),
                                        cell(
                                          row2H,
                                          Alignment.centerRight,
                                          Text(
                                            remaining,
                                            maxLines: 1,
                                            style: Ty.num.copyWith(
                                              fontSize: timeSize,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: overviewH,
                    child: ValueListenableBuilder<int>(
                      valueListenable: model.clock,
                      builder: (context, _, _) => Overview(
                        deck: deck.view,
                        frame: deck.frame.toDouble(),
                        cueFrame: deck.cueFrame,
                        loopIn: deck.loopIn,
                        loopOut: deck.loopOut,
                        hotCueFrames: Map<int, int>.of(deck.hotCueFrames),
                        palette: model.wavePalette,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    return DragTarget<TrackRow>(
      onWillAcceptWithDetails: (details) => details.data.locationId >= 0,
      onAcceptWithDetails: (details) =>
          model.loadTrackRow(deck, details.data),
      builder: (context, candidates, rejected) {
        if (candidates.isEmpty) return content;
        return Stack(
          children: [
            content,
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: accent, width: 2),
                    color: accent.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Keylock extends StatelessWidget {
  const _Keylock({required this.on, required this.size, required this.onTap});

  final bool on;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Glyph(
            GlyphKind.keylock,
            size: size,
            color: on ? DeckThemeScope.accentOf(context) : T.faint,
          ),
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/core/format.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/device.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/units/unit_menu.dart';

// Bottom row flex: 2 : 3 : 2, i.e. left : centre : right = 1 : 1.5 : 1.
const int _sideFlex = 2;
const int _centreFlex = 3;

/// The beat controls laid over the left edge of a waveform. A mode key picks
/// loop / jump / manual, and the three keys beside it change with the mode.
/// Everything is translucent so the wave stays visible behind it.
class BeatBar extends StatefulWidget {
  const BeatBar({
    required this.model,
    required this.deck,
    required this.rowHeight,
    this.stacked = false,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final double rowHeight;
  final bool stacked;

  @override
  State<BeatBar> createState() => _BeatBarState();
}

class _BeatBarState extends State<BeatBar> {
  final _modeAnchor = GlobalKey();
  final _jumpAnchor = GlobalKey();

  BeatMode get _mode => widget.deck.beatMode;

  GlyphKind get _modeGlyph => switch (_mode) {
    BeatMode.beatloop => GlyphKind.loop,
    BeatMode.beatjump => GlyphKind.jump,
    BeatMode.manualloop => GlyphKind.manualLoop,
  };

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final deck = widget.deck;
    final stacked = widget.stacked;
    final barH = widget.rowHeight;
    final barW = (barH * (stacked ? 1.0 : 1.3)).clamp(
      stacked ? 96.0 : 112.0,
      stacked ? 112.0 : 150.0,
    );
    final s = ControlScale(barH, base: stacked ? 56 : 42);
    final mode = _mode;
    final manual = mode == BeatMode.manualloop && !deck.loopActive;

    Widget modeButton() => GestureDetector(
      key: _modeAnchor,
      behavior: HitTestBehavior.opaque,
      onTap: _pickMode,
      child: Container(
        decoration: keyFace(glass: true),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              capitalizeWords(mode.label),
              style: Ty.labelSmall.copyWith(
                fontSize: s.font(T.s8) * 0.9,
                color: T.text,
              ),
            ),
            SizedBox(width: s.size(4)),
            Glyph(GlyphKind.dropdown, size: s.size(8), color: T.text),
          ],
        ),
      ),
    );

    Widget centreKey() {
      final label = manual
          ? 'Call'
          : mode == BeatMode.beatjump
          ? '${deck.jumpSize}'
          : deck.loopLabel;
      return GlassKey(
        key: mode == BeatMode.beatjump && !manual ? _jumpAnchor : null,
        label: label,
        glyph: _modeGlyph,
        active: deck.loopActive,
        height: 24,
        fill: true,
        scale: s,
        onTap: manual
            ? () => model.toggleLoopCall(deck)
            : mode == BeatMode.beatjump
            ? _pickJump
            : () => model.toggleLoopActive(deck),
      );
    }

    Widget sideKey({
      required String label,
      required VoidCallback onTap,
      bool active = false,
    }) {
      final child = GlassKey(
        label: label,
        active: active,
        height: 24,
        fill: true,
        scale: s,
        onTap: onTap,
      );
      return Expanded(flex: _sideFlex, child: child);
    }

    final gap = SizedBox(width: s.size(2));
    final bottom = Row(
      children: manual
          ? [
              sideKey(
                label: 'In',
                active: deck.loopArmed,
                onTap: () => model.loopIn(deck),
              ),
              if (!stacked) gap,
              if (!stacked) Expanded(flex: _centreFlex, child: centreKey()),
              if (!stacked) gap,
              sideKey(label: 'Out', onTap: () => model.loopOut(deck)),
            ]
          : [
              sideKey(
                label: '-',
                onTap: () => mode == BeatMode.beatjump
                    ? model.jumpBy(deck, -1)
                    : model.stepLoop(deck, true),
              ),
              if (!stacked) gap,
              if (!stacked) Expanded(flex: _centreFlex, child: centreKey()),
              if (!stacked) gap,
              sideKey(
                label: '+',
                onTap: () => mode == BeatMode.beatjump
                    ? model.jumpBy(deck, 1)
                    : model.stepLoop(deck, false),
              ),
            ],
    );

    return Container(
      width: barW,
      height: barH,
      padding: EdgeInsets.symmetric(horizontal: s.size(2)),
      color: T.glass,
      child: Column(
        children: [
          Expanded(child: modeButton()),
          SizedBox(height: s.size(2)),
          if (stacked) ...[
            Expanded(child: centreKey()),
            SizedBox(height: s.size(2)),
          ],
          Expanded(child: bottom),
        ],
      ),
    );
  }

  void _pickMode() {
    showChoiceMenu(
      context: context,
      anchorKey: _modeAnchor,
      labels: BeatMode.values.map((mode) => mode.label).toList(),
      current: BeatMode.values.indexOf(_mode),
      onSelect: (index) =>
          widget.model.setBeatMode(widget.deck, BeatMode.values[index]),
    );
  }

  void _pickJump() {
    showChoiceMenu(
      context: context,
      anchorKey: _jumpAnchor,
      labels: jumpSizes.map((size) => '$size').toList(),
      current: widget.deck.jumpBeatsIndex,
      onSelect: (index) => widget.model.setJumpBeats(widget.deck, index),
    );
  }
}

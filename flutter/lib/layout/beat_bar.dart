import 'package:material_ui/material_ui.dart';

import '../state/app_model.dart';
import '../model/deck.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/glyph.dart';
import '../widgets/unit_menu.dart';

/// The beat controls laid over the left edge of a waveform. A mode key picks
/// loop / jump / manual, and the three keys beside it change with the mode.
/// Everything is translucent so the wave stays visible behind it.
class BeatBar extends StatefulWidget {
  const BeatBar({required this.model, required this.deck, super.key});

  final AppModel model;
  final DeckRuntime deck;

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
    return Container(
      width: 160,
      height: 30,
      padding: const EdgeInsets.all(3),
      color: T.glass,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: GlyphButton(
              key: _modeAnchor,
              glyph: _modeGlyph,
              size: 24,
              onTap: _pickMode,
            ),
          ),
          const SizedBox(width: 4),
          if (_mode == BeatMode.manualloop && !deck.loopActive) ...[
            Expanded(
              child: GlassKey(
                label: 'in',
                active: deck.loopArmed,
                height: 24,
                onTap: () => model.loopIn(deck),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: GlassKey(
                label: 'call',
                active: deck.loopActive,
                height: 24,
                onTap: () => model.toggleLoopCall(deck),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: GlassKey(
                label: 'out',
                height: 24,
                onTap: () => model.loopOut(deck),
              ),
            ),
          ] else ...[
            SizedBox(
              width: 24,
              height: 24,
              child: GlassKey(
                label: '-',
                height: 24,
                onTap:
                    _mode == BeatMode.beatloop || _mode == BeatMode.manualloop
                    ? () => model.stepLoop(deck, true)
                    : () => model.jumpBy(deck, -1),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _mode == BeatMode.beatjump
                  ? GlassKey(
                      key: _jumpAnchor,
                      label: '${deck.jumpSize}',
                      suffix: 'jump',
                      height: 24,
                      onTap: _pickJump,
                    )
                  : GlassKey(
                      label: deck.loopLabel,
                      suffix: 'beats',
                      active: deck.loopActive,
                      height: 24,
                      onTap: () => model.toggleLoopActive(deck),
                    ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 24,
              height: 24,
              child: GlassKey(
                label: '+',
                height: 24,
                onTap:
                    _mode == BeatMode.beatloop || _mode == BeatMode.manualloop
                    ? () => model.stepLoop(deck, false)
                    : () => model.jumpBy(deck, 1),
              ),
            ),
          ],
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

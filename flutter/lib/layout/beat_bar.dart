import 'package:material_ui/material_ui.dart';

import '../state/app_model.dart';
import '../model/deck.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/device.dart';
import '../widgets/glyph.dart';
import '../widgets/unit_menu.dart';

/// The beat controls laid over the left edge of a waveform. A mode key picks
/// loop / jump / manual, and the three keys beside it change with the mode.
/// Everything is translucent so the wave stays visible behind it.
class BeatBar extends StatefulWidget {
  const BeatBar({
    required this.model,
    required this.deck,
    this.scale,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final ControlScale? scale;

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
    final s = widget.scale ?? ControlScale.fallback;
    final mode = _mode;
    final manual = mode == BeatMode.manualloop && !deck.loopActive;

    Widget key({
      required String label,
      required VoidCallback onTap,
      String? suffix,
      bool active = false,
      bool expand = false,
      GlobalKey? anchor,
      double width = 34,
    }) {
      final child = GlassKey(
        key: anchor,
        label: label,
        suffix: suffix,
        active: active,
        height: 24,
        fill: true,
        scale: s,
        onTap: onTap,
      );
      return expand
          ? Expanded(child: child)
          : SizedBox(width: s.size(width), child: child);
    }

    return Container(
      width: s.size(132),
      height: s.size(42),
      padding: EdgeInsets.all(s.size(2)),
      color: T.glass,
      child: Column(
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(
              key: _modeAnchor,
              behavior: HitTestBehavior.opaque,
              onTap: _pickMode,
              child: Container(
                decoration: keyFace(glass: true),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Glyph(_modeGlyph, size: s.size(12), color: T.dim),
                    SizedBox(width: s.size(3)),
                    Text(
                      mode.label.toUpperCase(),
                      style: Ty.labelSmall.copyWith(
                        fontSize: s.font(T.s8),
                        color: T.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: s.size(2)),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (manual) ...[
                  key(
                    label: 'in',
                    active: deck.loopArmed,
                    onTap: () => model.loopIn(deck),
                  ),
                  SizedBox(width: s.size(2)),
                  key(
                    label: 'call',
                    active: deck.loopActive,
                    expand: true,
                    onTap: () => model.toggleLoopCall(deck),
                  ),
                  SizedBox(width: s.size(2)),
                  key(label: 'out', onTap: () => model.loopOut(deck)),
                ] else ...[
                  key(
                    label: '-',
                    onTap: () => mode == BeatMode.beatjump
                        ? model.jumpBy(deck, -1)
                        : model.stepLoop(deck, true),
                  ),
                  SizedBox(width: s.size(2)),
                  if (mode == BeatMode.beatjump)
                    key(
                      label: '${deck.jumpSize}',
                      suffix: 'jump',
                      expand: true,
                      anchor: _jumpAnchor,
                      onTap: _pickJump,
                    )
                  else
                    key(
                      label: deck.loopLabel,
                      suffix: 'beats',
                      active: deck.loopActive,
                      expand: true,
                      onTap: () => model.toggleLoopActive(deck),
                    ),
                  SizedBox(width: s.size(2)),
                  key(
                    label: '+',
                    onTap: () => mode == BeatMode.beatjump
                        ? model.jumpBy(deck, 1)
                        : model.stepLoop(deck, false),
                  ),
                ],
              ],
            ),
          ),
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

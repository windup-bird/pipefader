import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/units/deck_picker.dart';
import 'package:pipefader_gui/core/device.dart';
import 'package:pipefader_gui/core/glyph.dart';

/// The transport stack shared by the desk and the phone. Heights come from the
/// available space, not fixed keys: sync stays the small key and cue / play
/// share what is left.
class TransportKeys extends StatelessWidget {
  const TransportKeys({
    required this.model,
    required this.deck,
    required this.column,
    required this.usePhoneDecks,
    required this.keyHeight,
    this.scale,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final int column;
  final bool usePhoneDecks;
  final double keyHeight;
  final ControlScale? scale;

  @override
  Widget build(BuildContext context) {
    final hasChoice = usePhoneDecks
        ? model.phoneHasDeckChoice
        : model.fullHasDeckChoice;
    final s = scale ?? ControlScale.fallback;
    final syncSize = s.font(T.s11);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasChoice) ...[
          DeckPicker(
            model: model,
            column: column,
            usePhoneDecks: usePhoneDecks,
            expand: true,
            buttonHeight: keyHeight,
          ),
          SizedBox(height: s.size(4)),
        ],
        SizedBox(
          height: keyHeight,
          child: PanelButton(
            label: 'sync',
            active: deck.sync,
            style: Ty.button.copyWith(fontSize: syncSize, letterSpacing: 0.4),
            onTap: () => model.toggleSync(deck),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          flex: 5,
          child: PanelButton(
            label: 'CUE',
            style: Ty.button.copyWith(fontSize: s.font(T.s12)),
            onTap: () => model.cue(deck),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          flex: 5,
          child: _PlayButton(
            key: ValueKey('play-$column'),
            deck: deck,
            scale: s,
            onTap: () => model.togglePlay(deck),
          ),
        ),
      ],
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({
    required this.deck,
    required this.scale,
    required this.onTap,
    super.key,
  });

  final DeckRuntime deck;
  final ControlScale scale;
  final VoidCallback onTap;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.deck.playing;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: Container(
          decoration: keyFace(active: active, pressed: _pressed, hover: _hover),
          alignment: Alignment.center,
          child: Glyph(
            GlyphKind.play,
            size: widget.scale.size(20),
            color: active ? T.text : (_hover ? T.text : T.dim),
          ),
        ),
      ),
    );
  }
}

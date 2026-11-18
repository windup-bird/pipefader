import 'package:material_ui/material_ui.dart';

import '../state/app_model.dart';
import '../theme.dart';
import 'buttons.dart';
import 'deck_picker.dart';

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
            label: 'cue',
            style: Ty.button.copyWith(fontSize: s.font(T.s12)),
            onTap: () => model.cue(deck),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          flex: 5,
          child: PanelButton(
            label: deck.playing ? 'pause' : 'play',
            active: deck.playing,
            style: Ty.button.copyWith(fontSize: s.font(T.s12)),
            onTap: () => model.togglePlay(deck),
          ),
        ),
      ],
    );
  }
}

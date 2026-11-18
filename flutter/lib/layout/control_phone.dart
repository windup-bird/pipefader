import 'package:material_ui/material_ui.dart';

import 'layout_mode.dart';
import '../model/deck.dart';
import '../state/app_model.dart';
import '../theme.dart';
import '../units/unit_body.dart';
import '../widgets/bar_fader.dart';
import '../widgets/glyph.dart';
import '../widgets/transport_keys.dart';
import '../widgets/unit_header.dart';

/// One deck's touch block: sync and play+cue on one side, a vertical fader on
/// the other, and the single unit between them. Tempo lives in the deck info.
/// In landscape the right-hand deck is mirrored so the pair is symmetrical.
class PhoneDeck extends StatelessWidget {
  const PhoneDeck({
    required this.model,
    required this.deck,
    required this.column,
    this.mirrored = false,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final int column;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final keyH = controlKeyHeight(constraints.maxHeight);
        final scale = ControlScale(constraints.maxHeight);
        final leftW = (width * 0.23).clamp(64.0, 94.0);
        final faderW = (width * 0.15).clamp(44.0, 62.0);
        final left = SizedBox(
          width: leftW,
          child: TransportKeys(
            model: model,
            deck: deck,
            column: column,
            usePhoneDecks: true,
            keyHeight: keyH,
            scale: scale,
          ),
        );
        final unit = Expanded(
          child: _PhoneUnit(
            model: model,
            deck: deck,
            keyHeight: keyH,
            scale: scale,
          ),
        );
        final fader = SizedBox(
          width: faderW,
          child: _Fader(model: model, deck: deck, scale: scale),
        );
        final children = mirrored
            ? <Widget>[
                fader,
                const SizedBox(width: 6),
                unit,
                const SizedBox(width: 6),
                left,
              ]
            : <Widget>[
                left,
                const SizedBox(width: 6),
                unit,
                const SizedBox(width: 6),
                fader,
              ];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

/// One phone unit: the same tab row as the desk, with the single panel below.
class _PhoneUnit extends StatelessWidget {
  const _PhoneUnit({
    required this.model,
    required this.deck,
    required this.keyHeight,
    required this.scale,
  });

  final AppModel model;
  final DeckRuntime deck;
  final double keyHeight;
  final ControlScale scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        UnitHeader(
          model: model,
          deck: deck,
          slot: ControlSlot.phone,
          height: keyHeight,
          scale: scale,
        ),
        Expanded(
          child: buildUnit(
            kind: deck.phoneUnit,
            model: model,
            deck: deck,
            scale: scale,
          ),
        ),
      ],
    );
  }
}

class _Fader extends StatelessWidget {
  const _Fader({required this.model, required this.deck, required this.scale});

  final AppModel model;
  final DeckRuntime deck;
  final ControlScale scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Glyph(GlyphKind.chevronDown, size: scale.size(8), color: T.faint),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: scale.size(2)),
            child: BarFader(
              value: deck.fader,
              scale: scale,
              onChanged: (value) => model.setFader(deck, value),
            ),
          ),
        ),
        Glyph(GlyphKind.chevronUp, size: scale.size(8), color: T.faint),
      ],
    );
  }
}

/// Two phone blocks side by side, mirrored in landscape. With three decks the
/// left block's picker offers 1 and 3, like the full control band.
class PhoneControlRow extends StatelessWidget {
  const PhoneControlRow({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: PhoneDeck(
            model: model,
            deck: model.decks[model.phoneSlotDeck(0)],
            column: 0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PhoneDeck(
            model: model,
            deck: model.decks[model.phoneSlotDeck(1)],
            column: 1,
            mirrored: true,
          ),
        ),
      ],
    );
  }
}

/// The stacked form: the same two blocks, one above the other.
class PhoneControlColumn extends StatelessWidget {
  const PhoneControlColumn({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: PhoneDeck(
            model: model,
            deck: model.decks[model.phoneSlotDeck(0)],
            column: 0,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: PhoneDeck(
            model: model,
            deck: model.decks[model.phoneSlotDeck(1)],
            column: 1,
          ),
        ),
      ],
    );
  }
}

/// A tiny deck number on the phone. It only appears when that column has more
/// than one deck to cycle through.

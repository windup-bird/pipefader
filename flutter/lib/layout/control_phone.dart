import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../model/deck.dart';
import '../state/app_model.dart';
import '../theme.dart';
import '../units/unit_body.dart';
import '../widgets/bar_fader.dart';
import '../widgets/buttons.dart';
import '../widgets/deck_picker.dart';
import '../widgets/glyph.dart';
import '../widgets/unit_menu.dart';

const List<UnitKind> phoneUnits = <UnitKind>[UnitKind.pads, UnitKind.mixerMax];

/// One deck's touch block: sync / tempo / play+cue on one side, a vertical
/// fader on the other, and the single unit between them. In landscape the
/// right-hand deck is mirrored so the pair is symmetrical.
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
        final leftW = (width * 0.23).clamp(64.0, 94.0);
        final faderW = (width * 0.15).clamp(44.0, 62.0);
        final left = SizedBox(
          width: leftW,
          child: _DeckKeys(model: model, deck: deck, column: column),
        );
        final unit = Expanded(
          child: _PhoneUnit(model: model, deck: deck),
        );
        final fader = SizedBox(
          width: faderW,
          child: _Fader(model: model, deck: deck),
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

class _DeckKeys extends StatelessWidget {
  const _DeckKeys({
    required this.model,
    required this.deck,
    required this.column,
  });

  final AppModel model;
  final DeckRuntime deck;
  final int column;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (model.phoneHasDeckChoice) ...[
          DeckPicker(
            model: model,
            column: column,
            usePhoneDecks: true,
            expand: true,
          ),
          const SizedBox(height: 2),
        ],
        SizedBox(
          height: 20,
          child: PanelButton(
            label: 'sync',
            active: deck.sync,
            style: Ty.button.copyWith(fontSize: T.s9, letterSpacing: 0.4),
            onTap: () => model.toggleSync(deck),
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: TempoTouch(model: model, deck: deck),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 24,
          child: Row(
            children: [
              Expanded(
                child: PanelButton(
                  label: 'play',
                  active: deck.playing,
                  style: Ty.button.copyWith(fontSize: T.s9),
                  onTap: () => model.togglePlay(deck),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: PanelButton(
                  label: 'cue',
                  style: Ty.button.copyWith(fontSize: T.s9),
                  onTap: () => model.cue(deck),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The BPM readout doubles as a control surface: vertical drag changes tempo
/// relatively, horizontal drag bends. A ruler appears while dragging, with 0.1
/// BPM minor ticks and 1 BPM major ticks.
class TempoTouch extends StatefulWidget {
  const TempoTouch({required this.model, required this.deck, super.key});

  final AppModel model;
  final DeckRuntime deck;

  @override
  State<TempoTouch> createState() => _TempoTouchState();
}

class _TempoTouchState extends State<TempoTouch> {
  bool _dragging = false;
  double _bend = 0;

  @override
  Widget build(BuildContext context) {
    final deck = widget.deck;
    final bending = deck.nudge != 0;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => setState(() => _dragging = true),
        onVerticalDragUpdate: (details) {
          widget.model.adjustTempo(deck, -details.delta.dy * 0.00022);
        },
        onVerticalDragEnd: (_) {
          if (mounted) setState(() => _dragging = false);
        },
        onVerticalDragCancel: () {
          if (mounted) setState(() => _dragging = false);
        },
        onHorizontalDragStart: (_) {
          _bend = 0;
        },
        onHorizontalDragUpdate: (details) {
          _bend += details.delta.dx * 0.0009;
          widget.model.setNudge(deck, _bend);
        },
        onHorizontalDragEnd: (_) {
          _bend = 0;
          widget.model.releaseBend(deck);
        },
        onHorizontalDragCancel: () {
          _bend = 0;
          widget.model.releaseBend(deck);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  bpmText(deck.bpm),
                  maxLines: 1,
                  style: Ty.phoneBpm.copyWith(
                    color: bending ? T.accent : T.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bending ? tempoText(1 + deck.nudge) : tempoText(deck.tempo),
                  style: Ty.phoneMeta.copyWith(
                    color: bending
                        ? T.accent
                        : deck.tempo == 1
                        ? T.faint
                        : T.accentHi,
                  ),
                ),
              ],
            ),
            if (_dragging)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 26,
                child: _BpmRuler(bpm: deck.bpm),
              ),
          ],
        ),
      ),
    );
  }
}

class _BpmRuler extends StatelessWidget {
  const _BpmRuler({required this.bpm});

  final double bpm;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BpmRulerPainter(bpm), size: Size.infinite);
  }
}

class _BpmRulerPainter extends CustomPainter {
  _BpmRulerPainter(this.bpm);

  final double bpm;

  static const _span = 2.4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = T.scrim.withValues(alpha: 0.55),
    );
    final height = size.height;
    final centre = height / 2;
    final first = ((bpm - _span) * 10).floor() / 10;
    final last = ((bpm + _span) * 10).ceil() / 10;
    final minor = Paint()
      ..color = T.dim.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = T.text.withValues(alpha: 0.8)
      ..strokeWidth = 1;

    for (var tick = first; tick <= last + 0.001; tick += 0.1) {
      final y = centre - (tick - bpm) / _span * (height / 2);
      if (y < 0 || y > height) continue;
      final isMajor = ((tick * 10).round() % 10 == 0);
      canvas.drawLine(
        Offset(size.width - (isMajor ? 11 : 5), y),
        Offset(size.width, y),
        isMajor ? major : minor,
      );
      if (isMajor) {
        final label = tick.round().toString();
        final text = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(fontSize: T.s8, color: T.dim, height: 1.0),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          Offset(size.width - 14 - text.width, y - text.height / 2),
        );
      }
    }
    canvas.drawLine(
      Offset(size.width - 16, centre),
      Offset(size.width, centre),
      Paint()
        ..color = T.accent
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_BpmRulerPainter old) => old.bpm != bpm;
}

class _PhoneUnit extends StatefulWidget {
  const _PhoneUnit({required this.model, required this.deck});

  final AppModel model;
  final DeckRuntime deck;

  @override
  State<_PhoneUnit> createState() => _PhoneUnitState();
}

class _PhoneUnitState extends State<_PhoneUnit> {
  final _anchor = GlobalKey();
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final kind = widget.deck.phoneUnit;
    return Column(
      children: [
        Expanded(
          child: buildUnit(kind: kind, model: widget.model, deck: widget.deck),
        ),
        SizedBox(
          height: 14,
          child: Center(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: GestureDetector(
                key: _anchor,
                behavior: HitTestBehavior.opaque,
                onTap: () => showChoiceMenu(
                  context: context,
                  anchorKey: _anchor,
                  labels: phoneUnits.map((unit) => unit.label).toList(),
                  current: phoneUnits.indexOf(kind),
                  onSelect: (index) =>
                      widget.model.setPhoneUnit(widget.deck, phoneUnits[index]),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        kind.label.toUpperCase(),
                        style: Ty.labelSmall.copyWith(
                          color: _hover ? T.accentHi : T.accent,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Glyph(
                        GlyphKind.dropdown,
                        size: 7,
                        color: _hover ? T.accentHi : T.faint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Fader extends StatelessWidget {
  const _Fader({required this.model, required this.deck});

  final AppModel model;
  final DeckRuntime deck;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Glyph(GlyphKind.chevronDown, size: 8, color: T.faint),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: BarFader(
              value: deck.fader,
              onChanged: (value) => model.setFader(deck, value),
            ),
          ),
        ),
        Glyph(GlyphKind.chevronUp, size: 8, color: T.faint),
      ],
    );
  }
}

/// Two phone blocks side by side, mirrored in landscape. With three decks the
/// left block's deck chip cycles 1 ⇄ 3, like the full control band.
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

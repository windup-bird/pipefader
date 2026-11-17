import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../state/app_model.dart';
import '../theme.dart';
import '../widgets/bar_fader.dart';
import '../widgets/buttons.dart';
import '../widgets/unit_menu.dart';

/// Tempo: sync state, the BPM with its two step keys, the fader range and the
/// bend pair. Four rows, centred, nothing else.
class TempoPanel extends StatelessWidget {
  const TempoPanel({required this.model, required this.deck, super.key});

  final AppModel model;
  final DeckRuntime deck;

  @override
  Widget build(BuildContext context) {
    final synced = deck.sync;
    final syncLabel = !synced
        ? 'sync off'
        : model.decks.indexOf(deck) == 0
        ? 'sync leader'
        : 'sync follower';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          syncLabel,
          style: Ty.label.copyWith(color: synced ? T.accent : T.faint),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PanelButton(
              label: '-',
              width: 26,
              height: 26,
              onTap: () => model.adjustTempo(deck, -0.001),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 74,
              child: Text(
                bpmText(deck.bpm),
                textAlign: TextAlign.center,
                style: Ty.bpm,
              ),
            ),
            const SizedBox(width: 10),
            PanelButton(
              label: '+',
              width: 26,
              height: 26,
              onTap: () => model.adjustTempo(deck, 0.001),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'RANGE ±${(deck.view.tempoRange * 100).round()}% · '
          '${tempoText(deck.tempo)}',
          style: Ty.labelSmall,
        ),
        const SizedBox(height: 6),
        _BendRow(model: model, deck: deck),
      ],
    );
  }
}

/// The beat panel, as the plan draws it: one three-column grid. The left
/// column is the step keys, the centre the value or call key, the right the
/// other step key — so the rows line up and a longer number never shifts a key.
class BeatctlPanel extends StatefulWidget {
  const BeatctlPanel({required this.model, required this.deck, super.key});

  final AppModel model;
  final DeckRuntime deck;

  @override
  State<BeatctlPanel> createState() => _BeatctlPanelState();
}

class _BeatctlPanelState extends State<BeatctlPanel> {
  final _jumpAnchor = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final deck = widget.deck;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The three columns are 1:2:1, so the side keys cover one pad column and
        // the centre two, and the rows fill the pad grid's height edge to edge.
        const gap = 4.0;
        final side = (constraints.maxWidth - 2 * gap) / 4;
        final centre = side * 2;
        return Column(
          children: [
            Expanded(
              child: _BeatRow(
                side: side,
                centre: centre,
                left: PanelButton(
                  label: '-',
                  onTap: () => model.stepLoop(deck, true),
                ),
                center: Center(
                  child: _ValueLabel(value: deck.loopLabel, label: 'loop'),
                ),
                right: PanelButton(
                  label: '+',
                  onTap: () => model.stepLoop(deck, false),
                ),
              ),
            ),
            const SizedBox(height: gap),
            Expanded(
              child: _BeatRow(
                side: side,
                centre: centre,
                left: PanelButton(
                  label: 'in',
                  active: deck.loopArmed,
                  onTap: () => model.loopIn(deck),
                ),
                center: PanelButton(
                  label: 'call',
                  active: deck.loopActive,
                  onTap: () => model.toggleLoopCall(deck),
                ),
                right: PanelButton(
                  label: 'out',
                  onTap: () => model.loopOut(deck),
                ),
              ),
            ),
            const SizedBox(height: gap),
            Expanded(
              child: _BeatRow(
                side: side,
                centre: centre,
                left: PanelButton(
                  label: '<',
                  onTap: () => model.jumpBy(deck, -1),
                ),
                center: _JumpButton(
                  anchorKey: _jumpAnchor,
                  size: deck.jumpSize,
                  onTap: _pickJump,
                ),
                right: PanelButton(
                  label: '>',
                  onTap: () => model.jumpBy(deck, 1),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _pickJump() {
    showChoiceMenu(
      context: context,
      anchorKey: _jumpAnchor,
      labels: jumpSizes.map((size) => '$size').toList(),
      current: widget.deck.jumpSizeIndex,
      onSelect: (index) => widget.model.setJumpSize(widget.deck, index),
    );
  }
}

/// One row of the beat grid: fixed key column | value column | fixed key
/// column. Every row uses it, so the three keys stack in two vertical lines.
class _BeatRow extends StatelessWidget {
  const _BeatRow({
    required this.side,
    required this.centre,
    required this.left,
    required this.center,
    required this.right,
  });

  final double side;
  final double centre;
  final Widget left;
  final Widget center;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: side, child: left),
        const SizedBox(width: 4),
        SizedBox(width: centre, child: center),
        const SizedBox(width: 4),
        SizedBox(width: side, child: right),
      ],
    );
  }
}

class _ValueLabel extends StatelessWidget {
  const _ValueLabel({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: Ty.num.copyWith(fontSize: T.s16, fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: ' $label',
            style: const TextStyle(fontSize: T.s9, color: T.faint),
          ),
        ],
      ),
    );
  }
}

class _JumpButton extends StatefulWidget {
  const _JumpButton({
    required this.anchorKey,
    required this.size,
    required this.onTap,
  });

  final GlobalKey anchorKey;
  final int size;
  final VoidCallback onTap;

  @override
  State<_JumpButton> createState() => _JumpButtonState();
}

class _JumpButtonState extends State<_JumpButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        key: widget.anchorKey,
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          alignment: Alignment.center,
          color: _hover ? T.surfaceHi : T.surface,
          child: _ValueLabel(value: '${widget.size}', label: 'jump'),
        ),
      ),
    );
  }
}

class _BendRow extends StatelessWidget {
  const _BendRow({required this.model, required this.deck});

  final AppModel model;
  final DeckRuntime deck;

  @override
  Widget build(BuildContext context) {
    final bending = deck.nudge != 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _HoldKey(
          label: '<',
          onDown: () => model.bend(deck, -1),
          onUp: () => model.releaseBend(deck),
        ),
        const SizedBox(width: 10),
        Text(
          bending ? 'BEND ${tempoText(1 + deck.nudge)}' : 'BEND',
          style: Ty.label.copyWith(color: bending ? T.accent : T.faint),
        ),
        const SizedBox(width: 10),
        _HoldKey(
          label: '>',
          onDown: () => model.bend(deck, 1),
          onUp: () => model.releaseBend(deck),
        ),
      ],
    );
  }
}

/// A key that acts while the pointer is held, like a pitch bend.
class _HoldKey extends StatefulWidget {
  const _HoldKey({
    required this.label,
    required this.onDown,
    required this.onUp,
  });

  final String label;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  State<_HoldKey> createState() => _HoldKeyState();
}

class _HoldKeyState extends State<_HoldKey> {
  bool _held = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          setState(() => _held = true);
          widget.onDown();
        },
        onPointerUp: (_) {
          if (!_held) return;
          setState(() => _held = false);
          widget.onUp();
        },
        onPointerCancel: (_) {
          if (!_held) return;
          setState(() => _held = false);
          widget.onUp();
        },
        child: Container(
          width: 26,
          height: 26,
          color: _held ? T.accent : T.surface,
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: Ty.button.copyWith(color: _held ? T.bg : T.dim),
          ),
        ),
      ),
    );
  }
}

/// The channel strip: high / mid / low / filter as vertical bars.
class MixerPanel extends StatelessWidget {
  const MixerPanel({required this.model, required this.deck, super.key});

  final AppModel model;
  final DeckRuntime deck;

  @override
  Widget build(BuildContext context) {
    final values = [deck.high, deck.mid, deck.low, deck.filter];
    const labels = ['HIGH', 'MID', 'LOW', 'FILT'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: BarFader(
                      value: values[i],
                      bipolar: true,
                      handleHeight: 5,
                      onChanged: (value) => model.setEq(deck, i, value),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(labels[i], style: Ty.labelSmall),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One FX slot: beat division, two parameters, hold/instant, and the slot name
/// which opens the picker.
class FxPanel extends StatelessWidget {
  const FxPanel({required this.model, required this.deck, super.key});

  final AppModel model;
  final DeckRuntime deck;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PanelButton(
                label: '-',
                width: 20,
                height: 20,
                onTap: () => model.stepBeats(deck, true),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  fxBeats[deck.beatsIndex],
                  textAlign: TextAlign.center,
                  style: Ty.num.copyWith(fontSize: T.s14),
                ),
              ),
              const SizedBox(width: 8),
              PanelButton(
                label: '+',
                width: 20,
                height: 20,
                onTap: () => model.stepBeats(deck, false),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _ParamSlider(
            label: 'FB',
            value: deck.fx1,
            onChanged: (value) => model.setFxParam(deck, 0, value),
          ),
          const SizedBox(height: 4),
          _ParamSlider(
            label: 'MIX',
            value: deck.fx2,
            onChanged: (value) => model.setFxParam(deck, 1, value),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: PanelButton(
                  label: 'hold',
                  active: deck.fxHold,
                  height: 24,
                  onTap: () => model.setFxHold(deck, true),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: PanelButton(
                  label: 'instant',
                  active: !deck.fxHold,
                  height: 24,
                  onTap: () => model.setFxHold(deck, false),
                ),
              ),
            ],
          ),
          const Spacer(),
          _FxName(model: model, deck: deck),
        ],
      ),
    );
  }
}

class _ParamSlider extends StatefulWidget {
  const _ParamSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_ParamSlider> createState() => _ParamSliderState();
}

class _ParamSliderState extends State<_ParamSlider> {
  bool _active = false;
  double _value = 0;

  @override
  void initState() {
    super.initState();
    _value = widget.value.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(_ParamSlider old) {
    super.didUpdateWidget(old);
    if (!_active) _value = widget.value.clamp(0.0, 1.0);
  }

  void _setFromLocal(Offset local, double width) {
    setState(() => _value = (local.dx / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 26, child: Text(widget.label, style: Ty.labelSmall)),
        const SizedBox(width: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  setState(() => _active = true);
                  _setFromLocal(event.localPosition, width);
                },
                onPointerMove: (event) {
                  if (!_active) return;
                  _setFromLocal(event.localPosition, width);
                },
                onPointerUp: (_) {
                  setState(() => _active = false);
                  widget.onChanged(_value);
                },
                onPointerCancel: (_) {
                  setState(() => _active = false);
                  widget.onChanged(_value);
                },
                child: Container(
                  height: 8,
                  color: T.surface,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _value,
                    child: Container(color: T.accent),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FxName extends StatefulWidget {
  const _FxName({required this.model, required this.deck});

  final AppModel model;
  final DeckRuntime deck;

  @override
  State<_FxName> createState() => _FxNameState();
}

class _FxNameState extends State<_FxName> {
  final _anchor = GlobalKey();
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showChoiceMenu(
          context: context,
          anchorKey: _anchor,
          labels: fxSlots,
          current: widget.deck.fxSlot,
          onSelect: (index) => widget.model.setFxSlot(widget.deck, index),
        ),
        child: Container(
          key: _anchor,
          height: 20,
          alignment: Alignment.center,
          child: Text(
            fxSlots[widget.deck.fxSlot].toUpperCase(),
            style: Ty.label.copyWith(color: _hover ? T.text : T.dim),
          ),
        ),
      ),
    );
  }
}

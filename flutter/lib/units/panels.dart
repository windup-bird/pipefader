import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../model/deck.dart';
import '../state/app_model.dart';
import '../theme.dart';
import '../widgets/bar_fader.dart';
import '../widgets/buttons.dart';
import '../widgets/device.dart';
import '../widgets/glyph.dart';
import '../widgets/pad_grid.dart';
import '../widgets/unit_menu.dart';

/// The pads slot: the pad modes above the grid, like a hardware pad section.
class PadsPanel extends StatelessWidget {
  const PadsPanel({required this.model, required this.deck, super.key});

  final AppModel model;
  final DeckRuntime deck;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 18,
          child: Center(
            child: ModeTabs(
              labels: PadMode.values.map((mode) => mode.label).toList(),
              selected: PadMode.values.indexOf(deck.padMode),
              onSelect: (index) =>
                  model.setPadMode(deck, PadMode.values[index]),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: PadGrid(model: model, deck: deck),
        ),
      ],
    );
  }
}

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
        : model.decks.indexOf(deck).isEven
        ? 'sync leader'
        : 'sync follower';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          syncLabel,
          style: Ty.label.copyWith(color: synced ? T.accent : T.faint),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PanelButton(
              label: '-',
              width: 24,
              height: 24,
              onTap: () => model.adjustTempo(deck, -0.001),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 66,
              child: Text(
                bpmText(deck.bpm),
                textAlign: TextAlign.center,
                style: Ty.bpm,
              ),
            ),
            const SizedBox(width: 8),
            PanelButton(
              label: '+',
              width: 24,
              height: 24,
              onTap: () => model.adjustTempo(deck, 0.001),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'range ±${(deck.view.tempoRange * 100).round()}% · ${tempoText(deck.tempo)}',
          style: Ty.labelSmall,
        ),
        const SizedBox(height: 6),
        _BendRow(model: model, deck: deck),
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
            style: Ty.num.copyWith(
              fontSize: T.s16,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: const TextStyle(fontSize: T.s9, color: T.faint),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.clip,
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
        SizedBox(
          width: 24,
          height: 24,
          child: HoldKey(
            label: '<',
            onDown: () => model.bend(deck, -1),
            onUp: () => model.releaseBend(deck),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          bending ? 'BEND ${tempoText(1 + deck.nudge)}' : 'BEND',
          style: Ty.label.copyWith(color: bending ? T.accent : T.faint),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 24,
          height: 24,
          child: HoldKey(
            label: '>',
            onDown: () => model.bend(deck, 1),
            onUp: () => model.releaseBend(deck),
          ),
        ),
      ],
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

    Widget eqFader(int index) => Expanded(
      child: Column(
        children: [
          Expanded(
            child: BarFader(
              value: values[index],
              bipolar: true,
              handleHeight: 5,
              onChanged: (value) => model.setEq(deck, index, value),
            ),
          ),
          const SizedBox(height: 6),
          Text(labels[index], style: Ty.labelSmall),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            eqFader(i),
          ],
        ],
      ),
    );
  }
}

/// One FX slot: beat division, two parameters and the slot name. The name
/// toggles the slot; the small arrow opens the picker.
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
          SizedBox(
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PanelButton(
                  label: '-',
                  width: 20,
                  height: 20,
                  onTap: () => model.stepBeats(deck, true),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Center(
                    child: _ValueLabel(
                      value: fxBeats[deck.beatsIndex],
                      label: 'beats',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                PanelButton(
                  label: '+',
                  width: 20,
                  height: 20,
                  onTap: () => model.stepBeats(deck, false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ParamBar(
              label: 'FB',
              value: deck.fx1,
              onChanged: (value) => model.setFxParam(deck, 0, value),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: ParamBar(
              label: 'MIX',
              value: deck.fx2,
              onChanged: (value) => model.setFxParam(deck, 1, value),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 24,
            child: Center(
              child: _FxName(model: model, deck: deck),
            ),
          ),
        ],
      ),
    );
  }
}

const double _mixerMaxLabelH = 18;

/// The phone's combined strip: four tone/filter faders and the FX param1
/// fader, all vertical and on the same baseline.
class MixerMaxPanel extends StatelessWidget {
  const MixerMaxPanel({required this.model, required this.deck, super.key});

  final AppModel model;
  final DeckRuntime deck;

  @override
  Widget build(BuildContext context) {
    final values = [deck.high, deck.mid, deck.low, deck.filter];
    const labels = ['HI', 'MID', 'LO', 'FIL'];

    Widget eqFader(int index) => Expanded(
      child: _MixerMaxFader(
        value: values[index],
        bipolar: true,
        onChanged: (value) => model.setEq(deck, index, value),
        label: Text(
          labels[index],
          style: Ty.labelSmall.copyWith(fontSize: T.s8),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            eqFader(i),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: _MixerMaxFader(
              value: deck.fx1,
              onChanged: (value) => model.setFxParam(deck, 0, value),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: _FxName(model: model, deck: deck, compact: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MixerMaxFader extends StatelessWidget {
  const _MixerMaxFader({
    required this.value,
    required this.onChanged,
    required this.label,
    this.bipolar = false,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final Widget label;
  final bool bipolar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BarFader(
            value: value,
            bipolar: bipolar,
            handleHeight: 4,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          height: _mixerMaxLabelH,
          child: Center(child: label),
        ),
      ],
    );
  }
}

/// A horizontal parameter fader: label, track and metal handle. The slot
/// widens while held, like the channel faders.
class ParamBar extends StatefulWidget {
  const ParamBar({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<ParamBar> createState() => _ParamBarState();
}

class _ParamBarState extends State<ParamBar> {
  static const _handleW = 8.0;

  bool _active = false;
  bool _hover = false;
  double _value = 0;
  double _lastX = 0;

  @override
  void initState() {
    super.initState();
    _value = widget.value.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(ParamBar old) {
    super.didUpdateWidget(old);
    if (!_active) _value = widget.value.clamp(0.0, 1.0);
  }

  void _setFromDrag(double x, double width) {
    final travel = width - _handleW;
    if (travel <= 0) return;
    final dx = x - _lastX;
    _lastX = x;
    setState(() => _value = (_value + dx / travel).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 22, child: Text(widget.label, style: Ty.labelSmall)),
        const SizedBox(width: 5),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final handleX = _handleW / 2 + _value * (width - _handleW);
              return MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                onEnter: (_) => setState(() => _hover = true),
                onExit: (_) => setState(() => _hover = false),
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    setState(() {
                      _active = true;
                      _lastX = event.localPosition.dx;
                    });
                  },
                  onPointerMove: (event) {
                    if (!_active) return;
                    _setFromDrag(event.localPosition.dx, width);
                  },
                  onPointerUp: (_) {
                    if (!_active) return;
                    setState(() => _active = false);
                    widget.onChanged(_value);
                  },
                  onPointerCancel: (_) {
                    if (!_active) return;
                    setState(() => _active = false);
                    widget.onChanged(_value);
                  },
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: _active ? height - 2 : 3),
                    duration: const Duration(milliseconds: 110),
                    curve: Curves.easeOut,
                    builder: (context, slot, _) {
                      return Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: (height - slot) / 2,
                            height: slot,
                            child: DecoratedBox(decoration: slotFace()),
                          ),
                          Positioned(
                            left: 0,
                            top: (height - slot) / 2,
                            width: handleX,
                            height: slot,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [T.accentLo, T.accent],
                                ),
                                boxShadow: _active
                                    ? const [
                                        BoxShadow(
                                          color: T.glowAccent,
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                          Positioned(
                            left: handleX - _handleW / 2,
                            top: 0,
                            width: _handleW,
                            height: height,
                            child: DecoratedBox(
                              decoration: handleFace(
                                active: _active,
                                hover: _hover,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
  const _FxName({
    required this.model,
    required this.deck,
    this.compact = false,
  });

  final AppModel model;
  final DeckRuntime deck;
  final bool compact;

  @override
  State<_FxName> createState() => _FxNameState();
}

class _FxNameState extends State<_FxName> {
  final _anchor = GlobalKey();
  bool _nameHover = false;
  bool _selectHover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.deck.fxOn;
    final compact = widget.compact;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _nameHover = true),
          onExit: (_) => setState(() => _nameHover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.model.toggleFx(widget.deck),
            child: Container(
              height: compact ? 18 : 24,
              padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 8),
              decoration: keyFace(active: on, hover: _nameHover),
              alignment: Alignment.center,
              child: Text(
                fxSlots[widget.deck.fxSlot].toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: Ty.label.copyWith(
                  fontSize: compact ? T.s8 : T.s10,
                  color: on
                      ? T.bg
                      : _nameHover
                      ? T.text
                      : T.dim,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: compact ? 2 : 4),
        SizedBox(
          width: compact ? 16 : 20,
          height: compact ? 18 : 24,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _selectHover = true),
            onExit: (_) => setState(() => _selectHover = false),
            child: GestureDetector(
              key: _anchor,
              behavior: HitTestBehavior.opaque,
              onTap: () => showChoiceMenu(
                context: context,
                anchorKey: _anchor,
                labels: fxSlots,
                current: widget.deck.fxSlot,
                onSelect: (index) => widget.model.setFxSlot(widget.deck, index),
              ),
              child: Container(
                decoration: keyFace(hover: _selectHover),
                child: Center(
                  child: Glyph(
                    GlyphKind.dropdown,
                    size: compact ? 7 : 8,
                    color: _selectHover ? T.text : T.faint,
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

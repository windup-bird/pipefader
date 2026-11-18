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

/// The pads slot. The desk picks the pad mode through the slot's unit tabs, so
/// the mode row only appears where there is no unit header (all-in-one).
class PadsPanel extends StatelessWidget {
  const PadsPanel({
    required this.model,
    required this.deck,
    this.showModeTabs = false,
    this.scale,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final bool showModeTabs;
  final ControlScale? scale;

  @override
  Widget build(BuildContext context) {
    final s = scale ?? ControlScale.fallback;
    return Column(
      children: [
        if (showModeTabs) ...[
          SizedBox(
            height: s.size(18),
            child: Center(
              child: ModeTabs(
                labels: PadMode.values.map((mode) => mode.label).toList(),
                selected: PadMode.values.indexOf(deck.padMode),
                scale: s,
                onSelect: (index) =>
                    model.setPadMode(deck, PadMode.values[index]),
              ),
            ),
          ),
          SizedBox(height: s.size(4)),
        ],
        Expanded(
          child: PadGrid(model: model, deck: deck, scale: s),
        ),
      ],
    );
  }
}

/// Tempo: sync state, the BPM with its two step keys, the fader range and the
/// bend pair. Four rows, centred, nothing else.
class TempoPanel extends StatelessWidget {
  const TempoPanel({
    required this.model,
    required this.deck,
    this.scale,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final ControlScale? scale;

  @override
  Widget build(BuildContext context) {
    final s = scale ?? ControlScale.fallback;
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
          style: Ty.label.copyWith(
            fontSize: s.font(T.s10),
            color: synced ? T.accent : T.faint,
          ),
        ),
        SizedBox(height: s.size(4)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PanelButton(
              label: '-',
              width: 24,
              height: 24,
              scale: s,
              onTap: () => model.adjustTempo(deck, -0.001),
            ),
            SizedBox(width: s.size(8)),
            SizedBox(
              width: s.size(66),
              child: Text(
                bpmText(deck.bpm),
                textAlign: TextAlign.center,
                style: Ty.bpm.copyWith(fontSize: s.font(T.s22)),
              ),
            ),
            SizedBox(width: s.size(8)),
            PanelButton(
              label: '+',
              width: 24,
              height: 24,
              scale: s,
              onTap: () => model.adjustTempo(deck, 0.001),
            ),
          ],
        ),
        SizedBox(height: s.size(4)),
        Text(
          'range ±${(deck.view.tempoRange * 100).round()}% · ${tempoText(deck.tempo)}',
          style: Ty.labelSmall.copyWith(fontSize: s.font(T.s9)),
        ),
        SizedBox(height: s.size(6)),
        _BendRow(model: model, deck: deck, scale: s),
      ],
    );
  }
}

class _ValueLabel extends StatelessWidget {
  const _ValueLabel({
    required this.value,
    required this.label,
    required this.scale,
  });

  final String value;
  final String label;
  final ControlScale scale;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: Ty.num.copyWith(
              fontSize: scale.font(T.s16),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: TextStyle(fontSize: scale.font(T.s9), color: T.faint),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
  }
}

class _BendRow extends StatelessWidget {
  const _BendRow({
    required this.model,
    required this.deck,
    required this.scale,
  });

  final AppModel model;
  final DeckRuntime deck;
  final ControlScale scale;

  @override
  Widget build(BuildContext context) {
    final bending = deck.nudge != 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: scale.size(24),
          height: scale.size(24),
          child: HoldKey(
            label: '<',
            scale: scale,
            onDown: () => model.bend(deck, -1),
            onUp: () => model.releaseBend(deck),
          ),
        ),
        SizedBox(width: scale.size(8)),
        Text(
          bending ? 'BEND ${tempoText(1 + deck.nudge)}' : 'BEND',
          style: Ty.label.copyWith(
            fontSize: scale.font(T.s10),
            color: bending ? T.accent : T.faint,
          ),
        ),
        SizedBox(width: scale.size(8)),
        SizedBox(
          width: scale.size(24),
          height: scale.size(24),
          child: HoldKey(
            label: '>',
            scale: scale,
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
  const MixerPanel({
    required this.model,
    required this.deck,
    this.scale,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final ControlScale? scale;

  @override
  Widget build(BuildContext context) {
    final s = scale ?? ControlScale.fallback;
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
              scale: s,
              onChanged: (value) => model.setEq(deck, index, value),
            ),
          ),
          SizedBox(height: s.size(6)),
          Text(
            labels[index],
            style: Ty.labelSmall.copyWith(fontSize: s.font(T.s9)),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(s.size(6), s.size(6), s.size(6), s.size(2)),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) SizedBox(width: s.size(8)),
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
  const FxPanel({
    required this.model,
    required this.deck,
    this.scale,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final ControlScale? scale;

  @override
  Widget build(BuildContext context) {
    final s = scale ?? ControlScale.fallback;
    return Padding(
      padding: EdgeInsets.fromLTRB(s.size(6), s.size(2), s.size(6), 0),
      child: Column(
        children: [
          SizedBox(
            height: s.size(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PanelButton(
                  label: '-',
                  width: 20,
                  height: 20,
                  scale: s,
                  onTap: () => model.stepBeats(deck, true),
                ),
                SizedBox(width: s.size(6)),
                Expanded(
                  child: Center(
                    child: _ValueLabel(
                      value: fxBeats[deck.beatsIndex],
                      label: 'beats',
                      scale: s,
                    ),
                  ),
                ),
                SizedBox(width: s.size(6)),
                PanelButton(
                  label: '+',
                  width: 20,
                  height: 20,
                  scale: s,
                  onTap: () => model.stepBeats(deck, false),
                ),
              ],
            ),
          ),
          SizedBox(height: s.size(4)),
          Expanded(
            child: ParamBar(
              label: 'FB',
              value: deck.fx1,
              scale: s,
              onChanged: (value) => model.setFxParam(deck, 0, value),
            ),
          ),
          SizedBox(height: s.size(3)),
          Expanded(
            child: ParamBar(
              label: 'MIX',
              value: deck.fx2,
              scale: s,
              onChanged: (value) => model.setFxParam(deck, 1, value),
            ),
          ),
          SizedBox(height: s.size(4)),
          SizedBox(
            height: s.size(24),
            child: Center(
              child: _FxName(model: model, deck: deck, scale: s),
            ),
          ),
        ],
      ),
    );
  }
}

/// The phone's combined strip: four tone/filter faders and the FX param1
/// fader, all vertical and on the same baseline.
class MixerMaxPanel extends StatelessWidget {
  const MixerMaxPanel({
    required this.model,
    required this.deck,
    this.scale,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final ControlScale? scale;

  @override
  Widget build(BuildContext context) {
    final s = scale ?? ControlScale.fallback;
    final values = [deck.high, deck.mid, deck.low, deck.filter];
    const labels = ['HI', 'MID', 'LO', 'FIL'];

    Widget eqFader(int index) => Expanded(
      child: _MixerMaxFader(
        value: values[index],
        bipolar: true,
        scale: s,
        onChanged: (value) => model.setEq(deck, index, value),
        label: Text(
          labels[index],
          style: Ty.labelSmall.copyWith(fontSize: s.font(T.s8)),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(s.size(6), s.size(4), s.size(6), s.size(2)),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) SizedBox(width: s.size(6)),
            eqFader(i),
          ],
          SizedBox(width: s.size(8)),
          Expanded(
            child: _MixerMaxFader(
              value: deck.fx1,
              scale: s,
              onChanged: (value) => model.setFxParam(deck, 0, value),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: _FxName(
                  model: model,
                  deck: deck,
                  compact: true,
                  scale: s,
                ),
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
    required this.scale,
    this.bipolar = false,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final Widget label;
  final bool bipolar;
  final ControlScale scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BarFader(
            value: value,
            bipolar: bipolar,
            handleHeight: 4,
            scale: scale,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          height: scale.size(18),
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
    this.scale,
    super.key,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ControlScale? scale;

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

  void _setFromDrag(double x, double width, double handleW) {
    final travel = width - handleW;
    if (travel <= 0) return;
    final dx = x - _lastX;
    _lastX = x;
    setState(() => _value = (_value + dx / travel).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale ?? ControlScale.fallback;
    final handleW = scale.size(_handleW);
    return Row(
      children: [
        SizedBox(
          width: scale.size(22),
          child: Text(
            widget.label,
            style: Ty.labelSmall.copyWith(fontSize: scale.font(T.s9)),
          ),
        ),
        SizedBox(width: scale.size(5)),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final handleX = handleW / 2 + _value * (width - handleW);
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
                    _setFromDrag(event.localPosition.dx, width, handleW);
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
                    tween: Tween<double>(
                      end: _active ? height - scale.size(2) : scale.size(3),
                    ),
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
                            left: handleX - handleW / 2,
                            top: 0,
                            width: handleW,
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
    required this.scale,
    this.compact = false,
  });

  final AppModel model;
  final DeckRuntime deck;
  final bool compact;
  final ControlScale scale;

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
    final s = widget.scale;
    final rowH = s.size(compact ? 18 : 24);
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
              height: rowH,
              padding: EdgeInsets.symmetric(
                horizontal: s.size(compact ? 5 : 8),
              ),
              decoration: keyFace(active: on, hover: _nameHover),
              alignment: Alignment.center,
              child: Text(
                fxSlots[widget.deck.fxSlot].toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: Ty.label.copyWith(
                  fontSize: s.font(compact ? T.s8 : T.s10),
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
        SizedBox(width: s.size(compact ? 2 : 4)),
        SizedBox(
          width: s.size(compact ? 16 : 20),
          height: rowH,
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
                    size: s.size(compact ? 7 : 8),
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

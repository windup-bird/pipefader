import 'package:material_ui/material_ui.dart';

import '../model/deck.dart';
import '../state/app_model.dart';
import '../theme.dart';
import '../units/panels.dart';
import '../widgets/bar_fader.dart';
import '../widgets/buttons.dart';
import '../widgets/fader.dart';
import '../widgets/meter.dart';
import '../widgets/pad_grid.dart';
import '../widgets/unit_menu.dart';

/// The three units that share the top row of the band: the pad modes, the
/// transport's sync key and the inner unit's name. Everything below them lines
/// up row for row: cue with the first pad row, play with the second.
const double topRow = 20;
const double topGap = 6;

/// The units the inner slot can become. The outer slot is always pads.
const List<UnitKind> innerUnits = <UnitKind>[
  UnitKind.tempo,
  UnitKind.beatctl,
  UnitKind.mixer,
  UnitKind.fx,
];

/// The band under the waveforms: transport | pads | unit | fader, and the same
/// inverted on the right. The centre holds the two channel faders, their meters
/// and the crossfader.
class ControlBand extends StatelessWidget {
  const ControlBand({
    required this.model,
    required this.height,
    super.key,
  });

  final AppModel model;
  final double height;

  @override
  Widget build(BuildContext context) {
    final first = model.decks[0];
    final second = model.decks[1];
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Transport(model: model, deck: first),
          const SizedBox(width: 8),
          Expanded(child: _PadSlot(model: model, deck: first)),
          const SizedBox(width: 8),
          Expanded(child: _UnitSlot(model: model, deck: first)),
          const SizedBox(width: 10),
          _Centre(model: model),
          const SizedBox(width: 10),
          Expanded(child: _UnitSlot(model: model, deck: second)),
          const SizedBox(width: 8),
          Expanded(child: _PadSlot(model: model, deck: second)),
          const SizedBox(width: 8),
          _Transport(model: model, deck: second),
        ],
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.model, required this.deck});

  final AppModel model;
  final DeckRuntime deck;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: topRow,
            child: PanelButton(
              label: 'sync',
              active: deck.sync,
              style: Ty.button.copyWith(fontSize: 9),
              onTap: () => model.toggleSync(deck),
            ),
          ),
          const SizedBox(height: topGap),
          Expanded(
            child: PanelButton(
              label: 'cue',
              style: Ty.button.copyWith(fontSize: 12),
              onTap: () => model.cue(deck),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PanelButton(
              label: deck.playing ? 'pause' : 'play',
              active: deck.playing,
              style: Ty.button.copyWith(fontSize: 12),
              onTap: () => model.togglePlay(deck),
            ),
          ),
        ],
      ),
    );
  }
}

/// The fixed pads slot: the pad modes on the top row, then the 2x4 grid. There
/// is no name — this slot cannot become anything else.
class _PadSlot extends StatelessWidget {
  const _PadSlot({required this.model, required this.deck});

  final AppModel model;
  final DeckRuntime deck;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: topRow,
          child: Center(
            child: ModeTabs(
              labels: PadMode.values.map((mode) => mode.label).toList(),
              selected: PadMode.values.indexOf(deck.padMode),
              onSelect: (index) =>
                  model.setPadMode(deck, PadMode.values[index]),
            ),
          ),
        ),
        const SizedBox(height: topGap),
        Expanded(child: PadGrid(model: model, deck: deck)),
      ],
    );
  }
}

/// The switchable inner slot. Its name sits on the top row, in the same style
/// as the pad modes, and opens the picker.
class _UnitSlot extends StatefulWidget {
  const _UnitSlot({required this.model, required this.deck});

  final AppModel model;
  final DeckRuntime deck;

  @override
  State<_UnitSlot> createState() => _UnitSlotState();
}

class _UnitSlotState extends State<_UnitSlot> {
  final _anchor = GlobalKey();
  bool _hover = false;

  UnitKind get _kind => widget.deck.unitInner;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: topRow,
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
                  labels: innerUnits.map((kind) => kind.label).toList(),
                  current: innerUnits.indexOf(_kind),
                  onSelect: (index) =>
                      widget.model.setUnit(widget.deck, innerUnits[index]),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  child: Text(
                    _kind.label.toUpperCase(),
                    style: Ty.labelSmall.copyWith(
                      color: _hover ? T.text : T.dim,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: topGap),
        Expanded(child: _panel(_kind)),
      ],
    );
  }

  Widget _panel(UnitKind kind) {
    switch (kind) {
      case UnitKind.pads:
        return PadGrid(model: widget.model, deck: widget.deck);
      case UnitKind.tempo:
        return TempoPanel(model: widget.model, deck: widget.deck);
      case UnitKind.beatctl:
        return BeatctlPanel(model: widget.model, deck: widget.deck);
      case UnitKind.mixer:
        return MixerPanel(model: widget.model, deck: widget.deck);
      case UnitKind.fx:
        return FxPanel(model: widget.model, deck: widget.deck);
    }
  }
}

class _Centre extends StatelessWidget {
  const _Centre({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          const SizedBox(height: topRow + topGap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: BarFader(
                    value: model.decks[0].fader,
                    onChanged: (value) => model.setFader(model.decks[0], value),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 8,
                  child: ValueListenableBuilder<int>(
                    valueListenable: model.clock,
                    builder: (context, _, _) => LevelMeter(
                      level: model.decks[0].meter,
                      peak: model.decks[0].meterPeak,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BarFader(
                    value: model.decks[1].fader,
                    onChanged: (value) => model.setFader(model.decks[1], value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Crossfader(
            value: model.crossfader,
            onChanged: model.setCrossfader,
          ),
        ],
      ),
    );
  }
}

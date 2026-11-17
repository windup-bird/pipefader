import 'package:material_ui/material_ui.dart';

import '../model/deck.dart';
import '../state/app_model.dart';
import 'panels.dart';

/// One place that maps a unit kind to its panel, shared by the desk and the
/// phone so a new panel only has to be wired once.
Widget buildUnit({
  required UnitKind kind,
  required AppModel model,
  required DeckRuntime deck,
}) {
  return switch (kind) {
    UnitKind.pads => PadsPanel(model: model, deck: deck),
    UnitKind.tempo => TempoPanel(model: model, deck: deck),
    UnitKind.mixer => MixerPanel(model: model, deck: deck),
    UnitKind.fx => FxPanel(model: model, deck: deck),
    UnitKind.mixerMax => MixerMaxPanel(model: model, deck: deck),
  };
}

import 'package:material_ui/material_ui.dart';

import '../model/deck.dart';
import '../state/app_model.dart';
import '../theme.dart';
import 'panels.dart';

/// One place that maps a unit kind to its panel, shared by the desk and the
/// phone so a new panel only has to be wired once.
Widget buildUnit({
  required UnitKind kind,
  required AppModel model,
  required DeckRuntime deck,
  ControlScale? scale,
}) {
  return switch (kind) {
    UnitKind.padsCue ||
    UnitKind.padsLoop ||
    UnitKind.padsJump => PadsPanel(model: model, deck: deck, scale: scale),
    UnitKind.tempo => TempoPanel(model: model, deck: deck, scale: scale),
    UnitKind.mixer => MixerPanel(model: model, deck: deck, scale: scale),
    UnitKind.fx => FxPanel(model: model, deck: deck, scale: scale),
    UnitKind.mixerMax => MixerMaxPanel(model: model, deck: deck, scale: scale),
  };
}

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/model/deck.dart';
import 'package:pipefader_gui/state/app_model.dart';

import 'panels/fx.dart';
import 'panels/mixer.dart';
import 'panels/mixer_max.dart';
import 'panels/pads.dart';
import 'panels/tempo.dart';

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

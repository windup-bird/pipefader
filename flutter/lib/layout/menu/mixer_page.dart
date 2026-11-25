import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/i18n.dart';
import 'package:pipefader_gui/layout/menu/menu_widgets.dart';
import 'package:pipefader_gui/layout/menu/settings_widgets.dart';
import 'package:pipefader_gui/state/menu_state.dart';

/// Root › Mixer: the `[mixer]` half of the profile. Every write goes through `MenuState.setSetting`,
/// which the bridge applies to the live engine; there is no Apply key.
class MenuMixerPage extends StatelessWidget {
  const MenuMixerPage({required this.menu, required this.onBack, super.key});

  final MenuState menu;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    return MenuPageFrame(
      header: MenuPageHeader(title: l10n.mixer, onBack: onBack),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsPageBody(
            page: menu.settingsPage('mixer'),
            onSet: menu.builtin
                ? null
                : (key, value) => unawaited(menu.setSetting(key, value)),
          ),
          MenuStatusLine(
            error: menu.error,
            note: menu.builtin
                ? l10n.builtinReadOnly
                : menu.restartRequired
                ? l10n.restartRequired
                : null,
          ),
        ],
      ),
    );
  }
}

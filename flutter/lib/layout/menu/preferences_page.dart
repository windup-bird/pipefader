import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/core/i18n.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/menu/library_settings.dart';
import 'package:pipefader_gui/layout/menu/menu_widgets.dart';
import 'package:pipefader_gui/layout/menu/settings_widgets.dart';
import 'package:pipefader_gui/state/menu_state.dart';

/// Root › Preferences: the `[live]`, `[preference]` and library sides of the profile. A four-way
/// section switch keeps the page short; `Logs` is the only diagnostic left, so it sits at the
/// bottom of this page instead of taking a root key.
class MenuPreferencesPage extends StatefulWidget {
  const MenuPreferencesPage({
    required this.menu,
    required this.onBack,
    required this.onOpenLogs,
    super.key,
  });

  final MenuState menu;
  final VoidCallback onBack;
  final VoidCallback onOpenLogs;

  @override
  State<MenuPreferencesPage> createState() => _MenuPreferencesPageState();
}

class _MenuPreferencesPageState extends State<MenuPreferencesPage> {
  String _section = 'audio';

  static const _sections = ['audio', 'library', 'analysis', 'display'];

  MenuState get menu => widget.menu;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(menu.reloadProfile());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    return MenuPageFrame(
      header: MenuPageHeader(title: l10n.preferences, onBack: widget.onBack),
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var index = 0; index < _sections.length; index++) ...[
              if (index > 0) const SizedBox(width: T.gap),
              Expanded(
                child: PanelButton(
                  key: ValueKey('preferences-${_sections[index]}'),
                  label: _sectionLabel(l10n, _sections[index]),
                  rawLabel: true,
                  height: 40,
                  active: _section == _sections[index],
                  onTap: () => setState(() => _section = _sections[index]),
                  style: Ty.button.copyWith(fontSize: T.s10),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        if (_section == 'library')
          MenuLibrarySettings(menu: menu)
        else
          SettingsPageBody(
            page: menu.settingsPage(_section),
            onSet: menu.builtin
                ? null
                : (key, value) => unawaited(menu.setSetting(key, value)),
          ),
        const SizedBox(height: 18),
        PanelButton(
          key: const ValueKey('preferences-logs'),
          label: l10n.logs,
          rawLabel: true,
          glyph: GlyphKind.logs,
          height: 44,
          onTap: widget.onOpenLogs,
          style: Ty.menuRow.copyWith(fontSize: T.s12),
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

  String _sectionLabel(L10n l10n, String id) => switch (id) {
    'audio' => l10n.audio,
    'library' => l10n.library,
    'analysis' => l10n.analysis,
    'display' => l10n.display,
    _ => id,
  };
}

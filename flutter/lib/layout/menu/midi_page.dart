import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/menu/menu_widgets.dart';
import 'package:pipefader_gui/state/menu_state.dart';

/// `MIDI / MAP`: the current input, every port the host reports, and the map file in use. The
/// refresh key is the same widget as Output's, so the two pages read as one control panel.
class MenuMidiPage extends StatelessWidget {
  const MenuMidiPage({required this.menu, required this.onBack, super.key});

  final MenuState menu;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final current = menu.midiPort.isEmpty
        ? 'No controller connected'
        : menu.midiPort;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuPageHeader(
          title: 'Midi / Map',
          onBack: onBack,
          trailing: MenuRefreshButton(
            key: const ValueKey('midi-refresh'),
            menu: menu,
            onTap: () => unawaited(menu.refresh()),
          ),
        ),
        const SizedBox(height: 14),
        const MenuSectionLabel('Input'),
        MenuSelectRow(label: current, selected: true),
        if (menu.ports.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Text(
              'No MIDI input ports found',
              style: Ty.meta.copyWith(color: T.faint),
            ),
          )
        else
          for (final port in menu.ports)
            MenuSelectRow(
              key: ValueKey('midi-port-${port.index}'),
              label: port.name,
              selected: port.name == menu.midiPort,
              onTap: menu.builtin
                  ? null
                  : () => unawaited(menu.selectMidiPort(port)),
            ),
        const SizedBox(height: 12),
        const MenuSectionLabel('Map'),
        if (menu.maps.isEmpty)
          MenuSelectRow(label: menu.midiMap, selected: true, note: 'In use')
        else
          for (final map in menu.maps)
            MenuSelectRow(
              key: ValueKey('midi-map-${map.path}'),
              label: map.name,
              note: map.builtin ? 'Built-in' : null,
              selected: map.path == menu.midiMap,
              onTap: menu.builtin
                  ? null
                  : () => unawaited(menu.selectMidiMap(map)),
            ),
        MenuStatusLine(
          error: menu.error,
          note: menu.builtin
              ? '${menu.profile} · built-in profile is read-only'
              : '${menu.ports.length} MIDI port(s)',
        ),
      ],
    );
  }
}

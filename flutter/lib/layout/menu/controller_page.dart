import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/core/i18n.dart';
import 'package:pipefader_gui/core/platform/file_dialog.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/layout/menu/menu_widgets.dart';
import 'package:pipefader_gui/model/menu.dart';
import 'package:pipefader_gui/state/menu_state.dart';

/// `Controller › ports › one controller`. The list is the host's scan; the detail page is the
/// selected device, its Disable key and the map it should use. Choosing a user map goes through
/// the host's file dialog, so the same flow exists on Android and the desktop.
class MenuControllerPage extends StatefulWidget {
  const MenuControllerPage({required this.menu, required this.onBack, super.key});

  final MenuState menu;
  final VoidCallback onBack;

  @override
  State<MenuControllerPage> createState() => _MenuControllerPageState();
}

class _MenuControllerPageState extends State<MenuControllerPage> {
  String? _openPort;

  MenuState get menu => widget.menu;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final port = _openPort;
    if (port != null) return _detail(context, l10n, port);
    return _list(context, l10n);
  }

  Widget _list(BuildContext context, L10n l10n) {
    final ports = <MidiPortInfo>[
      if (menu.midiPort.isNotEmpty &&
          !menu.ports.any((port) => port.name == menu.midiPort))
        MidiPortInfo(index: -1, name: menu.midiPort),
      ...menu.ports,
    ];
    return MenuPageFrame(
      header: MenuPageHeader(
        title: l10n.controller,
        onBack: widget.onBack,
        trailing: MenuRefreshButton(
          key: const ValueKey('controller-refresh'),
          menu: menu,
          onTap: () => unawaited(menu.refresh()),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ports.isEmpty)
            _EmptyLine(text: l10n.noPorts)
          else
            for (final port in ports) ...[
              MenuListRow(
                key: ValueKey('controller-port-${port.index}:${port.name}'),
                label: port.name,
                note: port.name == menu.midiPort ? l10n.inUse : null,
                selected: port.name == menu.midiPort,
                onTap: menu.builtin && port.name != menu.midiPort
                    ? null
                    : () => unawaited(_enter(port)),
              ),
              const SizedBox(height: T.gapS),
            ],
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, L10n l10n, String port) {
    final maps = menu.maps;
    return MenuPageFrame(
      header: MenuPageHeader(
        title: port,
        onBack: () => setState(() => _openPort = null),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelButton(
            key: const ValueKey('controller-disable'),
            label: l10n.disable,
            rawLabel: true,
            height: 46,
            onTap: menu.builtin ? null : () => unawaited(_disable()),
            style: Ty.menuRow.copyWith(fontSize: T.s12),
          ),
          const SizedBox(height: 14),
          MenuSectionLabel(l10n.map),
          PanelButton(
            key: const ValueKey('controller-choose-map'),
            label: l10n.chooseUserMap,
            rawLabel: true,
            glyph: GlyphKind.folder,
            height: 46,
            onTap: menu.builtin ? null : () => unawaited(_pickMap()),
            style: Ty.menuRow.copyWith(fontSize: T.s12),
          ),
          const SizedBox(height: T.gap),
          if (maps.isEmpty)
            _EmptyLine(text: l10n.noMap)
          else
            for (final map in maps) ...[
              MenuListRow(
                key: ValueKey('controller-map-${map.path}'),
                label: map.name,
                note: map.builtin ? l10n.builtIn : null,
                selected: map.path == menu.midiMap,
                onTap: menu.builtin
                    ? null
                    : () => unawaited(menu.selectMidiMap(map)),
              ),
              const SizedBox(height: T.gapS),
            ],
        ],
      ),
    );
  }

  Future<void> _enter(MidiPortInfo port) async {
    setState(() => _openPort = port.name);
    if (port.name != menu.midiPort && !menu.builtin) {
      await menu.selectMidiPort(port);
    }
  }

  Future<void> _disable() async {
    await menu.disableController();
    if (!mounted) return;
    setState(() => _openPort = null);
  }

  Future<void> _pickMap() async {
    final picked = await pickMapFile();
    if (!mounted) return;
    if (picked == null) {
      // A cancelled dialog is indistinguishable from a platform without one; keep it quiet.
      return;
    }
    await menu.importMidiMap(picked.name, picked.bytes);
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
    child: Text(text, style: Ty.bodySmall.copyWith(color: T.faint)),
  );
}

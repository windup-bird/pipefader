import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/device.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/core/i18n.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/menu/menu_widgets.dart';
import 'package:pipefader_gui/model/menu.dart';
import 'package:pipefader_gui/state/menu_state.dart';

/// `Output › Master|Precue › destinations`, with a second flow for adding: device, then channel
/// pair, then confirm. Every step is a full-width key so the panel reads the same as the root.
class MenuOutputPage extends StatefulWidget {
  const MenuOutputPage({required this.menu, required this.onBack, super.key});

  final MenuState menu;
  final VoidCallback onBack;

  @override
  State<MenuOutputPage> createState() => _MenuOutputPageState();
}

enum _AddStep { none, device, channels }

class _MenuOutputPageState extends State<MenuOutputPage> {
  _AddStep _step = _AddStep.none;

  MenuState get menu => widget.menu;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    return switch (_step) {
      _AddStep.none => _list(context, l10n),
      _AddStep.device => _devices(context, l10n),
      _AddStep.channels => _channels(context, l10n),
    };
  }

  Widget _list(BuildContext context, L10n l10n) {
    final role = menu.role;
    final channels = menu.outputsFor(role);
    final canRemove = !menu.builtin;
    return MenuPageFrame(
      header: MenuPageHeader(
        title: l10n.output,
        onBack: widget.onBack,
        trailing: MenuRefreshButton(
          key: const ValueKey('output-refresh'),
          menu: menu,
          onTap: () => unawaited(menu.refresh()),
        ),
      ),
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final item in OutputRole.values) ...[
              if (item != OutputRole.values.first) const SizedBox(width: T.gap),
              Expanded(
                child: PanelButton(
                  key: ValueKey('output-role-${item.name}'),
                  label: l10n.role(item.configName),
                  rawLabel: true,
                  height: 42,
                  active: item == role,
                  onTap: () => menu.selectRole(item),
                  style: Ty.menuRow.copyWith(fontSize: T.s12),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        if (channels.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              l10n.noChannels(l10n.role(role.configName)),
              style: Ty.bodySmall.copyWith(color: T.faint),
            ),
          )
        else
          for (final channel in channels) ...[
            _ChannelRow(
              key: ValueKey('output-${channel.role.name}-${channel.index}'),
              channel: channel,
              canRemove: canRemove,
              onRemove: () => unawaited(menu.removeOutput(channel)),
            ),
            const SizedBox(height: T.gapS),
          ],
        const SizedBox(height: 10),
        PanelButton(
          key: const ValueKey('output-add'),
          label: l10n.addOutput,
          rawLabel: true,
          glyph: GlyphKind.plus,
          height: 46,
          onTap: menu.builtin
              ? null
              : () => setState(() => _step = _AddStep.device),
          style: Ty.menuRow.copyWith(fontSize: T.s12),
        ),
      ],
      ),
    );
  }

  Widget _devices(BuildContext context, L10n l10n) {
    return MenuPageFrame(
      header: MenuPageHeader(
        title: l10n.addOutput,
        onBack: () => setState(() => _step = _AddStep.none),
        trailing: MenuRefreshButton(
          key: const ValueKey('output-device-refresh'),
          menu: menu,
          onTap: () => unawaited(menu.refresh()),
        ),
      ),
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuSectionLabel(l10n.device),
        MenuListRow(
          key: const ValueKey('output-device-0'),
          label: l10n.defaultDevice,
          selected: menu.deviceChoice == 0,
          onTap: () {
            menu.selectDevice(0);
            setState(() => _step = _AddStep.channels);
          },
        ),
        const SizedBox(height: T.gapS),
        for (var index = 0; index < menu.devices.length; index++) ...[
          MenuListRow(
            key: ValueKey('output-device-${index + 1}'),
            label: menu.devices[index].description.isEmpty
                ? menu.devices[index].name
                : menu.devices[index].description,
            note: menu.devices[index].name,
            selected: menu.deviceChoice == index + 1,
            onTap: () {
              menu.selectDevice(index + 1);
              setState(() => _step = _AddStep.channels);
            },
          ),
          const SizedBox(height: T.gapS),
        ],
      ],
      ),
    );
  }

  Widget _channels(BuildContext context, L10n l10n) {
    final pairs = menu.channelPairs;
    return MenuPageFrame(
      header: MenuPageHeader(
        title: l10n.channels,
        onBack: () => setState(() => _step = _AddStep.device),
      ),
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuSectionLabel(l10n.channels),
        for (var index = 0; index < pairs.length; index++) ...[
          MenuListRow(
            key: ValueKey('output-channels-$index'),
            label: '${pairs[index].$1},${pairs[index].$2}',
            selected: menu.addChannels == pairs[index],
            onTap: () => menu.selectChannels(pairs[index]),
          ),
          const SizedBox(height: T.gapS),
        ],
        const SizedBox(height: 6),
        PanelButton(
          key: const ValueKey('output-confirm'),
          label: l10n.addOutput,
          rawLabel: true,
          glyph: GlyphKind.plus,
          height: 46,
          onTap: () => unawaited(_add()),
          style: Ty.menuRow.copyWith(fontSize: T.s12),
        ),
      ],
      ),
    );
  }

  Future<void> _add() async {
    await menu.addOutput(menu.role);
    if (!mounted) return;
    if (menu.error == null) setState(() => _step = _AddStep.none);
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channel,
    required this.canRemove,
    required this.onRemove,
    super.key,
  });

  final OutputChannel channel;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: keyFace(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.menuRow.copyWith(fontSize: T.s12),
                ),
                const SizedBox(height: 3),
                Text(
                  '${channel.channelLabel} · ${channel.deviceLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.meta.copyWith(color: T.faint),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: T.gapS),
        GlyphButton(
          key: ValueKey('output-remove-${channel.index}'),
          glyph: GlyphKind.trash,
          size: 46,
          iconSize: 18,
          onTap: canRemove ? onRemove : null,
        ),
      ],
    );
  }
}

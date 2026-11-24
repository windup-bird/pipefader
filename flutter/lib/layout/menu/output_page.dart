import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/menu/menu_widgets.dart';
import 'package:pipefader_gui/model/menu.dart';
import 'package:pipefader_gui/state/menu_state.dart';

/// `Output › Master|Precue › channels`. The left column is the category, the right one is the
/// destination list; adding and removing stay in the second column so the shape never changes.
class MenuOutputPage extends StatelessWidget {
  const MenuOutputPage({required this.menu, required this.onBack, super.key});

  final MenuState menu;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final role = menu.role;
    final channels = menu.outputsFor(role);
    final canRemove = !menu.builtin;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuPageHeader(
          title: 'Output',
          onBack: onBack,
          trailing: MenuRefreshButton(
            key: const ValueKey('output-refresh'),
            menu: menu,
            onTap: () => unawaited(menu.refresh()),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: MenuChoice(
                axis: Axis.vertical,
                height: 32,
                options: [for (final role in OutputRole.values) role.label],
                selected: role.index,
                onSelect: (index) => menu.selectRole(OutputRole.values[index]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 160),
                alignment: Alignment.topCenter,
                curve: Curves.easeOutCubic,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: Column(
                    key: ValueKey(role),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MenuSectionLabel('${role.label} channels'),
                      if (channels.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'No ${role.label.toLowerCase()} channels',
                            style: Ty.meta.copyWith(color: T.faint),
                          ),
                        ),
                      for (final channel in channels)
                        _ChannelRow(
                          key: ValueKey(
                            'output-${channel.role.name}-${channel.index}',
                          ),
                          channel: channel,
                          canRemove: canRemove,
                          onRemove: () => unawaited(menu.removeOutput(channel)),
                        ),
                      const SizedBox(height: 12),
                      const MenuSectionLabel('Device'),
                      MenuChoice(
                        axis: Axis.vertical,
                        height: 28,
                        options: [
                          'Default device',
                          for (final device in menu.devices)
                            device.description.isEmpty
                                ? device.name
                                : device.description,
                        ],
                        selected: menu.deviceChoice,
                        onSelect: menu.selectDevice,
                      ),
                      const SizedBox(height: 10),
                      const MenuSectionLabel('Channels'),
                      MenuChoice(
                        options: [
                          for (final pair in menu.channelPairs)
                            '${pair.$1},${pair.$2}',
                        ],
                        selected: menu.channelPairs.indexOf(menu.addChannels),
                        onSelect: (index) =>
                            menu.selectChannels(menu.channelPairs[index]),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: PanelButton(
                          key: ValueKey('output-add-${role.name}'),
                          label: 'Add ${role.label.toLowerCase()} channel',
                          height: 30,
                          onTap: menu.builtin
                              ? null
                              : () => unawaited(menu.addOutput(role)),
                          style: Ty.button.copyWith(
                            fontSize: T.s9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        MenuStatusLine(
          error: menu.error,
          note: menu.builtin
              ? '${menu.profile} · built-in profile is read-only'
              : menu.restartRequired
              ? 'Restart app to apply output changes'
              : '${menu.outputs.length} destination(s)',
        ),
      ],
    );
  }
}

class _ChannelRow extends StatefulWidget {
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
  State<_ChannelRow> createState() => _ChannelRowState();
}

class _ChannelRowState extends State<_ChannelRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        height: 48,
        color: _hover ? T.surface : Colors.transparent,
        padding: const EdgeInsets.only(left: 8, right: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.menuRow.copyWith(fontSize: T.s10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.channel.channelLabel} · ${widget.channel.deviceLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.meta.copyWith(color: T.faint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            GlyphButton(
              key: ValueKey('output-remove-${widget.channel.index}'),
              glyph: GlyphKind.close,
              size: 20,
              onTap: widget.canRemove ? widget.onRemove : null,
            ),
          ],
        ),
      ),
    );
  }
}

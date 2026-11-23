import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/menu/menu_widgets.dart';
import 'package:pipefader_gui/state/menu_state.dart';

/// The editable rows: profile identity, audio rate, and the mixer's shape. The rate is the one row
/// that needs a restart; everything else is reloaded into the engine immediately.
class MenuSettingsPage extends StatelessWidget {
  const MenuSettingsPage({required this.menu, required this.onBack, super.key});

  final MenuState menu;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final settings = menu.settings;
    final enabled = !menu.builtin;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuPageHeader(title: 'Settings', onBack: onBack),
        const SizedBox(height: 14),
        const MenuSectionLabel('Profile'),
        MenuSelectRow(
          label: menu.profile,
          selected: true,
          note: menu.builtin ? 'Built-in' : 'User',
        ),
        const SizedBox(height: 12),
        const MenuSectionLabel('Audio'),
        _SettingChoice(
          keyPrefix: 'setting-sample_rate',
          label: 'Sample Rate',
          note: 'kHz · restart required',
          options: const ['44.1', '48', '96'],
          values: const ['44100', '48000', '96000'],
          selected: _indexOf(const [
            '44100',
            '48000',
            '96000',
          ], '${settings.sampleRate}'),
          enabled: enabled,
          onSelect: (value) => unawaited(menu.setSetting('sample_rate', value)),
        ),
        const SizedBox(height: 12),
        const MenuSectionLabel('Mixer'),
        _SettingChoice(
          keyPrefix: 'setting-crossfader_curve',
          label: 'Crossfader',
          options: const ['Classic', 'Constant Power', 'Cut'],
          values: const ['classic', 'constant_power', 'cut'],
          selected: _indexOf(const [
            'classic',
            'constant_power',
            'cut',
          ], settings.crossfaderCurve),
          enabled: enabled,
          onSelect: (value) =>
              unawaited(menu.setSetting('crossfader_curve', value)),
        ),
        const SizedBox(height: 10),
        _SettingChoice(
          keyPrefix: 'setting-cue_blend',
          label: 'Cue Blend',
          options: const ['Cue', 'Both', 'Master'],
          values: const ['cue', 'both', 'master'],
          selected: _indexOf(const [
            'cue',
            'both',
            'master',
          ], settings.cueBlendName),
          enabled: enabled,
          onSelect: (value) => unawaited(menu.setSetting('cue_blend', value)),
        ),
        const SizedBox(height: 10),
        _SettingChoice(
          keyPrefix: 'setting-autogain',
          label: 'Auto Gain',
          options: const ['Off', 'On'],
          values: const ['off', 'on'],
          selected: settings.autogain ? 1 : 0,
          enabled: enabled,
          onSelect: (value) => unawaited(menu.setSetting('autogain', value)),
        ),
        MenuStatusLine(
          error: menu.error,
          note: menu.builtin
              ? 'The built-in profile is read-only; changes are disabled'
              : 'Changes are written to the running profile',
        ),
      ],
    );
  }

  static int _indexOf(List<String> values, String value) =>
      values.indexOf(value);
}

class _SettingChoice extends StatelessWidget {
  const _SettingChoice({
    required this.keyPrefix,
    required this.label,
    required this.options,
    required this.values,
    required this.selected,
    required this.onSelect,
    this.note,
    this.enabled = true,
  });

  final String keyPrefix;
  final String label;
  final String? note;
  final List<String> options;
  final List<String> values;
  final int selected;
  final ValueChanged<String> onSelect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Ty.labelSmall.copyWith(color: T.dim),
                ),
              ),
              if (note != null)
                Text(note!, style: Ty.meta.copyWith(color: T.faint)),
            ],
          ),
        ),
        MenuChoice(
          options: options,
          keys: [for (final value in values) ValueKey('$keyPrefix-$value')],
          selected: selected,
          onSelect: (index) => onSelect(values[index]),
          enabled: enabled,
          height: 28,
          fontSize: T.s8,
        ),
      ],
    );
  }
}

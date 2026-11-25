import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/i18n.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/menu/menu_widgets.dart';
import 'package:pipefader_gui/model/menu.dart';

/// Renders one backend-described settings page. The backend owns the keys and values; this file
/// owns the localised labels and the key layout, so a profile field added in Rust still works
/// with its English fallback before the translation lands.
class SettingsPageBody extends StatelessWidget {
  const SettingsPageBody({
    required this.page,
    required this.onSet,
    super.key,
  });

  final SettingsPageData? page;
  final void Function(String key, String value)? onSet;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final page = this.page;
    if (page == null || page.sections.isEmpty) {
      return Text(l10n.noSettings, style: Ty.bodySmall.copyWith(color: T.faint));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var sectionIndex = 0; sectionIndex < page.sections.length; sectionIndex++) ...[
          if (sectionIndex > 0) const SizedBox(height: 16),
          MenuSectionLabel(_sectionLabel(l10n, page.sections[sectionIndex].title)),
          for (var rowIndex = 0;
              rowIndex < page.sections[sectionIndex].rows.length;
              rowIndex++) ...[
            if (rowIndex > 0) const SizedBox(height: 8),
            _SettingRow(
              row: page.sections[sectionIndex].rows[rowIndex],
              onSet: onSet,
            ),
          ],
        ],
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.row, required this.onSet});

  final SettingsRowData row;
  final void Function(String key, String value)? onSet;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final options = row.options;
    final selected = options.indexWhere((option) => option.value == row.value);
    final enabled = row.enabled && onSet != null;
    final label = _rowLabel(l10n, row.key, row.label);
    final note = row.needsRestart
        ? l10n.restartHint
        : (row.note.isEmpty ? null : row.note);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 440;
        final labelWidth = narrow ? 98.0 : 136.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: labelWidth,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ty.labelSmall.copyWith(
                        color: T.dim,
                        fontSize: T.s10,
                      ),
                    ),
                  ),
                  if (note != null)
                    Tooltip(
                      message: note,
                      child: Text(
                        '  *',
                        style: Ty.meta.copyWith(color: T.warn),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MenuChoice(
                options: [
                  for (final option in options)
                    _optionLabel(l10n, row.key, option.value, option.label),
                ],
                keys: [
                  for (final option in options)
                    ValueKey('setting-${row.key}-${option.value}'),
                ],
                selected: selected,
                onSelect: enabled
                    ? (index) => onSet?.call(row.key, options[index].value)
                    : (_) {},
                enabled: enabled,
                height: 34,
                fontSize: T.s9,
                gap: 6,
              ),
            ),
          ],
        );
      },
    );
  }
}

String _sectionLabel(L10n l, String title) => switch (title) {
  'Crossfader' => l.pick('Crossfader', '交叉推子'),
  'Fader' => l.pick('Fader', '推子'),
  'Auto Gain' => l.pick('Auto Gain', '自动增益'),
  'Limiter' => l.pick('Limiter', '限制器'),
  'EQ' => l.pick('EQ', 'EQ'),
  'Filter' => l.pick('Filter', '滤波器'),
  'Playback' => l.pick('Playback', '播放'),
  'Keylock' => l.pick('Keylock', '键锁'),
  'Stems' => l.pick('Stems', '分轨'),
  'Backends' => l.pick('Backends', '分析后端'),
  'Behaviour' => l.pick('Behaviour', '行为'),
  'Grid' => l.pick('Grid', '网格'),
  'Keys' => l.pick('Keys', '调性'),
  'Panel' => l.pick('Panel', '面板'),
  _ => title,
};

String _rowLabel(L10n l, String key, String fallback) => switch (key) {
  'crossfader_curve' => l.pick('Curve', '曲线'),
  'cue_blend' => l.cueBlend,
  'cue_cut_width' => l.pick('Cut Width', '切档宽度'),
  'fader_position' => l.pick('Cue Tap', '监听取样点'),
  'autogain' => l.autoGain,
  'autogain_target_db' => l.pick('Target', '目标'),
  'limiter' => l.pick('Limiter', '限制器'),
  'limiter_ceiling_db' => l.pick('Ceiling', '上限'),
  'eq_lower_hz' => l.pick('Low / Mid', '低 / 中'),
  'eq_higher_hz' => l.pick('Mid / High', '中 / 高'),
  'filter' => l.pick('Kind', '类型'),
  'sample_rate' => l.sampleRate,
  'keylock_block' => l.pick('Block', '块大小'),
  'stems_provider' => l.pick('Provider', '提供方'),
  'beats_backend' => l.pick('Beats', '节拍'),
  'key_backend' => l.pick('Key', '调性'),
  'auto_analyse' => l.pick('Auto Analyse', '自动分析'),
  'grid_offset_ms' => l.pick('Offset', '偏移'),
  'key_format' => l.pick('Notation', '记法'),
  'follow' => l.pick('Follow Commands', '跟随命令'),
  _ => fallback,
};

String _optionLabel(L10n l, String key, String value, String fallback) {
  return switch (value) {
    'off' => l.off,
    'on' => l.on,
    'pre' => l.pick('Pre', '前'),
    'post' => l.pick('Post', '后'),
    'classic' => key == 'key_format' ? l.pick('Classic', '传统') : l.classic,
    'constant_power' => l.constantPower,
    'cut' => l.cut,
    'cue' => l.cue,
    'both' => l.both,
    'master' => l.pick('Master', '主输出'),
    'linear' => l.pick('Linear', '线性'),
    'cpu' => 'CPU',
    'cuda' => 'CUDA',
    'stratum' => 'Stratum',
    'timestretch' => l.pick('Time-stretch', '时移'),
    'camelot' => 'Camelot',
    _ => fallback,
  };
}

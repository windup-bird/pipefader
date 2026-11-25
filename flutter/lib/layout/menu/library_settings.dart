import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/device.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/core/i18n.dart';
import 'package:pipefader_gui/core/platform/file_dialog.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/menu/menu_widgets.dart';
import 'package:pipefader_gui/model/menu.dart';
import 'package:pipefader_gui/state/menu_state.dart';

/// Preferences › Library: the plain folders added by the user, the sources the scan found, and the
/// two actions that change them. USB volumes are chosen through the same folder dialog; Android
/// converts the SAF tree to a path before this page sees it.
class MenuLibrarySettings extends StatelessWidget {
  const MenuLibrarySettings({required this.menu, super.key});

  final MenuState menu;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final enabled = !menu.builtin;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuSectionLabel(l10n.folders),
        if (menu.libraryFolders.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.noFolders,
              style: Ty.bodySmall.copyWith(color: T.faint),
            ),
          )
        else
          for (final folder in menu.libraryFolders) ...[
            _FolderRow(
              path: folder,
              onRemove: enabled
                  ? () => unawaited(menu.removeLibraryFolder(folder))
                  : null,
            ),
            const SizedBox(height: T.gapS),
          ],
        const SizedBox(height: 6),
        PanelButton(
          key: const ValueKey('library-add-folder'),
          label: l10n.addFolder,
          rawLabel: true,
          glyph: GlyphKind.folder,
          height: 44,
          onTap: enabled ? () => unawaited(_addFolder()) : null,
          style: Ty.menuRow.copyWith(fontSize: T.s12),
        ),
        const SizedBox(height: 16),
        MenuSectionLabel(l10n.sources),
        if (menu.librarySources.isEmpty)
          Text(l10n.noSources, style: Ty.bodySmall.copyWith(color: T.faint))
        else
          for (final source in menu.librarySources) ...[
            _SourceRow(source: source),
            const SizedBox(height: T.gapS),
          ],
        const SizedBox(height: 10),
        PanelButton(
          key: const ValueKey('library-rescan'),
          label: l10n.rescan,
          rawLabel: true,
          glyph: GlyphKind.refresh,
          height: 44,
          onTap: menu.rescanLibrary,
          style: Ty.menuRow.copyWith(fontSize: T.s12),
        ),
      ],
    );
  }

  Future<void> _addFolder() async {
    final path = await pickDirectory();
    if (path == null) return;
    await menu.addLibraryFolder(path);
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.path, required this.onRemove});

  final String path;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: keyFace(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Text(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Ty.menuRow.copyWith(fontSize: T.s11),
            ),
          ),
        ),
        const SizedBox(width: T.gapS),
        GlyphButton(
          key: ValueKey('library-remove-$path'),
          glyph: GlyphKind.trash,
          size: 30,
          onTap: onRemove,
        ),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final LibrarySourceInfo source;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: keyFace(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ty.menuRow.copyWith(fontSize: T.s11),
          ),
          const SizedBox(height: 3),
          Text(
            '${source.origin} · ${source.path}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ty.meta.copyWith(color: T.faint),
          ),
        ],
      ),
    );
  }
}

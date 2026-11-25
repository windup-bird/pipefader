import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/bridge/engine.dart';
import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/core/i18n.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/menu/menu_widgets.dart';

/// The last lines of `bridge.log`. On Android the file lives in the app's private directory, so
/// this page is how it is read without adb; the refresh key re-reads after a failed boot.
class MenuLogsPage extends StatefulWidget {
  const MenuLogsPage({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<MenuLogsPage> createState() => _MenuLogsPageState();
}

class _MenuLogsPageState extends State<MenuLogsPage> {
  late Future<List<String>> _lines = _load();

  Future<List<String>> _load() => EngineClient.recentLogs();

  void _refresh() => setState(() => _lines = _load());

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    return MenuPageFrame(
      header: MenuPageHeader(
        title: l10n.logs,
        onBack: widget.onBack,
        trailing: GlyphButton(
          key: const ValueKey('logs-refresh'),
          glyph: GlyphKind.refresh,
          size: 26,
          onTap: _refresh,
        ),
      ),
      child: FutureBuilder<List<String>>(
          future: _lines,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.readingLog,
                  style: Ty.bodySmall.copyWith(color: T.faint),
                ),
              );
            }
            if (snapshot.hasError) {
              return Text(
                l10n.couldNotReadLog(snapshot.error!),
                style: Ty.bodySmall.copyWith(color: T.error),
              );
            }
            final lines = snapshot.data ?? const <String>[];
            if (lines.isEmpty) {
              return Text(
                l10n.noLogYet,
                style: Ty.bodySmall.copyWith(color: T.faint),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      line,
                      style: Ty.labelSmall.copyWith(
                        fontSize: T.s9,
                        height: 1.35,
                        color: T.dim,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
    );
  }
}

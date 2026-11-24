import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/bridge/engine.dart';
import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/glyph.dart';
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

  Future<List<String>> _load() async {
    try {
      final lines = await EngineClient.recentLogs();
      return lines.isEmpty ? const ['No log yet.'] : lines;
    } catch (error) {
      return ['Could not read the log: $error'];
    }
  }

  void _refresh() => setState(() => _lines = _load());

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuPageHeader(
          title: 'Logs',
          onBack: widget.onBack,
          trailing: GlyphButton(
            key: const ValueKey('logs-refresh'),
            glyph: GlyphKind.refresh,
            size: 22,
            onTap: _refresh,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<String>>(
          future: _lines,
          builder: (context, snapshot) {
            final lines = snapshot.data;
            if (lines == null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Reading log...',
                  style: Ty.meta.copyWith(color: T.faint),
                ),
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
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: T.s9,
                        height: 1.3,
                        color: T.dim,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

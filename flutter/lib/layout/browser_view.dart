import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/layout/browser_pane.dart';

/// phone 系布局共用的 browsing 页面：deck 身份留在顶部，其余交给单列 browser。
/// landscape 与 all-in-one 的 deck 身份行各自构造，差异只在传入的 [infoRow]，
/// 高度由 [infoHeight] 决定，[header] 可选。
class BrowsingView extends StatelessWidget {
  const BrowsingView({
    required this.model,
    required this.deck,
    required this.infoRow,
    required this.infoHeight,
    this.header,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final Widget infoRow;
  final double infoHeight;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: T.band,
      child: Column(
        children: [
          ?header,
          SizedBox(height: infoHeight, child: infoRow),
          Expanded(child: PhoneBrowserPane(model: model, deck: deck)),
        ],
      ),
    );
  }
}

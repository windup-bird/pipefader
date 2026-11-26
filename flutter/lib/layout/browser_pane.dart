import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/format.dart';
import 'package:pipefader_gui/core/i18n.dart';
import 'package:pipefader_gui/core/platform/file_dialog.dart';
import 'package:pipefader_gui/layout/app_menu.dart';
import 'package:pipefader_gui/layout/menu/menu_widgets.dart';
import 'package:pipefader_gui/model/library.dart';
import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';
import 'package:pipefader_gui/controls/buttons.dart';
import 'package:pipefader_gui/core/glyph.dart';
import 'package:pipefader_gui/core/device.dart';

/// The bottom band: one bar, then library | lists | tracks and the optional right pane. Each
/// column has its own toggle in the bar; the full layout animates the width, a phone drills down
/// through the same data with [PhoneBrowserPane].
class BrowserPane extends StatelessWidget {
  const BrowserPane({required this.model, this.onClose, super.key});

  final AppModel model;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: T.browser,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final showLibrary = model.libraryOpen && width >= 560;
          final showRight = model.rightOpen && width >= 620;
          final columnW = width >= 1100
              ? 200.0
              : width >= 760
              ? 168.0
              : 132.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BrowserHeader(
                model: model,
                onClose: onClose,
                showLibrary: showLibrary,
                showRight: showRight,
                columnW: columnW,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AnimatedColumn(
                      open: showLibrary,
                      width: columnW,
                      color: T.browser,
                      childKey: showLibrary
                          ? const ValueKey('library-pane')
                          : null,
                      child: _LibraryColumn(model: model),
                    ),
                    SizedBox(
                      width: columnW,
                      child: ColoredBox(
                        color: T.browserCol,
                        child: _ListColumn(model: model),
                      ),
                    ),
                    Expanded(
                      child: ColoredBox(
                        color: T.browser,
                        child: _TracksColumn(model: model),
                      ),
                    ),
                    _AnimatedColumn(
                      key: const ValueKey('browser-right'),
                      open: showRight,
                      width: columnW,
                      color: T.browserCol,
                      childKey: showRight
                          ? const ValueKey('browser-blank')
                          : null,
                      child: const SizedBox.expand(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A column whose width animates between zero and its natural width. The child keeps its layout
/// while it is clipped, so opening and closing does not re-flow the rows.
class _AnimatedColumn extends StatelessWidget {
  const _AnimatedColumn({
    required this.open,
    required this.width,
    required this.color,
    required this.child,
    this.childKey,
    super.key,
  });

  final bool open;
  final double width;
  final Color color;
  final Widget child;
  final Key? childKey;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: open ? width : 0,
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: width,
          maxWidth: width,
          child: SizedBox(
            key: childKey,
            width: width,
            child: ColoredBox(color: color, child: child),
          ),
        ),
      ),
    );
  }
}

/// The header follows the column layout instead of spanning it: each segment sits over its own
/// pane, so the library toggle moves right when the library opens and the right toggle moves left
/// when the right pane opens. Library-only keys disappear with their column.
class _BrowserHeader extends StatelessWidget {
  const _BrowserHeader({
    required this.model,
    required this.onClose,
    required this.showLibrary,
    required this.showRight,
    required this.columnW,
  });

  final AppModel model;
  final VoidCallback? onClose;
  final bool showLibrary;
  final bool showRight;
  final double columnW;

  @override
  Widget build(BuildContext context) {
    if (model.searchOpen) {
      return _SearchBar(model: model, onClose: onClose);
    }
    final l10n = L10nScope.of(context);
    final source = model.libraryRoots.isEmpty
        ? l10n.library
        : model.libraryRoots[model.selectedLibrary].name;
    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: T.browserBar)),
          Positioned.fill(
            child: Row(
              children: [
                _HeaderSegment(
                  open: showLibrary,
                  width: columnW,
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      GlyphButton(
                        key: const ValueKey('browser-rescan'),
                        glyph: GlyphKind.refresh,
                        size: 28,
                        onTap: () => unawaited(model.rescanLibrary()),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                SizedBox(
                  width: columnW,
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      GlyphButton(
                        key: const ValueKey('library-toggle'),
                        glyph: GlyphKind.panel,
                        size: 28,
                        onTap: model.toggleLibrary,
                        active: model.libraryOpen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ty.menuRow.copyWith(fontSize: T.s11),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 460;
                      final veryWide = constraints.maxWidth >= 720;
                      return Row(
                        children: [
                          if (veryWide)
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _StatusLine(model: model),
                              ),
                            )
                          else
                            const Spacer(),
                          if (wide)
                            PanelButton(
                              key: const ValueKey('browser-analyse'),
                              label: model.analysing
                                  ? l10n.analysing
                                  : l10n.analyse,
                              rawLabel: true,
                              glyph: GlyphKind.analyse,
                              height: 30,
                              active: model.analysing,
                              onTap: model.canAnalyse && !model.analysing
                                  ? () => unawaited(model.analyseList())
                                  : null,
                              style: Ty.button.copyWith(fontSize: T.s9),
                            )
                          else
                            GlyphButton(
                              key: const ValueKey('browser-analyse'),
                              glyph: GlyphKind.analyse,
                              size: 28,
                              active: model.analysing,
                              onTap: model.canAnalyse && !model.analysing
                                  ? () => unawaited(model.analyseList())
                                  : null,
                            ),
                          const SizedBox(width: 8),
                          GlyphButton(
                            key: const ValueKey('search-toggle'),
                            glyph: GlyphKind.search,
                            size: 28,
                            onTap: model.toggleSearch,
                            active: model.searchOpen,
                          ),
                          const SizedBox(width: 8),
                          GlyphButton(
                            key: const ValueKey('right-toggle'),
                            glyph: GlyphKind.panelRight,
                            size: 28,
                            onTap: model.toggleRight,
                            active: model.rightOpen,
                          ),
                          if (onClose != null) ...[
                            const SizedBox(width: 8),
                            GlyphButton(
                              key: const ValueKey('browser-close'),
                              glyph: GlyphKind.close,
                              size: 28,
                              onTap: onClose,
                            ),
                          ],
                          const SizedBox(width: 8),
                        ],
                      );
                    },
                  ),
                ),
                _HeaderSegment(
                  open: showRight,
                  width: columnW,
                  child: const SizedBox.expand(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSegment extends StatelessWidget {
  const _HeaderSegment({
    required this.open,
    required this.width,
    required this.child,
  });

  final bool open;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: IgnorePointer(
        ignoring: !open,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: open ? width : 0,
          height: 44,
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: width,
            maxWidth: width,
            child: SizedBox(width: width, height: 44, child: child),
          ),
        ),
      ),
    );
  }
}

/// Search takes the whole bar: source and list scopes on the left, the field, then close. The two
/// scopes are filters, not navigation; they only change what `librarySearch` is allowed to return.
class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.model, required this.onClose});

  final AppModel model;
  final VoidCallback? onClose;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.model.searchText,
  );
  final FocusNode _focus = FocusNode();

  AppModel get model => widget.model;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final sourceLabel = model.searchSourceId == null
        ? l10n.allLibraries
        : model.libraryRoots
              .where((root) => root.id == model.searchSourceId)
              .map((root) => root.name)
              .firstOrNull ??
              l10n.allLibraries;
    final listLabel = model.searchListId == null
        ? l10n.allLists
        : model.lists
              .where((list) => list.id == model.searchListId)
              .map((list) => list.name)
              .firstOrNull ??
              l10n.allLists;
    return SizedBox(
      height: 44,
      child: ColoredBox(
        color: T.surfaceHi,
        child: Row(
          children: [
            const SizedBox(width: 6),
            SizedBox(
              width: 112,
              child: _ScopeButton(
                key: const ValueKey('search-source'),
                label: sourceLabel,
                onTap: _pickSource,
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 112,
              child: _ScopeButton(
                key: const ValueKey('search-list'),
                label: listLabel,
                onTap: _pickList,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                cursorColor: T.accent,
                cursorWidth: 1,
                style: Ty.body,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: l10n.searchLibrary,
                  hintStyle: Ty.body.copyWith(color: T.faint),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: model.setSearch,
                onSubmitted: (_) => model.toggleSearch(),
              ),
            ),
            GlyphButton(
              key: const ValueKey('search-toggle'),
              glyph: GlyphKind.close,
              size: 28,
              onTap: model.toggleSearch,
              active: true,
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSource(BuildContext context) async {
    final options = <(String, int?)>[
      (L10nScope.of(context).allLibraries, null),
      for (final root in model.libraryRoots) (root.name, root.id),
    ];
    final picked = await _showScopeMenu(
      context,
      options,
      model.searchSourceId,
    );
    if (picked == null) return;
    model.setSearchSource(picked.value);
    if (mounted) setState(() {});
  }

  Future<void> _pickList(BuildContext context) async {
    final options = <(String, int?)>[
      (L10nScope.of(context).allLists, null),
      for (final list in model.lists) (list.name, list.id),
    ];
    final picked = await _showScopeMenu(context, options, model.searchListId);
    if (picked == null) return;
    model.setSearchList(picked.value);
    if (mounted) setState(() {});
  }
}

class _ScopePick {
  const _ScopePick(this.value);

  final int? value;
}

class _ScopeButton extends StatelessWidget {
  const _ScopeButton({required this.label, required this.onTap, super.key});

  final String label;
  final void Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) {
    return PanelButton(
      label: label,
      rawLabel: true,
      height: 30,
      onTap: () => onTap(context),
      trailing: const Glyph(GlyphKind.chevronDown, size: 10, color: T.faint),
      style: Ty.button.copyWith(fontSize: T.s9),
    );
  }
}

Future<_ScopePick?> _showScopeMenu(
  BuildContext context,
  List<(String, int?)> options,
  int? selected,
) async {
  final overlay = Overlay.of(context);
  final box = context.findRenderObject();
  final rect = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : Rect.fromLTWH(0, 44, 220, 1);
  late final OverlayEntry entry;
  final completer = Completer<_ScopePick?>();
  void close(_ScopePick? value) {
    if (entry.mounted) entry.remove();
    if (!completer.isCompleted) completer.complete(value);
  }

  entry = OverlayEntry(
    builder: (context) {
      final screen = MediaQuery.sizeOf(context);
      final width = math.max(rect.width, 220.0).toDouble();
      final left = rect.left
          .clamp(6.0, math.max(6.0, screen.width - width - 6))
          .toDouble();
      final top = math.min(rect.bottom + 4, screen.height - 60).toDouble();
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => close(null),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: width,
            child: Material(
              type: MaterialType.transparency,
              child: DecoratedBox(
                decoration: panelFace(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final option in options)
                          MenuListRow(
                            label: option.$1,
                            selected: option.$2 == selected,
                            onTap: () => close(_ScopePick(option.$2)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
  return completer.future;
}

/// The bar's idle readout: how many tracks are listed, how long they run and how many still need
/// analysis. Hidden on narrow widths; the same numbers are in the tracks pane there.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    if (model.analysing) {
      return Text(
        l10n.analysing,
        style: Ty.meta.copyWith(color: T.accent),
      );
    }
    final count = model.visibleTracks.length;
    final minutes = (model.visibleSeconds / 60).round();
    final analysed = model.analysedCount;
    final total = model.visibleTracks.length;
    final analysis = analysed >= total
        ? l10n.allAnalysed
        : l10n.unanalysed(total - analysed);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.tracksCount(count), style: Ty.meta.copyWith(color: T.text)),
        const SizedBox(width: 12),
        Text(l10n.minutes(minutes), style: Ty.meta.copyWith(color: T.dim)),
        const SizedBox(width: 12),
        Text(analysis, style: Ty.meta.copyWith(color: T.dim)),
      ],
    );
  }
}

class _LibraryColumn extends StatelessWidget {
  const _LibraryColumn({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
          child: PanelButton(
            key: const ValueKey('library-add'),
            label: l10n.add,
            rawLabel: true,
            glyph: GlyphKind.plus,
            height: 32,
            onTap: () => unawaited(_showAddSource(context, model)),
            style: Ty.button.copyWith(fontSize: T.s9),
          ),
        ),
        Expanded(
          child: model.libraryRoots.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    l10n.noSources,
                    style: Ty.bodySmall.copyWith(color: T.faint),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: model.libraryRoots.length,
                  itemBuilder: (context, index) => EntryRow(
                    label: model.libraryRoots[index].name,
                    selected: model.selectedLibrary == index,
                    onTap: () => model.selectLibrary(index),
                  ),
                ),
        ),
      ],
    );
  }

}

class _ListColumn extends StatelessWidget {
  const _ListColumn({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    if (model.lists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          l10n.noLists,
          style: Ty.bodySmall.copyWith(color: T.faint),
        ),
      );
    }
    final rows = _listTreeRows(model);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final entry = row.entry;
        return EntryRow(
          key: ValueKey('list-${entry.id}'),
          label: entry.name,
          depth: row.depth,
          selected: model.selectedListId == entry.id,
          expandable: entry.hasChildren,
          expanded: model.isListExpanded(entry.id),
          onToggle: () => model.toggleList(entry.id),
          toggleKey: ValueKey('list-toggle-${entry.id}'),
          onTap: () => model.openList(entry),
        );
      },
    );
  }
}

class _ListTreeNode {
  const _ListTreeNode(this.entry, this.depth);

  final ListEntry entry;
  final int depth;
}

List<_ListTreeNode> _listTreeRows(AppModel model) {
  final byParent = <int?, List<ListEntry>>{};
  for (final entry in model.lists) {
    byParent.putIfAbsent(entry.parentId, () => <ListEntry>[]).add(entry);
  }
  final rows = <_ListTreeNode>[];
  void walk(int? parent, int depth) {
    for (final entry in byParent[parent] ?? const <ListEntry>[]) {
      rows.add(_ListTreeNode(entry, depth));
      if (entry.hasChildren && model.isListExpanded(entry.id)) {
        walk(entry.id, depth + 1);
      }
    }
  }

  walk(null, 0);
  // A malformed cache can report a parent that is not in this source; show those rows rather
  // than silently hiding a list. Children of a collapsed parent are intentionally not shown.
  final ids = model.lists.map((entry) => entry.id).toSet();
  for (final entry in model.lists) {
    if (entry.parentId != null && !ids.contains(entry.parentId)) {
      rows.add(_ListTreeNode(entry, 0));
    }
  }
  return rows;
}

/// A bare icon tap target for the phone browser bar: no key face, just the
/// glyph with a hover tint.
class IconKey extends StatefulWidget {
  const IconKey({required this.glyph, required this.onTap, super.key});

  final GlyphKind glyph;
  final VoidCallback onTap;

  @override
  State<IconKey> createState() => _IconKeyState();
}

class _IconKeyState extends State<IconKey> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Glyph(
              widget.glyph,
              size: 15,
              color: _hover ? T.text : T.dim,
            ),
          ),
        ),
      ),
    );
  }
}

class EntryRow extends StatefulWidget {
  const EntryRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.depth = 0,
    this.expandable = false,
    this.expanded = false,
    this.onToggle,
    this.toggleKey,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int depth;
  final bool expandable;
  final bool expanded;
  final VoidCallback? onToggle;
  final Key? toggleKey;

  @override
  State<EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<EntryRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? T.accent
        : _hover
        ? T.text
        : T.dim;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 30,
          color: widget.selected
              ? T.surface
              : _hover
              ? T.surfaceLo
              : Colors.transparent,
          padding: EdgeInsets.only(
            left: 10 + widget.depth * 14.0,
            right: 10,
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: widget.expandable
                    ? GestureDetector(
                        key: widget.toggleKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onToggle,
                        child: Center(
                          child: Glyph(
                            widget.expanded
                                ? GlyphKind.chevronDown
                                : GlyphKind.chevronRight,
                            size: 11,
                            color: widget.selected ? T.accent : T.faint,
                          ),
                        ),
                      )
                    : null,
              ),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: T.s12,
                    height: 1.0,
                    color: color,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TracksColumn extends StatelessWidget {
  const _TracksColumn({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final tracks = model.visibleTracks;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showBpm = width >= 430;
        final showKey = width >= 520;
        final showTime = width >= 600;
        if (tracks.isEmpty) {
          return Center(
            child: Text(
              L10nScope.of(context).noMatches,
              style: Ty.bodySmall.copyWith(color: T.faint),
            ),
          );
        }
        return _TrackViewport(
          selected: model.selectedTrack,
          itemExtent: _TrackRow.height,
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            final row = _TrackRow(
              index: index,
              track: track,
              selected: model.selectedTrack == index,
              showBpm: showBpm,
              showKey: showKey,
              showTime: showTime,
              onTap: () => model.selectTrack(index),
            );
            if (track.locationId < 0) return row;
            return LongPressDraggable<TrackRow>(
              data: track,
              delay: const Duration(milliseconds: 100),
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: _TrackDragFeedback(track: track),
              childWhenDragging: Opacity(opacity: 0.35, child: row),
              child: row,
            );
          },
        );
      },
    );
  }
}

/// The small card under the pointer while a library row is dragged to a deck.
class _TrackDragFeedback extends StatelessWidget {
  const _TrackDragFeedback({required this.track, this.wide = false});

  final TrackRow track;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: wide ? 280 : 240),
        decoration: panelFace(color: T.surfaceHi),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 3, height: 28, color: T.accent),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: T.s12,
                      color: T.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: T.s10, color: T.dim),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackRow extends StatefulWidget {
  static const height = 30.0;

  const _TrackRow({
    required this.index,
    required this.track,
    required this.selected,
    required this.showBpm,
    required this.showKey,
    required this.showTime,
    required this.onTap,
  });

  final int index;
  final TrackRow track;
  final bool selected;
  final bool showBpm;
  final bool showKey;
  final bool showTime;
  final VoidCallback onTap;

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: _TrackRow.height,
          color: selected
              ? T.surfaceHi
              : _hover
              ? T.surfaceLo
              : Colors.transparent,
          padding: const EdgeInsets.only(right: 10),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  '${widget.index + 1}'.padLeft(2, '0'),
                  textAlign: TextAlign.center,
                  style: Ty.labelSmall.copyWith(
                    color: selected ? T.accent : T.faint,
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: track.title,
                        style: TextStyle(
                          fontSize: T.s12_5,
                          height: 1.0,
                          color: selected ? T.accent : T.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: '   ${track.artist}',
                        style: const TextStyle(
                          fontSize: T.s11,
                          height: 1.0,
                          color: T.dim,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.showBpm)
                SizedBox(
                  width: 48,
                  child: Text(
                    bpmText(track.bpm),
                    textAlign: TextAlign.right,
                    style: Ty.labelSmall.copyWith(color: T.dim),
                  ),
                ),
              if (widget.showKey)
                SizedBox(
                  width: 48,
                  child: Text(
                    track.key,
                    textAlign: TextAlign.right,
                    style: Ty.labelSmall.copyWith(color: T.dim),
                  ),
                ),
              if (widget.showTime)
                SizedBox(
                  width: 52,
                  child: Text(
                    shortClock(track.seconds),
                    textAlign: TextAlign.right,
                    style: Ty.labelSmall.copyWith(color: T.dim),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The phone browser: a single column that drills from library roots to lists
/// to tracks, the way a file manager does. One row of chrome carries the back
/// key, the current title, search and close. Loading a track closes the sheet
/// but keeps [AppModel.browseDepth], so reopening returns to the same list.
class PhoneBrowserPane extends StatelessWidget {
  const PhoneBrowserPane({required this.model, required this.deck, super.key});

  final AppModel model;
  final DeckRuntime deck;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: T.browser,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PhoneBrowserBar(model: model),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (model.searchOpen && model.searchText.trim().isNotEmpty) {
      return _TrackList(
        model: model,
        tracks: model.visibleTracks,
        onTap: (index) => model.loadTrackOnto(deck, index),
      );
    }
    final l10n = L10nScope.of(context);
    return switch (model.browseDepth) {
      0 => ListView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            child: PanelButton(
              key: const ValueKey('library-add'),
              label: l10n.add,
              rawLabel: true,
              glyph: GlyphKind.plus,
              height: 34,
              onTap: () => unawaited(_showAddSource(context, model)),
              style: Ty.button.copyWith(fontSize: T.s9),
            ),
          ),
          for (var index = 0; index < model.libraryRoots.length; index++)
            EntryRow(
              label: model.libraryRoots[index].name,
              selected: model.selectedLibrary == index,
              onTap: () {
                model.selectLibrary(index);
                model.browseInto();
              },
            ),
        ],
      ),
      1 => Builder(
        builder: (context) {
          final rows = _listTreeRows(model);
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final entry = row.entry;
              return EntryRow(
                key: ValueKey('list-${entry.id}'),
                label: entry.name,
                depth: row.depth,
                selected: model.selectedListId == entry.id,
                expandable: entry.hasChildren,
                expanded: model.isListExpanded(entry.id),
                onToggle: () => model.toggleList(entry.id),
                toggleKey: ValueKey('list-toggle-${entry.id}'),
                onTap: () {
                  model.openList(entry);
                  if (!entry.hasChildren) model.browseInto();
                },
              );
            },
          );
        },
      ),
      _ => _TrackList(
        model: model,
        tracks: model.visibleTracks,
        onTap: (index) => model.loadTrackOnto(deck, index),
      ),
    };
  }

}

class _PhoneBrowserBar extends StatelessWidget {
  const _PhoneBrowserBar({required this.model});

  final AppModel model;

  String _title(L10n l10n) => switch (model.browseDepth) {
    0 => l10n.library,
    1 => model.lists.isEmpty
        ? l10n.noLists
        : model.lists
                  .where((entry) => entry.id == model.selectedListId)
                  .map((entry) => entry.name)
                  .firstOrNull ??
              l10n.noLists,
    _ => l10n.allTracks,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ColoredBox(
        color: model.searchOpen ? T.surfaceHi : T.browserBar,
        child: Row(
          children: [
            if (model.searchOpen)
              IconKey(
                key: const ValueKey('search-toggle'),
                glyph: GlyphKind.close,
                onTap: model.toggleSearch,
              )
            else if (model.browseDepth > 0)
              IconKey(
                key: const ValueKey('browse-back'),
                glyph: GlyphKind.chevronLeft,
                onTap: model.browseBack,
              )
            else
              const SizedBox(width: 4),
            Expanded(
              child: model.searchOpen
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _PhoneSearchField(model: model),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _title(L10nScope.of(context)),
                        style: Ty.label.copyWith(color: T.text),
                      ),
                    ),
            ),
            if (!model.searchOpen && model.browseDepth == 2)
              IconKey(
                key: const ValueKey('browser-analyse'),
                glyph: GlyphKind.analyse,
                onTap: () => unawaited(model.analyseList()),
              ),
            if (!model.searchOpen)
              IconKey(
                key: const ValueKey('search-toggle'),
                glyph: GlyphKind.search,
                onTap: model.toggleSearch,
              ),
            const SizedBox(width: 4),
            IconKey(
              key: const ValueKey('browser-close'),
              glyph: GlyphKind.close,
              onTap: model.closeBrowserOverlay,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _PhoneSearchField extends StatelessWidget {
  const _PhoneSearchField({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    return TextField(
      autofocus: true,
      cursorColor: T.accent,
      cursorWidth: 1,
      style: Ty.body,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: l10n.searchLibrary,
        hintStyle: Ty.body.copyWith(color: T.faint),
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: model.setSearch,
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({
    required this.model,
    required this.tracks,
    required this.onTap,
  });

  final AppModel model;
  final List<TrackRow> tracks;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          L10nScope.of(context).noMatches,
          style: Ty.bodySmall.copyWith(color: T.faint),
        ),
      );
    }
    return _TrackViewport(
      selected: model.selectedTrack,
      itemExtent: _PhoneTrackRow.height,
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final row = _PhoneTrackRow(
          track: track,
          selected: model.selectedTrack == index,
          onTap: () => onTap(index),
        );
        if (track.locationId < 0) return row;
        return LongPressDraggable<TrackRow>(
          data: track,
          delay: const Duration(milliseconds: 100),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _TrackDragFeedback(track: track, wide: true),
          childWhenDragging: Opacity(opacity: 0.35, child: row),
          child: row,
        );
      },
    );
  }
}

/// Reveal the browser cursor after external navigation, without forcing the
/// view back to it when the user scrolls manually.
class _TrackViewport extends StatefulWidget {
  const _TrackViewport({
    required this.selected,
    required this.itemExtent,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int selected;
  final double itemExtent;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_TrackViewport> createState() => _TrackViewportState();
}

class _TrackViewportState extends State<_TrackViewport> {
  static const _padding = 4.0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _revealCursor();
  }

  @override
  void didUpdateWidget(_TrackViewport old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected || old.itemCount != widget.itemCount) {
      _revealCursor();
    }
  }

  void _revealCursor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final pos = _scroll.position;
      final top = _padding + widget.selected * widget.itemExtent;
      final bottom = top + widget.itemExtent;
      final target = top < pos.pixels
          ? top
          : bottom > pos.pixels + pos.viewportDimension
          ? bottom - pos.viewportDimension
          : pos.pixels;
      final pixels = target.clamp(pos.minScrollExtent, pos.maxScrollExtent);
      if (pixels != pos.pixels) _scroll.jumpTo(pixels);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.symmetric(vertical: _padding),
    itemExtent: widget.itemExtent,
    itemCount: widget.itemCount,
    itemBuilder: widget.itemBuilder,
  );
}

class _PhoneTrackRow extends StatelessWidget {
  static const height = 44.0;

  const _PhoneTrackRow({
    required this.track,
    required this.selected,
    required this.onTap,
  });

  final TrackRow track;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: height,
        color: selected ? T.surfaceHi : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: T.s13,
                      height: 1.1,
                      color: selected ? T.accent : T.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: T.s11,
                      height: 1.0,
                      color: T.dim,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              bpmText(track.bpm),
              style: Ty.labelSmall.copyWith(color: T.dim),
            ),
            const SizedBox(width: 10),
            Text(track.key, style: Ty.labelSmall.copyWith(color: T.dim)),
            const SizedBox(width: 10),
            Text(
              shortClock(track.seconds),
              style: Ty.labelSmall.copyWith(color: T.faint),
            ),
          ],
        ),
      ),
    );
  }
}

/// The overlay form the shell falls back to (kept for layouts that host the
/// browser over the page).

enum _SourceChoice { folder, usb, settings }

/// The Add key in the library column: a folder, a mounted volume, or the settings page that owns
/// the same list. The folder and USB choices both end in the host's directory picker; Android turns
/// the SAF tree into a real path before the backend sees it.
Future<void> _showAddSource(BuildContext context, AppModel model) async {
  final l10n = L10nScope.of(context);
  final choice = await showDialog<_SourceChoice>(
    context: context,
    barrierColor: T.scrim,
    builder: (context) => _AddSourceDialog(l10n: l10n),
  );
  if (choice == null || !context.mounted) return;
  if (choice == _SourceChoice.settings) {
    showPreferencesMenu(context, model: model);
    return;
  }
  final path = await pickDirectory();
  if (path == null) return;
  await model.addLibraryFolder(path);
}

class _AddSourceDialog extends StatelessWidget {
  const _AddSourceDialog({required this.l10n});

  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: math.min(340.0, MediaQuery.sizeOf(context).width - 32),
        child: DecoratedBox(
          decoration: panelFace(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.addSource, style: Ty.pageTitle),
                const SizedBox(height: 12),
                MenuListRow(
                  key: const ValueKey('source-folder'),
                  label: l10n.folder,
                  onTap: () =>
                      Navigator.of(context).pop(_SourceChoice.folder),
                ),
                const SizedBox(height: 6),
                MenuListRow(
                  key: const ValueKey('source-usb'),
                  label: l10n.usb,
                  note: l10n.chooseVolume,
                  onTap: () => Navigator.of(context).pop(_SourceChoice.usb),
                ),
                const SizedBox(height: 6),
                MenuListRow(
                  key: const ValueKey('source-settings'),
                  label: l10n.librarySettings,
                  onTap: () =>
                      Navigator.of(context).pop(_SourceChoice.settings),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

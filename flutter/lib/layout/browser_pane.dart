import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../model/library.dart';
import '../state/app_model.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/glyph.dart';

/// The bottom band: one bar with the two column switches and the search box,
/// then library | lists | tracks.
class BrowserPane extends StatelessWidget {
  const BrowserPane({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BrowserBar(model: model),
        Container(height: 1, color: T.hair),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            final showLibrary = model.libraryOpen && width >= 560;
            final libraryWidth = width >= 900 ? 200.0 : 176.0;
            final listWidth = width >= 900
                ? 200.0
                : width >= 560
                    ? 148.0
                    : 116.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showLibrary) ...[
                  SizedBox(
                    width: libraryWidth,
                    child: _LibraryColumn(model: model),
                  ),
                  Container(width: 1, color: T.hair),
                ],
                SizedBox(width: listWidth, child: _ListColumn(model: model)),
                Container(width: 1, color: T.hair),
                Expanded(child: _TracksColumn(model: model)),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _BrowserBar extends StatefulWidget {
  const _BrowserBar({required this.model});

  final AppModel model;

  @override
  State<_BrowserBar> createState() => _BrowserBarState();
}

class _BrowserBarState extends State<_BrowserBar> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.model.searchText);
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(_BrowserBar old) {
    super.didUpdateWidget(old);
    if (!widget.model.searchOpen && _controller.text.isNotEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          GlyphButton(
            key: const ValueKey('library-toggle'),
            glyph: GlyphKind.panel,
            onTap: widget.model.toggleLibrary,
            active: widget.model.libraryOpen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: widget.model.searchOpen
                ? SizedBox(
                    height: 26,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: true,
                      cursorColor: T.accent,
                      cursorWidth: 1,
                      style: const TextStyle(
                        fontSize: T.s12,
                        color: T.text,
                        height: 1.2,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'search library',
                        hintStyle: TextStyle(
                          fontSize: T.s12,
                          color: T.faint,
                          height: 1.2,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: widget.model.setSearch,
                      onSubmitted: (_) => widget.model.toggleSearch(),
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text('BROWSER', style: Ty.label),
                  ),
          ),
          GlyphButton(
            key: const ValueKey('search-toggle'),
            glyph: GlyphKind.search,
            onTap: widget.model.toggleSearch,
            active: widget.model.searchOpen,
          ),
          const SizedBox(width: 4),
          const GlyphButton(glyph: GlyphKind.panelRight, onTap: null),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _LibraryColumn extends StatelessWidget {
  const _LibraryColumn({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: model.libraryRoots.length,
      itemBuilder: (context, index) => EntryRow(
        label: model.libraryRoots[index].name,
        selected: model.selectedLibrary == index,
        onTap: () => model.selectLibrary(index),
      ),
    );
  }
}

class _ListColumn extends StatelessWidget {
  const _ListColumn({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: model.lists.length,
      itemBuilder: (context, index) => EntryRow(
        label: model.lists[index].name,
        selected: model.selectedList == index,
        onTap: () => model.selectList(index),
      ),
    );
  }
}

class EntryRow extends StatefulWidget {
  const EntryRow({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

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
          height: 32,
          color: widget.selected
              ? T.surface
              : _hover
                  ? T.band
                  : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: T.s12,
              height: 1.0,
              color: color,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
            ),
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
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final showBpm = width >= 430;
      final showKey = width >= 520;
      final showTime = width >= 600;
      if (tracks.isEmpty) {
        return const Center(
          child: Text(
            'no matches',
            style: TextStyle(fontSize: T.s12, color: T.faint),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return _TrackRow(
            index: index,
            track: track,
            selected: model.selectedTrack == index,
            showBpm: showBpm,
            showKey: showKey,
            showTime: showTime,
            onTap: () => model.selectTrack(index),
          );
        },
      );
    });
  }
}

class _TrackRow extends StatefulWidget {
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
          height: 32,
          color: selected
              ? T.surfaceHi
              : _hover
                  ? T.band
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

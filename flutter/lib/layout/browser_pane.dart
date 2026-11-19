import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../model/library.dart';
import '../state/app_model.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/glyph.dart';

/// The bottom band: a header with the two column switches and the status or
/// search field, then library | lists | tracks, plus the empty right column.
/// The library toggle sits at the left edge of the list column so it always
/// lines up with the lists beneath it.
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
              _BrowserBar(
                model: model,
                onClose: onClose,
                libraryWidth: showLibrary ? columnW : 0,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showLibrary)
                      SizedBox(
                        width: columnW,
                        child: ColoredBox(
                          color: T.browser,
                          child: _LibraryColumn(model: model),
                        ),
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
                    if (showRight)
                      SizedBox(
                        key: const ValueKey('browser-blank'),
                        width: columnW,
                        child: const ColoredBox(color: T.browserCol),
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

class _BrowserBar extends StatefulWidget {
  const _BrowserBar({
    required this.model,
    required this.onClose,
    required this.libraryWidth,
  });

  final AppModel model;
  final VoidCallback? onClose;

  /// The width the library column occupies; the toggle is padded by it so the
  /// key always sits at the left edge of the lists below.
  final double libraryWidth;

  @override
  State<_BrowserBar> createState() => _BrowserBarState();
}

class _BrowserBarState extends State<_BrowserBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.model.searchText,
  );
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
    final model = widget.model;
    // The library key rides at the left edge of the list column: padded by
    // whatever width the library column takes, so it shifts right when the
    // library is open and returns to the page edge when it is not.
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlyphButton(
          key: const ValueKey('search-toggle'),
          glyph: GlyphKind.search,
          onTap: model.toggleSearch,
          active: model.searchOpen,
        ),
        const SizedBox(width: 6),
        GlyphButton(
          key: const ValueKey('right-toggle'),
          glyph: GlyphKind.panelRight,
          onTap: model.toggleRight,
          active: model.rightOpen,
        ),
        if (widget.onClose != null) ...[
          const SizedBox(width: 8),
          GlyphButton(
            key: const ValueKey('browser-close'),
            glyph: GlyphKind.close,
            onTap: widget.onClose,
          ),
        ],
      ],
    );

    return SizedBox(
      height: 42,
      child: Stack(
        children: [
          // The header surface: a shade above the browser body, no rules.
          const Positioned.fill(child: ColoredBox(color: T.browserBar)),
          if (model.searchOpen)
            // Search covers the whole bar, brighter, edge to edge.
            Positioned.fill(
              child: ColoredBox(
                color: T.surfaceHi,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        autofocus: true,
                        cursorColor: T.accent,
                        cursorWidth: 1,
                        style: const TextStyle(
                          fontSize: T.s13,
                          color: T.text,
                          height: 1.2,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Search Library',
                          hintStyle: TextStyle(
                            fontSize: T.s13,
                            color: T.faint,
                            height: 1.2,
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: model.setSearch,
                        onSubmitted: (_) => model.toggleSearch(),
                      ),
                    ),
                    GlyphButton(
                      key: const ValueKey('search-toggle'),
                      glyph: GlyphKind.close,
                      onTap: model.toggleSearch,
                      active: true,
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
            )
          else
            Positioned.fill(
              child: Row(
                children: [
                  // A fixed-width leading box whose right edge is the tracks
                  // column start; the library key sits at its left so it stays
                  // pinned to the page edge.
                  SizedBox(
                    width: widget.libraryWidth > 0 ? widget.libraryWidth : 40,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GlyphButton(
                          key: const ValueKey('library-toggle'),
                          glyph: GlyphKind.panel,
                          onTap: model.toggleLibrary,
                          active: model.libraryOpen,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _StatusLine(model: model),
                    ),
                  ),
                  trailing,
                  const SizedBox(width: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The bar's idle readout: how many tracks are listed, how long they run and
/// how many still need analysis.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final count = model.visibleTracks.length;
    final minutes = (model.visibleSeconds / 60).round();
    final analysed = model.analysedCount;
    final total = model.visibleTracks.length;
    final analysis = analysed >= total ? '全部已分析' : '未分析 ${total - analysed} 首';
    return Row(
      children: [
        Text('$count 首歌', style: Ty.meta.copyWith(color: T.text)),
        const SizedBox(width: 12),
        Text('$minutes 分钟', style: Ty.meta.copyWith(color: T.dim)),
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: model.lists.length,
      itemBuilder: (context, index) => EntryRow(
        label: model.lists[index].name,
        selected: model.selectedList == index,
        onTap: () => model.selectList(index),
      ),
    );
  }
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
          height: 30,
          color: widget.selected
              ? T.surface
              : _hover
              ? T.surfaceLo
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
    return LayoutBuilder(
      builder: (context, constraints) {
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
          padding: const EdgeInsets.symmetric(vertical: 4),
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
      },
    );
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
          height: 30,
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
    return switch (model.browseDepth) {
      0 => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: model.libraryRoots.length,
        itemBuilder: (context, index) => EntryRow(
          label: model.libraryRoots[index].name,
          selected: model.selectedLibrary == index,
          onTap: () {
            model.selectLibrary(index);
            model.browseInto();
          },
        ),
      ),
      1 => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: model.lists.length,
        itemBuilder: (context, index) => EntryRow(
          label: model.lists[index].name,
          selected: model.selectedList == index,
          onTap: () {
            model.selectList(index);
            model.browseInto();
          },
        ),
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

  String get _title => switch (model.browseDepth) {
    0 => 'Library',
    1 => model.lists[model.selectedList].name,
    _ => 'All Tracks',
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
                        _title,
                        style: Ty.label.copyWith(color: T.text),
                      ),
                    ),
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
    return TextField(
      autofocus: true,
      cursorColor: T.accent,
      cursorWidth: 1,
      style: const TextStyle(fontSize: T.s13, color: T.text, height: 1.2),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: 'Search Library',
        hintStyle: TextStyle(fontSize: T.s13, color: T.faint, height: 1.2),
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
      return const Center(
        child: Text(
          'No Matches',
          style: TextStyle(fontSize: T.s12, color: T.faint),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return _PhoneTrackRow(
          track: track,
          selected: model.selectedTrack == index,
          onTap: () => onTap(index),
        );
      },
    );
  }
}

class _PhoneTrackRow extends StatelessWidget {
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
        height: 44,
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
            const SizedBox(width: 12),
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
class BrowserOverlay extends StatelessWidget {
  const BrowserOverlay({required this.model, required this.deck, super.key});

  final AppModel model;
  final DeckRuntime deck;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: model.closeBrowserOverlay,
            child: ColoredBox(color: T.scrim),
          ),
        ),
        Positioned.fill(
          child: PhoneBrowserPane(model: model, deck: deck),
        ),
      ],
    );
  }
}

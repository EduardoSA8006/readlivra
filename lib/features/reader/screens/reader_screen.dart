import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/result/app_exceptions.dart';
import '../../stats/data/reading_session_service.dart';
import '../../stats/providers.dart';
import '../../../core/models/bookmark.dart';
import '../../../core/models/highlight.dart';
import '../../library/providers.dart';
import '../data/block_cache.dart';
import '../data/chapter_blocks.dart';
import '../data/font_resolver.dart';
import '../data/highlight_renderer.dart';
import '../data/simple_block_renderer.dart';
import '../../../core/models/ebook.dart';
import '../data/models/reading_preferences.dart';
import '../providers.dart';
import '../viewmodels/reader_state.dart';
import '../viewmodels/reader_viewmodel.dart';
import 'annotations_list_sheet.dart';
import 'reading_preferences_sheet.dart';
import 'toc_drawer.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    this.bookId,
    this.path,
    this.autoPick = true,
    this.initialChapter,
    this.initialAnchorBlock,
    this.initialAnchorAlignment,
  });

  /// Optional library entry id — when provided, progress is restored and
  /// persisted across sessions.
  final String? bookId;

  /// Path of the EPUB to open. When null and [autoPick] is true, the screen
  /// triggers a file picker on first frame.
  final String? path;

  /// Only relevant when [path] is null.
  final bool autoPick;

  /// When provided, the reader opens directly on this chapter instead of
  /// resuming from the saved anchor.
  final int? initialChapter;

  /// Optional block within [initialChapter] to anchor on.
  final int? initialAnchorBlock;

  /// Alignment within [initialAnchorBlock] (0..1).
  final double? initialAnchorAlignment;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  ReadingSessionService? _session;
  String? _trackedBookId;
  // Cached during initState so dispose can release the reader state
  // without touching `ref` (which is unsafe once the widget is being
  // unmounted in Riverpod 3).
  late final ReaderViewModel _readerNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readerNotifier = ref.read(readerViewModelProvider.notifier);
    _initSessionService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(readerViewModelProvider);
      if (s is! ReaderIdle) return;
      if (widget.path != null) {
        final anchor = widget.initialAnchorBlock == null
            ? null
            : ReaderAnchor(
                blockIndex: widget.initialAnchorBlock!,
                alignment: widget.initialAnchorAlignment ?? 0,
              );
        _readerNotifier.openEpub(
          widget.path!,
          bookId: widget.bookId,
          initialChapter: widget.initialChapter,
          initialAnchor: anchor,
        );
      } else if (widget.autoPick) {
        _readerNotifier.pickAndOpenEpub();
      }
    });
  }

  Future<void> _initSessionService() async {
    _session = await ref.read(readingSessionServiceProvider.future);
    if (!mounted) return;
    final s = ref.read(readerViewModelProvider);
    if (s is ReaderReading && s.bookId != null) {
      await _session!.start(s.bookId!);
      _trackedBookId = s.bookId;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = _session;
    if (session == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        session.resume();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        unawaited(session.pause());
      case AppLifecycleState.detached:
        unawaited(session.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_session?.stop());
    // Reset the global reader state so a system-back / swipe-back exit
    // doesn't leave a stale ReaderReading hanging around. Deferred via
    // Future so we don't mutate a provider mid-lifecycle (Riverpod 3
    // forbids that during dispose). The notifier reference was cached
    // in initState because `ref` is unsafe once the widget unmounts.
    final notifier = _readerNotifier;
    Future(() => notifier.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerViewModelProvider);
    final vm = ref.read(readerViewModelProvider.notifier);
    final palette = ref.watch(readerPaletteProvider);

    // Track session lifecycle as the reader transitions between states.
    ref.listen<ReaderState>(readerViewModelProvider, (prev, next) async {
      final session = _session;
      if (session == null) return;
      if (next is ReaderReading && next.bookId != null) {
        if (_trackedBookId != next.bookId) {
          await session.start(next.bookId!);
          _trackedBookId = next.bookId;
        }
      } else if (_trackedBookId != null) {
        await session.stop();
        _trackedBookId = null;
      }
    });

    final readingState = state is ReaderReading ? state : null;
    return Scaffold(
      backgroundColor: palette.background,
      drawer: readingState == null
          ? null
          : TocDrawer(
              ebook: readingState.ebook,
              currentChapter: readingState.chapterIndex,
              onChapterTap: (i) => vm.jumpToAnchor(
                chapterIndex: i,
                blockIndex: 0,
                blockAlignment: 0,
              ),
            ),
      // Only allow the edge-swipe gesture while reading.
      drawerEnableOpenDragGesture: readingState != null,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          color: palette.textPrimary,
          onPressed: () {
            final navigator = Navigator.of(context);
            _trackedBookId = null;
            vm.close();
            unawaited(_session?.stop());
            navigator.maybePop();
          },
        ),
        title: switch (state) {
          ReaderReading(:final ebook, :final chapterIndex) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ebook.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                'Cap. ${chapterIndex + 1} de ${ebook.chapterCount}',
                style: TextStyle(fontSize: 11, color: palette.textSecondary),
              ),
            ],
          ),
          _ => const SizedBox.shrink(),
        },
        centerTitle: false,
        actions: [
          if (readingState != null)
            Builder(
              builder: (ctx) => IconButton(
                icon: Icon(
                  Icons.format_list_bulleted_rounded,
                  color: palette.textPrimary,
                ),
                tooltip: 'Sumário',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          if (readingState != null && readingState.bookId != null)
            IconButton(
              icon: Icon(Icons.bookmarks_outlined, color: palette.textPrimary),
              tooltip: 'Marcadores e destaques',
              onPressed: () =>
                  showAnnotationsListSheet(context, readingState.bookId!),
            ),
          if (readingState != null)
            IconButton(
              icon: Icon(Icons.text_fields_rounded, color: palette.textPrimary),
              tooltip: 'Preferências de leitura',
              onPressed: () => showReadingPreferencesSheet(context),
            ),
        ],
      ),
      body: switch (state) {
        ReaderIdle() => _IdleView(onOpen: vm.pickAndOpenEpub),
        ReaderLoading() => const Center(child: CircularProgressIndicator()),
        ReaderError(:final error) => _ErrorView(
          error: error,
          onRetry: vm.pickAndOpenEpub,
        ),
        ReaderReading() => _ReadingView(state: state),
      },
      bottomNavigationBar: state is ReaderReading
          ? _ReaderBottomBar(state: state, vm: vm)
          : null,
    );
  }
}

class _IdleView extends ConsumerWidget {
  const _IdleView({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(readerPaletteProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 56,
              color: palette.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Selecione um arquivo .epub para começar',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: palette.textPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Abrir EPUB'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final AppException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Color(0xFFB35454),
            ),
            const SizedBox(height: 12),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingView extends ConsumerStatefulWidget {
  const _ReadingView({required this.state});
  final ReaderReading state;

  @override
  ConsumerState<_ReadingView> createState() => _ReadingViewState();
}

class _ReadingViewState extends ConsumerState<_ReadingView> {
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();

  /// Block cache keeps the current chapter ± [BlockCache.keepAround] in
  /// memory. With ~150 KB of HTML+blocks per chapter, the 50-chapter
  /// window covers most novels in full while still capping memory on
  /// long books (e.g. 500-chapter web novels).
  final BlockCache _cache = BlockCache(keepAround: 50);
  final Set<int> _pending = <int>{};

  bool _anchorRestored = false;
  List<String>? _currentBlocks;
  int _lastChapterIndex = 0;
  int _navDirection = 1;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onItemPositions);
    _ensureCurrentBlocks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRestoreAnchor();
      _scheduleHousekeeping();
    });
  }

  @override
  void didUpdateWidget(covariant _ReadingView old) {
    super.didUpdateWidget(old);
    if (old.state.chapterIndex != widget.state.chapterIndex) {
      _anchorRestored = false;
      _ensureCurrentBlocks();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeRestoreAnchor();
        _scheduleHousekeeping();
      });
    }
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onItemPositions);
    _cache.clear();
    super.dispose();
  }

  /// Loads (or reuses) the blocks for the chapter the widget is currently
  /// pointing at and stores them in [_currentBlocks]. While the load is in
  /// flight the view shows a small spinner.
  void _ensureCurrentBlocks() {
    final idx = widget.state.chapterIndex;
    final cached = _cache.get(idx);
    if (cached != null) {
      _currentBlocks = cached;
      return;
    }
    _currentBlocks = null;
    _loadBlocks(idx).then((blocks) {
      if (!mounted) return;
      if (widget.state.chapterIndex != idx) return;
      setState(() => _currentBlocks = blocks);
    });
  }

  Future<List<String>> _loadBlocks(int chapterIndex) async {
    final cached = _cache.get(chapterIndex);
    if (cached != null) return cached;
    final chapter = widget.state.ebook.chapters[chapterIndex];
    final html = await chapter.loadHtml();
    final worker = await ref.read(chapterParserWorkerProvider.future);
    final blocks = await worker.split(html);
    _cache.put(chapterIndex, blocks);
    return blocks;
  }

  Future<void> _prefetchNeighbor(int chapterIndex) async {
    final ebook = widget.state.ebook;
    if (chapterIndex < 0 || chapterIndex >= ebook.chapterCount) return;
    if (_cache.contains(chapterIndex) || _pending.contains(chapterIndex)) {
      return;
    }
    _pending.add(chapterIndex);
    try {
      await _loadBlocks(chapterIndex);
    } catch (_) {
      // Best-effort: a sync parse will run on the next visit if this fails.
    } finally {
      _pending.remove(chapterIndex);
    }
  }

  void _scheduleHousekeeping() {
    final current = widget.state.chapterIndex;
    if (current != _lastChapterIndex) {
      _navDirection = current >= _lastChapterIndex ? 1 : -1;
      _lastChapterIndex = current;
    }
    final evicted = _cache.evictFar(current);
    final ebook = widget.state.ebook;
    for (final i in evicted) {
      if (i >= 0 && i < ebook.chapterCount) ebook.chapters[i].clearCache();
    }

    // Always keep the immediate neighbors warm so a stray back-tap is
    // instant; bias the deeper prefetch in the direction the reader is
    // actually moving so forward reading hides the parse cost.
    _prefetchNeighbor(current + 1);
    _prefetchNeighbor(current - 1);
    for (var d = 2; d <= 6; d++) {
      _prefetchNeighbor(current + d * _navDirection);
    }
  }

  void _maybeRestoreAnchor() {
    if (_anchorRestored || !mounted) return;
    final anchor = widget.state.pendingAnchor;
    if (anchor == null) {
      _anchorRestored = true;
      return;
    }
    final blocks = _currentBlocks;
    if (blocks == null) return; // try again once blocks are loaded
    final target = anchor.blockIndex.clamp(0, blocks.length - 1);
    if (!_itemScrollController.isAttached) return;
    _itemScrollController.jumpTo(
      index: target,
      alignment: -anchor.alignment.clamp(0.0, 1.0),
    );
    _anchorRestored = true;
    ref.read(readerViewModelProvider.notifier).clearPendingAnchor();
  }

  void _onItemPositions() {
    if (!_anchorRestored) return;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final visible = positions
        .where((p) => p.itemTrailingEdge > 0)
        .toList(growable: false);
    if (visible.isEmpty) return;
    visible.sort((a, b) => a.index.compareTo(b.index));
    final first = visible.first;
    final logicalIndex = first.index.clamp(0, 1 << 30);
    final alignment = (-first.itemLeadingEdge).clamp(0.0, 1.0).toDouble();

    ref
        .read(readerViewModelProvider.notifier)
        .reportBlockPosition(logicalIndex, alignment);

    // Publish the position so the bottom bar can offer "bookmark current
    // block" without flooding rebuilds — the StateProvider only emits when
    // the value actually changes.
    final next = (
      chapterIndex: widget.state.chapterIndex,
      blockIndex: logicalIndex,
      alignment: alignment,
    );
    final current = ref.read(readingPositionProvider);
    if (current?.chapterIndex != next.chapterIndex ||
        current?.blockIndex != next.blockIndex) {
      ref.read(readingPositionProvider.notifier).update(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_anchorRestored && widget.state.pendingAnchor != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeRestoreAnchor(),
      );
    }
    final blocks = _currentBlocks;
    if (blocks == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final prefs =
        ref.watch(readingPreferencesProvider).value ??
        ReadingPreferences.defaults;
    final bookId = widget.state.bookId;

    final bookmarks = bookId == null
        ? const <Bookmark>[]
        : ref.watch(bookmarksProvider(bookId)).value ?? const <Bookmark>[];
    final highlights = bookId == null
        ? const <Highlight>[]
        : ref.watch(highlightsProvider(bookId)).value ?? const <Highlight>[];

    final bookmarkedBlocks = <int>{
      for (final b in bookmarks)
        if (b.chapterIndex == widget.state.chapterIndex) b.blockIndex,
    };
    // Group highlights per block so each _BlockHtml only sees its own.
    final highlightsByBlock = <int, List<Highlight>>{};
    for (final h in highlights) {
      if (h.chapterIndex != widget.state.chapterIndex) continue;
      highlightsByBlock.putIfAbsent(h.blockIndex, () => []).add(h);
    }

    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      // Don't keep off-screen blocks alive — let the engine free their
      // RenderObjects so memory stays bounded on long chapters.
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        return _BlockHtml(
          html: blocks[index],
          ebook: widget.state.ebook,
          prefs: prefs,
          bookmarked: bookmarkedBlocks.contains(index),
          highlights: highlightsByBlock[index] ?? const [],
          bookId: bookId,
          chapterIndex: widget.state.chapterIndex,
          blockIndex: index,
        );
      },
    );
  }
}

class _BlockHtml extends ConsumerStatefulWidget {
  const _BlockHtml({
    required this.html,
    required this.ebook,
    required this.prefs,
    required this.bookId,
    required this.chapterIndex,
    required this.blockIndex,
    this.bookmarked = false,
    this.highlights = const [],
  });

  final String html;
  final Ebook ebook;
  final ReadingPreferences prefs;
  final String? bookId;
  final int chapterIndex;
  final int blockIndex;
  final bool bookmarked;
  final List<Highlight> highlights;

  @override
  ConsumerState<_BlockHtml> createState() => _BlockHtmlState();
}

class _BlockHtmlState extends ConsumerState<_BlockHtml> {
  String? _lastSelected;

  @override
  Widget build(BuildContext context) {
    final html = widget.html;
    final ebook = widget.ebook;
    final prefs = widget.prefs;
    final bookId = widget.bookId;
    final bookmarked = widget.bookmarked;
    final highlights = widget.highlights;
    final palette = ref.watch(readerPaletteProvider);
    final family = resolveFontFamily(prefs.font);
    final partials = highlights
        .where((h) => !h.isWholeBlock)
        .toList(growable: false);
    final wholes = highlights
        .where((h) => h.isWholeBlock)
        .toList(growable: false);

    final renderedHtml = partials.isEmpty
        ? html
        : wrapHighlights(
            html,
            partials
                .map(
                  (h) => HighlightRange(
                    start: h.startOffset!,
                    end: h.endOffset!,
                    backgroundArgb: h.color.background,
                    accentArgb: h.color.accent,
                  ),
                )
                .toList(),
          );

    final bodyAlign = _toTextAlign(prefs.textAlign);
    final headingAlign = prefs.centerHeadings ? TextAlign.center : bodyAlign;

    // Fast path: when the block is plain inline markup (the vast majority
    // of paragraphs and headings) skip flutter_html altogether and render
    // a single Text.rich. flutter_html chokes on some real-world EPUBs
    // (Shadow Slave's deeply-nested styled wrappers leave entire chapters
    // blank) and the bypass is also significantly cheaper per build.
    if (partials.isEmpty) {
      final simple = tryBuildSimpleBlock(
        html: html,
        prefs: prefs,
        palette: palette,
        fontFamily: family,
        bodyAlign: bodyAlign,
        headingAlign: headingAlign,
      );
      if (simple != null) {
        Widget body = simple.widget;
        if (wholes.isNotEmpty) {
          final whole = wholes.last;
          body = Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: Color(whole.color.background).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(6),
              border: Border(
                left: BorderSide(color: Color(whole.color.accent), width: 3),
              ),
            ),
            child: body,
          );
        } else if (bookmarked) {
          body = Container(
            padding: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: palette.accent, width: 2)),
            ),
            child: body,
          );
        }
        if (bookId == null) return body;
        return SelectionArea(
          onSelectionChanged: (content) {
            _lastSelected = content?.plainText;
          },
          contextMenuBuilder: (context, state) {
            final selected = _lastSelected ?? '';
            final canHighlight = selected.trim().isNotEmpty;
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: state.contextMenuAnchors,
              buttonItems: [
                if (canHighlight)
                  ContextMenuButtonItem(
                    label: 'Destacar',
                    onPressed: () {
                      state.hideToolbar();
                      _persistHighlight(selected);
                    },
                  ),
                ...state.contextMenuButtonItems,
              ],
            );
          },
          child: body,
        );
      }
    }

    final blockStyle = <String, Style>{
      'body': Style(
        fontFamily: family,
        fontSize: FontSize(prefs.fontSize),
        lineHeight: LineHeight(prefs.lineHeight),
        letterSpacing: prefs.letterSpacing,
        color: palette.textPrimary,
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
        textAlign: bodyAlign,
      ),
      'p': Style(
        margin: Margins.only(bottom: prefs.paragraphSpacing),
        textAlign: bodyAlign,
      ),
      'h1, h2, h3, h4, h5, h6': Style(
        fontFamily: family,
        color: palette.textPrimary,
        textAlign: headingAlign,
      ),
      'mark': Style(
        // Style attribute on each <mark> already paints background/border;
        // make sure flutter_html doesn't overwrite it.
        backgroundColor: const Color(0x00000000),
      ),
    };

    final htmlWidget = Html(
      data: renderedHtml,
      extensions: [
        TagExtension(
          tagsToExtend: const {'img'},
          builder: (ctx) {
            final src = ctx.attributes['src'];
            if (src == null || src.isEmpty) return const SizedBox.shrink();
            return _AsyncEpubImage(ebook: ebook, src: src);
          },
        ),
      ],
      style: blockStyle,
    );

    Widget content = htmlWidget;
    if (wholes.isNotEmpty) {
      final whole = wholes.last;
      content = Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Color(whole.color.background).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: Color(whole.color.accent), width: 3),
          ),
        ),
        child: htmlWidget,
      );
    } else if (bookmarked) {
      content = Container(
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: palette.accent, width: 2)),
        ),
        child: htmlWidget,
      );
    }

    if (bookId == null) return content;

    return SelectionArea(
      onSelectionChanged: (content) {
        _lastSelected = content?.plainText;
      },
      contextMenuBuilder: (context, state) {
        final selected = _lastSelected ?? '';
        final canHighlight = selected.trim().isNotEmpty;
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
            if (canHighlight)
              ContextMenuButtonItem(
                label: 'Destacar',
                onPressed: () {
                  state.hideToolbar();
                  _persistHighlight(selected);
                },
              ),
            ...state.contextMenuButtonItems,
          ],
        );
      },
      child: content,
    );
  }

  void _persistHighlight(String selectedText) {
    final id = widget.bookId;
    if (id == null) return;
    final plainText = blockPlainText(widget.html);
    final start = plainText.indexOf(selectedText);
    if (start < 0) return;
    final end = start + selectedText.length;
    final snippet = selectedText.length > 160
        ? '${selectedText.substring(0, 160).trimRight()}…'
        : selectedText;
    ref
        .read(annotationsViewModelProvider.notifier)
        .addHighlight(
          bookId: id,
          chapterIndex: widget.chapterIndex,
          blockIndex: widget.blockIndex,
          snippet: snippet,
          startOffset: start,
          endOffset: end,
        );
  }
}

class _ReaderBottomBar extends ConsumerWidget {
  const _ReaderBottomBar({required this.state, required this.vm});
  final ReaderReading state;
  final ReaderViewModel vm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(readerPaletteProvider);

    final bookId = state.bookId;
    final position = ref.watch(readingPositionProvider);
    final bookmarks = bookId == null
        ? const <Bookmark>[]
        : ref.watch(bookmarksProvider(bookId)).value ?? const <Bookmark>[];

    final activeBlock = position?.chapterIndex == state.chapterIndex
        ? position!.blockIndex
        : null;
    final hasBookmarkOnCurrentBlock =
        activeBlock != null &&
        bookmarks.any(
          (b) =>
              b.chapterIndex == state.chapterIndex &&
              b.blockIndex == activeBlock,
        );

    Future<void> toggleBookmark() async {
      if (bookId == null || activeBlock == null) return;
      final annotations = ref.read(annotationsViewModelProvider.notifier);
      if (hasBookmarkOnCurrentBlock) {
        await annotations.removeBookmarkAt(
          bookId: bookId,
          chapterIndex: state.chapterIndex,
          blockIndex: activeBlock,
        );
      } else {
        final blocks = splitChapterIntoBlocks(state.currentChapter.htmlContent);
        final html = activeBlock < blocks.length ? blocks[activeBlock] : '';
        await annotations.addBookmark(
          bookId: bookId,
          chapterIndex: state.chapterIndex,
          blockIndex: activeBlock,
          blockAlignment: position?.alignment ?? 0,
          snippet: blockSnippet(html),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: Color(0xFFEDE7DD))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 3,
                backgroundColor: const Color(0xFFEDE7DD),
                valueColor: AlwaysStoppedAnimation(palette.accent),
              ),
            ),
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: state.hasPrevious ? vm.previousChapter : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Anterior'),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: bookId == null || activeBlock == null
                        ? null
                        : toggleBookmark,
                    tooltip: hasBookmarkOnCurrentBlock
                        ? 'Remover marcador'
                        : 'Marcar esta posição',
                    icon: Icon(
                      hasBookmarkOnCurrentBlock
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      color: hasBookmarkOnCurrentBlock
                          ? palette.accent
                          : palette.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: state.hasNext ? vm.nextChapter : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('Próximo'),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.textPrimary,
                      ),
                    ),
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

class _AsyncEpubImage extends StatefulWidget {
  const _AsyncEpubImage({required this.ebook, required this.src});

  final Ebook ebook;
  final String src;

  @override
  State<_AsyncEpubImage> createState() => _AsyncEpubImageState();
}

class _AsyncEpubImageState extends State<_AsyncEpubImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AsyncEpubImage old) {
    super.didUpdateWidget(old);
    if (old.src != widget.src || old.ebook != widget.ebook) {
      _bytes = null;
      _loading = true;
      _missing = false;
      _load();
    }
  }

  Future<void> _load() async {
    final bytes = await widget.ebook.resolveImage(widget.src);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
      _missing = bytes == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(
          height: 80,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    if (_missing || _bytes == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Image.memory(_bytes!, fit: BoxFit.contain, gaplessPlayback: true),
    );
  }
}

TextAlign _toTextAlign(ReadingTextAlign value) {
  switch (value) {
    case ReadingTextAlign.left:
      return TextAlign.left;
    case ReadingTextAlign.center:
      return TextAlign.center;
    case ReadingTextAlign.right:
      return TextAlign.right;
    case ReadingTextAlign.justify:
      return TextAlign.justify;
  }
}

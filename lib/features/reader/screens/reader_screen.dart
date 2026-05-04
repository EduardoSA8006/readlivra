import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/result/app_exceptions.dart';
import '../../../core/theme/app_theme.dart';
import '../../stats/data/reading_session_service.dart';
import '../../stats/providers.dart';
import '../../library/data/models/bookmark.dart';
import '../../library/data/models/highlight.dart';
import '../../library/providers.dart';
import '../data/chapter_blocks.dart';
import '../data/font_resolver.dart';
import '../data/highlight_renderer.dart';
import '../data/models/ebook.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSessionService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(readerViewModelProvider);
      if (s is! ReaderIdle) return;
      final vm = ref.read(readerViewModelProvider.notifier);
      if (widget.path != null) {
        final anchor = widget.initialAnchorBlock == null
            ? null
            : ReaderAnchor(
                blockIndex: widget.initialAnchorBlock!,
                alignment: widget.initialAnchorAlignment ?? 0,
              );
        vm.openEpub(
          widget.path!,
          bookId: widget.bookId,
          initialChapter: widget.initialChapter,
          initialAnchor: anchor,
        );
      } else if (widget.autoPick) {
        vm.pickAndOpenEpub();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerViewModelProvider);
    final vm = ref.read(readerViewModelProvider.notifier);

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
      backgroundColor: AppTheme.background,
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
        backgroundColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          color: AppTheme.textPrimary,
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Cap. ${chapterIndex + 1} de ${ebook.chapterCount}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
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
                icon: const Icon(Icons.format_list_bulleted_rounded,
                    color: AppTheme.textPrimary),
                tooltip: 'Sumário',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          if (readingState != null && readingState.bookId != null)
            IconButton(
              icon: const Icon(Icons.bookmarks_outlined,
                  color: AppTheme.textPrimary),
              tooltip: 'Marcadores e destaques',
              onPressed: () =>
                  showAnnotationsListSheet(context, readingState.bookId!),
            ),
          if (readingState != null)
            IconButton(
              icon: const Icon(Icons.text_fields_rounded,
                  color: AppTheme.textPrimary),
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

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded,
                size: 56, color: AppTheme.textSecondary),
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
                backgroundColor: AppTheme.textPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
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
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFB35454)),
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

  /// Two slots per chapter: index 0 is the chapter title, the rest are blocks.
  final Map<int, List<String>> _blocksCache = {};
  bool _anchorRestored = false;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onItemPositions);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeRestoreAnchor());
  }

  @override
  void didUpdateWidget(covariant _ReadingView old) {
    super.didUpdateWidget(old);
    if (old.state.chapterIndex != widget.state.chapterIndex) {
      _anchorRestored = false;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybeRestoreAnchor());
    }
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onItemPositions);
    super.dispose();
  }

  List<String> _blocksFor(int chapterIndex) {
    final cached = _blocksCache[chapterIndex];
    if (cached != null) return cached;
    final html = widget.state.ebook.chapters[chapterIndex].htmlContent;
    final blocks = splitChapterIntoBlocks(html);
    _blocksCache[chapterIndex] = blocks;
    return blocks;
  }

  void _maybeRestoreAnchor() {
    if (_anchorRestored || !mounted) return;
    final anchor = widget.state.pendingAnchor;
    if (anchor == null) {
      _anchorRestored = true;
      return;
    }
    final blocks = _blocksFor(widget.state.chapterIndex);
    // +1 because index 0 is reserved for the title.
    final target = (anchor.blockIndex + 1).clamp(0, blocks.length);
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
    final logicalIndex = (first.index - 1).clamp(0, 1 << 30);
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
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybeRestoreAnchor());
    }
    final blocks = _blocksFor(widget.state.chapterIndex);
    final prefs = ref.watch(readingPreferencesProvider).value ??
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: blocks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              widget.state.currentChapter.title,
              style: TextStyle(
                fontFamily: resolveFontFamily(prefs.font),
                fontSize: prefs.fontSize + 5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.25,
                letterSpacing: prefs.letterSpacing,
              ),
            ),
          );
        }
        final blockIndex = index - 1;
        return _BlockHtml(
          html: blocks[blockIndex],
          ebook: widget.state.ebook,
          prefs: prefs,
          bookmarked: bookmarkedBlocks.contains(blockIndex),
          highlights: highlightsByBlock[blockIndex] ?? const [],
          bookId: bookId,
          chapterIndex: widget.state.chapterIndex,
          blockIndex: blockIndex,
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
    final family = resolveFontFamily(prefs.font);
    final partials =
        highlights.where((h) => !h.isWholeBlock).toList(growable: false);
    final wholes =
        highlights.where((h) => h.isWholeBlock).toList(growable: false);

    final renderedHtml = partials.isEmpty
        ? html
        : wrapHighlights(
            html,
            partials
                .map((h) => HighlightRange(
                      start: h.startOffset!,
                      end: h.endOffset!,
                      backgroundArgb: h.color.background,
                      accentArgb: h.color.accent,
                    ))
                .toList(),
          );

    final blockStyle = <String, Style>{
      'body': Style(
        fontFamily: family,
        fontSize: FontSize(prefs.fontSize),
        lineHeight: LineHeight(prefs.lineHeight),
        letterSpacing: prefs.letterSpacing,
        color: AppTheme.textPrimary,
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
      ),
      'p': Style(margin: Margins.only(bottom: prefs.paragraphSpacing)),
      'h1, h2, h3': Style(
        fontFamily: family,
        color: AppTheme.textPrimary,
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
            final bytes = ebook.resolveImage(src);
            if (bytes == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Image.memory(bytes, fit: BoxFit.contain),
            );
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
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: AppTheme.accent, width: 2),
          ),
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
    ref.read(annotationsViewModelProvider.notifier).addHighlight(
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
    final bookId = state.bookId;
    final position = ref.watch(readingPositionProvider);
    final bookmarks = bookId == null
        ? const <Bookmark>[]
        : ref.watch(bookmarksProvider(bookId)).value ?? const <Bookmark>[];

    final activeBlock = position?.chapterIndex == state.chapterIndex
        ? position!.blockIndex
        : null;
    final hasBookmarkOnCurrentBlock = activeBlock != null &&
        bookmarks.any((b) =>
            b.chapterIndex == state.chapterIndex &&
            b.blockIndex == activeBlock);

    Future<void> toggleBookmark() async {
      if (bookId == null || activeBlock == null) return;
      final annotations =
          ref.read(annotationsViewModelProvider.notifier);
      if (hasBookmarkOnCurrentBlock) {
        await annotations.removeBookmarkAt(
          bookId: bookId,
          chapterIndex: state.chapterIndex,
          blockIndex: activeBlock,
        );
      } else {
        final blocks = splitChapterIntoBlocks(
            state.currentChapter.htmlContent);
        final html =
            activeBlock < blocks.length ? blocks[activeBlock] : '';
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
      decoration: const BoxDecoration(
        color: AppTheme.surface,
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
                valueColor:
                    const AlwaysStoppedAnimation(AppTheme.accent),
              ),
            ),
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed:
                          state.hasPrevious ? vm.previousChapter : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Anterior'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        bookId == null || activeBlock == null
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
                          ? AppTheme.accent
                          : AppTheme.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: state.hasNext ? vm.nextChapter : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('Próximo'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
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

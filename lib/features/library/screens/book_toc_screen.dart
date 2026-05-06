import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../reader/data/models/ebook.dart';
import '../../reader/screens/reader_screen.dart';
import '../providers.dart';

class BookTocScreen extends ConsumerStatefulWidget {
  const BookTocScreen({
    super.key,
    required this.bookId,
    required this.filePath,
    required this.bookTitle,
    required this.author,
    required this.ebook,
    required this.currentChapter,
  });

  final String bookId;
  final String filePath;
  final String bookTitle;
  final String? author;
  final Ebook ebook;
  final int currentChapter;

  @override
  ConsumerState<BookTocScreen> createState() => _BookTocScreenState();
}

class _BookTocScreenState extends ConsumerState<BookTocScreen> {
  final _scrollController = ItemScrollController();
  final _positionsListener = ItemPositionsListener.create();
  final _searchController = TextEditingController();
  bool _searchVisible = false;
  String _query = '';
  bool _currentVisible = true;

  late final int _initial = widget.currentChapter
      .clamp(0, widget.ebook.chapterCount - 1)
      .toInt();

  @override
  void initState() {
    super.initState();
    _positionsListener.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void dispose() {
    _positionsListener.itemPositions.removeListener(_onPositionsChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onPositionsChanged() {
    if (_query.isNotEmpty) return;
    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final visible = positions.any(
      (p) =>
          p.index == widget.currentChapter &&
          p.itemTrailingEdge > 0 &&
          p.itemLeadingEdge < 1,
    );
    if (visible != _currentVisible) {
      setState(() => _currentVisible = visible);
    }
  }

  Future<void> _openChapter(int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          bookId: widget.bookId,
          path: widget.filePath,
          initialChapter: index,
        ),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchController.clear();
        _query = '';
      }
    });
  }

  void _scrollToCurrent() {
    _scrollController.scrollTo(
      index: widget.currentChapter,
      alignment: 0.1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bookmarks = ref.watch(bookmarksProvider(widget.bookId)).value ?? const [];
    final highlights =
        ref.watch(highlightsProvider(widget.bookId)).value ?? const [];

    final annotationsByChapter = <int, int>{};
    for (final b in bookmarks) {
      annotationsByChapter[b.chapterIndex] =
          (annotationsByChapter[b.chapterIndex] ?? 0) + 1;
    }
    for (final h in highlights) {
      annotationsByChapter[h.chapterIndex] =
          (annotationsByChapter[h.chapterIndex] ?? 0) + 1;
    }

    final total = widget.ebook.chapterCount;
    final read = widget.currentChapter.clamp(0, total).toInt();
    final progress = total == 0 ? 0.0 : read / total;

    final filteredIndexes = <int>[];
    final lowerQuery = _query.trim().toLowerCase();
    for (var i = 0; i < total; i++) {
      if (lowerQuery.isEmpty ||
          widget.ebook.chapters[i].title.toLowerCase().contains(lowerQuery)) {
        filteredIndexes.add(i);
      }
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Sumário',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: _searchVisible ? 'Fechar busca' : 'Buscar capítulo',
            icon: Icon(
              _searchVisible ? Icons.close_rounded : Icons.search_rounded,
              color: scheme.onSurface,
            ),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      floatingActionButton: (!_currentVisible && _query.isEmpty && total > 0)
          ? FloatingActionButton.small(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              elevation: 2,
              onPressed: _scrollToCurrent,
              child: const Icon(Icons.my_location_rounded),
            )
          : null,
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              title: widget.bookTitle,
              author: widget.author,
              read: read,
              total: total,
              progress: progress,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _searchVisible
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _SearchField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Divider(height: 1, color: scheme.outline.withValues(alpha: 0.5)),
            Expanded(
              child: filteredIndexes.isEmpty
                  ? _EmptyState(query: _query)
                  : (_query.isEmpty
                        ? ScrollablePositionedList.builder(
                            itemScrollController: _scrollController,
                            itemPositionsListener: _positionsListener,
                            initialScrollIndex: _initial,
                            initialAlignment: 0.1,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: total,
                            itemBuilder: (context, i) => _ChapterTile(
                              index: i,
                              title: widget.ebook.chapters[i].title,
                              status: _statusFor(i),
                              annotations: annotationsByChapter[i] ?? 0,
                              onTap: () => _openChapter(i),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: filteredIndexes.length,
                            itemBuilder: (context, i) {
                              final idx = filteredIndexes[i];
                              return _ChapterTile(
                                index: idx,
                                title: widget.ebook.chapters[idx].title,
                                status: _statusFor(idx),
                                annotations: annotationsByChapter[idx] ?? 0,
                                onTap: () => _openChapter(idx),
                              );
                            },
                          )),
            ),
          ],
        ),
      ),
    );
  }

  _ChapterStatus _statusFor(int index) {
    if (index < widget.currentChapter) return _ChapterStatus.read;
    if (index == widget.currentChapter) return _ChapterStatus.current;
    return _ChapterStatus.unread;
  }
}

enum _ChapterStatus { read, current, unread }

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.author,
    required this.read,
    required this.total,
    required this.progress,
  });

  final String title;
  final String? author;
  final int read;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = (total - read).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
          if (author != null) ...[
            const SizedBox(height: 2),
            Text(
              author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: scheme.outline.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation(scheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CounterChip(
                label: 'lidos',
                value: '$read',
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              _CounterChip(
                label: 'restantes',
                value: '$remaining',
                color: scheme.onSurfaceVariant,
              ),
              const Spacer(),
              Text(
                '$total ${total == 1 ? "capítulo" : "capítulos"}',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      autofocus: true,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: scheme.onSurface),
      decoration: InputDecoration(
        hintText: 'Buscar capítulo',
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: scheme.onSurfaceVariant,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.index,
    required this.title,
    required this.status,
    required this.annotations,
    required this.onTap,
  });

  final int index;
  final String title;
  final _ChapterStatus status;
  final int annotations;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrent = status == _ChapterStatus.current;
    final isRead = status == _ChapterStatus.read;
    final accentBg = isCurrent
        ? scheme.primary.withValues(alpha: 0.06)
        : Colors.transparent;
    final numberColor = isCurrent
        ? scheme.primary
        : isRead
            ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
            : scheme.onSurfaceVariant;
    final titleColor = isRead
        ? scheme.onSurface.withValues(alpha: 0.55)
        : scheme.onSurface;
    final titleWeight = isCurrent ? FontWeight.w700 : FontWeight.w500;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: accentBg,
          border: Border(
            left: BorderSide(
              color: isCurrent ? scheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              child: _StatusGlyph(
                status: status,
                index: index,
                color: numberColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 14,
                      color: titleColor,
                      fontWeight: titleWeight,
                      height: 1.3,
                      letterSpacing: -0.1,
                      decoration: isRead ? TextDecoration.lineThrough : null,
                      decorationColor:
                          scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      decorationThickness: 1,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(height: 2),
                    Text(
                      'lendo agora',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (annotations > 0) ...[
              const SizedBox(width: 8),
              _AnnotationBadge(count: annotations),
            ],
            const SizedBox(width: 6),
            Icon(
              isCurrent ? Icons.play_arrow_rounded : Icons.chevron_right_rounded,
              size: 18,
              color: isCurrent
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({
    required this.status,
    required this.index,
    required this.color,
  });

  final _ChapterStatus status;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _ChapterStatus.read:
        return Icon(Icons.check_rounded, size: 18, color: color);
      case _ChapterStatus.current:
        return Icon(Icons.bookmark_rounded, size: 18, color: color);
      case _ChapterStatus.unread:
        return Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.2,
          ),
        );
    }
  }
}

class _AnnotationBadge extends StatelessWidget {
  const _AnnotationBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_rounded, size: 11, color: scheme.secondary),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: scheme.secondary,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhum capítulo encontrado',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'para "$query"',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

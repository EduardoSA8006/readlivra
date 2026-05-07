import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/bookmark.dart';
import '../../../core/models/highlight.dart';
import '../../library/providers.dart';
import '../providers.dart';
import '../viewmodels/reader_state.dart';

Future<void> showAnnotationsListSheet(BuildContext context, String bookId) {
  final palette =
      ProviderScope.containerOf(context).read(readerPaletteProvider);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: palette.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scroll) =>
          _AnnotationsListSheet(bookId: bookId, controller: scroll),
    ),
  );
}

class _AnnotationsListSheet extends ConsumerWidget{
  const _AnnotationsListSheet({
    required this.bookId,
    required this.controller,
  });

  final String bookId;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(readerPaletteProvider);

    final bookmarksAsync = ref.watch(bookmarksProvider(bookId));
    final highlightsAsync = ref.watch(highlightsProvider(bookId));
    final readerState = ref.watch(readerViewModelProvider);
    final readerVm = ref.read(readerViewModelProvider.notifier);
    final annotationsVm = ref.read(annotationsViewModelProvider.notifier);

    final ebook =
        readerState is ReaderReading ? readerState.ebook : null;

    final bookmarks = bookmarksAsync.value ?? const <Bookmark>[];
    final highlights = highlightsAsync.value ?? const <Highlight>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Marcadores e destaques',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: (bookmarks.isEmpty && highlights.isEmpty)
                ? const _EmptyState()
                : ListView(
                    controller: controller,
                    padding: EdgeInsets.zero,
                    children: [
                      if (bookmarks.isNotEmpty) ...[
                        const _SectionLabel('Marcadores'),
                        const SizedBox(height: 8),
                        ...bookmarks.map(
                          (b) => _BookmarkRow(
                            bookmark: b,
                            chapterTitle: ebook == null
                                ? null
                                : ebook.chapters[b.chapterIndex].title,
                            onTap: () {
                              Navigator.of(context).pop();
                              readerVm.jumpToAnchor(
                                chapterIndex: b.chapterIndex,
                                blockIndex: b.blockIndex,
                                blockAlignment: b.blockAlignment,
                              );
                            },
                            onEditNote: () async {
                              final note = await _editNoteDialog(
                                  context, b.note);
                              if (note == null) return;
                              await annotationsVm.updateBookmarkNote(
                                bookId,
                                b.id,
                                note.isEmpty ? null : note,
                              );
                            },
                            onRemove: () => annotationsVm.removeBookmark(
                                bookId, b.id),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (highlights.isNotEmpty) ...[
                        const _SectionLabel('Destaques'),
                        const SizedBox(height: 8),
                        ...highlights.map(
                          (h) => _HighlightRow(
                            highlight: h,
                            chapterTitle: ebook == null
                                ? null
                                : ebook.chapters[h.chapterIndex].title,
                            onTap: () {
                              Navigator.of(context).pop();
                              readerVm.jumpToAnchor(
                                chapterIndex: h.chapterIndex,
                                blockIndex: h.blockIndex,
                                blockAlignment: 0,
                              );
                            },
                            onRemove: () => annotationsVm.removeHighlight(
                                bookId, h.id),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends ConsumerWidget{
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(readerPaletteProvider);

    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        color: palette.textSecondary,
        letterSpacing: 1.0,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _BookmarkRow extends ConsumerWidget{
  const _BookmarkRow({
    required this.bookmark,
    required this.chapterTitle,
    required this.onTap,
    required this.onEditNote,
    required this.onRemove,
  });

  final Bookmark bookmark;
  final String? chapterTitle;
  final VoidCallback onTap;
  final VoidCallback onEditNote;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(readerPaletteProvider);

    return _AnnotationRowShell(
      leading: Icon(Icons.bookmark_rounded,
          size: 18, color: palette.accent),
      chapterTitle: chapterTitle ?? 'Capítulo ${bookmark.chapterIndex + 1}',
      snippet: bookmark.snippet,
      footer: bookmark.note,
      trailing: IconButton(
        onPressed: onEditNote,
        icon: const Icon(Icons.edit_note_rounded, size: 20),
        color: palette.textSecondary,
        visualDensity: VisualDensity.compact,
        tooltip: bookmark.note == null ? 'Adicionar nota' : 'Editar nota',
      ),
      onTap: onTap,
      onRemove: onRemove,
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.highlight,
    required this.chapterTitle,
    required this.onTap,
    required this.onRemove,
  });

  final Highlight highlight;
  final String? chapterTitle;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return _AnnotationRowShell(
      leading: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Color(highlight.color.background),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      chapterTitle:
          chapterTitle ?? 'Capítulo ${highlight.chapterIndex + 1}',
      snippet: highlight.snippet,
      onTap: onTap,
      onRemove: onRemove,
    );
  }
}

class _AnnotationRowShell extends ConsumerWidget{
  const _AnnotationRowShell({
    required this.leading,
    required this.chapterTitle,
    required this.snippet,
    required this.onTap,
    required this.onRemove,
    this.footer,
    this.trailing,
  });

  final Widget leading;
  final String chapterTitle;
  final String snippet;
  final String? footer;
  final Widget? trailing;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(readerPaletteProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDE7DD)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 22, child: Center(child: leading)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chapterTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        snippet,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      if (footer != null && footer!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            footer!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.textSecondary,
                              fontStyle: FontStyle.italic,
                              height: 1.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: palette.textSecondary,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> _editNoteDialog(
    BuildContext context, String? initial) async {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nota do marcador'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        minLines: 2,
        decoration: const InputDecoration(
          hintText: 'O que você gostaria de lembrar?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

class _EmptyState extends ConsumerWidget{
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(readerPaletteProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline_rounded,
                size: 40, color: palette.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Pressione um parágrafo para criar um marcador ou destaque.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../reader/screens/reader_screen.dart';
import '../data/models/book_entry.dart';
import '../data/models/bookmark.dart';
import '../data/models/highlight.dart';
import '../providers.dart';
import '../viewmodels/book_detail_state.dart';
import 'book_toc_screen.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(bookDetailViewModelProvider(bookId));

    return Scaffold(
      backgroundColor: scheme.surface,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(bookDetailViewModelProvider(bookId)),
        ),
        data: (data) => _DetailContent(data: data, bookId: bookId),
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.data, required this.bookId});

  final BookDetailData data;
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final vm = ref.read(bookDetailViewModelProvider(bookId).notifier);

    Future<void> openReader({
      int? chapter,
      int? anchorBlock,
      double? anchorAlignment,
    }) async {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReaderScreen(
            bookId: data.book.id,
            path: data.book.filePath,
            initialChapter: chapter,
            initialAnchorBlock: anchorBlock,
            initialAnchorAlignment: anchorAlignment,
          ),
        ),
      );
      ref.invalidate(bookDetailViewModelProvider(bookId));
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          pinned: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            _OverflowMenu(
              data: data,
              onResetProgress: () => _confirmAndRun(
                context,
                title: 'Resetar progresso?',
                message: 'O progresso de leitura voltará ao início.',
                confirmLabel: 'Resetar',
                run: vm.resetProgress,
              ),
              onRemove: () =>
                  _confirmRemove(context, data.book.title, vm.remove),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverList.list(
            children: [
              _Hero(book: data.book),
              const SizedBox(height: 28),
              _StatsStrip(data: data),
              const SizedBox(height: 24),
              _PrimaryAction(data: data, onTap: () => openReader()),
              const SizedBox(height: 28),
              _ProgressLine(data: data),
              const SizedBox(height: 32),
              _AnnotationsPreview(
                bookId: bookId,
                ebookChapterTitleAt: (i) =>
                    i >= 0 && i < data.ebook.chapterCount
                    ? data.ebook.chapters[i].title
                    : 'Capítulo ${i + 1}',
                onJump:
                    ({required chapter, required block, required alignment}) =>
                        openReader(
                          chapter: chapter,
                          anchorBlock: block,
                          anchorAlignment: alignment,
                        ),
              ),
              _TocLink(
                data: data,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookTocScreen(
                      bookId: data.book.id,
                      filePath: data.book.filePath,
                      bookTitle: data.book.title,
                      author: data.book.author,
                      ebook: data.ebook,
                      currentChapter: data.currentChapter,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndRun(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() run,
  }) async {
    final ok = await _confirm(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    );
    if (ok) await run();
  }

  Future<void> _confirmRemove(
    BuildContext context,
    String title,
    Future<bool> Function() remove,
  ) async {
    final ok = await _confirm(
      context,
      title: 'Remover livro?',
      message:
          '"$title" será removido da biblioteca, junto com seu histórico de leitura.',
      confirmLabel: 'Remover',
    );
    if (!ok) return;
    await remove();
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.book});
  final BookEntry book;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(width: 180, height: 260, child: _Cover(book: book)),
        const SizedBox(height: 24),
        Text(
          book.title,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            height: 1.2,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          book.author ?? 'Autor desconhecido',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.book});
  final BookEntry book;

  @override
  Widget build(BuildContext context) {
    final fallback = _colorForTitle(book.title);
    final decoration = BoxDecoration(
      color: fallback,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 32,
          spreadRadius: -4,
          offset: const Offset(0, 16),
        ),
      ],
    );
    if (book.coverPath == null) {
      return _FallbackCover(decoration: decoration, title: book.title);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: decoration,
        child: Image.file(
          File(book.coverPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _FallbackCover(decoration: decoration, title: book.title),
        ),
      ),
    );
  }
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover({required this.decoration, required this.title});
  final Decoration decoration;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: decoration,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            title,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.data});
  final BookDetailData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progressPct = (data.chapterProgress * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              value: '$progressPct%',
              label: 'concluído',
              accent: scheme.primary,
            ),
          ),
          _Divider(scheme: scheme),
          Expanded(
            child: _StatCell(
              value: '${data.chapterCount}',
              label: data.chapterCount == 1 ? 'capítulo' : 'capítulos',
              accent: scheme.onSurface,
            ),
          ),
          _Divider(scheme: scheme),
          Expanded(
            child: _StatCell(
              value: _formatDurationCompact(data.totalReadingTime),
              label: 'tempo lido',
              accent: scheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: scheme.outline);
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.accent,
  });
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.data, required this.onTap});
  final BookDetailData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasProgress =
        data.currentChapter > 0 ||
        data.progress.blockIndex > 0 ||
        data.progress.blockAlignment > 0;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        icon: Icon(
          hasProgress ? Icons.play_arrow_rounded : Icons.menu_book_rounded,
          size: 22,
        ),
        label: Text(hasProgress ? 'Continuar lendo' : 'Começar a ler'),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.data});
  final BookDetailData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Capítulo ${data.currentChapter + 1} de ${data.chapterCount}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const Spacer(),
            if (data.lastReadAt != null)
              Text(
                'última leitura ${_formatRelativeDate(data.lastReadAt!)}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: data.chapterProgress,
            minHeight: 6,
            backgroundColor: scheme.outline.withValues(alpha: 0.6),
            valueColor: AlwaysStoppedAnimation(scheme.primary),
          ),
        ),
      ],
    );
  }
}

typedef _JumpHandler =
    void Function({
      required int chapter,
      required int block,
      required double alignment,
    });

class _AnnotationsPreview extends ConsumerWidget {
  const _AnnotationsPreview({
    required this.bookId,
    required this.ebookChapterTitleAt,
    required this.onJump,
  });

  final String bookId;
  final String Function(int) ebookChapterTitleAt;
  final _JumpHandler onJump;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final bookmarks =
        ref.watch(bookmarksProvider(bookId)).value ?? const <Bookmark>[];
    final highlights =
        ref.watch(highlightsProvider(bookId)).value ?? const <Highlight>[];

    if (bookmarks.isEmpty && highlights.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalCount = bookmarks.length + highlights.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionLabel('Marcadores'),
              const Spacer(),
              Text(
                '$totalCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...bookmarks
              .take(2)
              .map(
                (b) => _AnnotationLine(
                  icon: Icons.bookmark_rounded,
                  iconColor: AppPalette.secondary,
                  chapter: ebookChapterTitleAt(b.chapterIndex),
                  snippet: b.snippet,
                  note: b.note,
                  onTap: () => onJump(
                    chapter: b.chapterIndex,
                    block: b.blockIndex,
                    alignment: b.blockAlignment,
                  ),
                ),
              ),
          ...highlights
              .take(2)
              .map(
                (h) => _AnnotationLine(
                  icon: Icons.format_color_fill_rounded,
                  iconColor: Color(h.color.background),
                  chapter: ebookChapterTitleAt(h.chapterIndex),
                  snippet: h.snippet,
                  onTap: () => onJump(
                    chapter: h.chapterIndex,
                    block: h.blockIndex,
                    alignment: 0,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _AnnotationLine extends StatelessWidget {
  const _AnnotationLine({
    required this.icon,
    required this.iconColor,
    required this.chapter,
    required this.snippet,
    required this.onTap,
    this.note,
  });
  final IconData icon;
  final Color iconColor;
  final String chapter;
  final String snippet;
  final String? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chapter,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                  if (note != null && note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: scheme.onSurfaceVariant,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _TocLink extends StatelessWidget {
  const _TocLink({required this.data, required this.onTap});

  final BookDetailData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = data.ebook.chapterCount;
    final current = data.currentChapter + 1;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.format_list_bulleted_rounded,
                size: 20,
                color: scheme.onSurface,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sumário',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0
                          ? 'Sem capítulos'
                          : 'Capítulo $current de $count',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.data,
    required this.onResetProgress,
    required this.onRemove,
  });

  final BookDetailData data;
  final VoidCallback onResetProgress;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<_MenuAction>(
      tooltip: 'Mais opções',
      icon: Icon(Icons.more_vert_rounded, color: scheme.onSurface),
      position: PopupMenuPosition.under,
      onSelected: (value) {
        switch (value) {
          case _MenuAction.details:
            _openDetails(context);
          case _MenuAction.reset:
            onResetProgress();
          case _MenuAction.remove:
            onRemove();
        }
      },
      itemBuilder: (_) => [
        _menuItem(
          _MenuAction.details,
          Icons.info_outline_rounded,
          'Detalhes do arquivo',
          scheme.onSurface,
        ),
        _menuItem(
          _MenuAction.reset,
          Icons.restart_alt_rounded,
          'Resetar progresso',
          scheme.onSurface,
        ),
        _menuItem(
          _MenuAction.remove,
          Icons.delete_outline_rounded,
          'Remover livro',
          AppPalette.danger,
        ),
      ],
    );
  }

  PopupMenuItem<_MenuAction> _menuItem(
    _MenuAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<_MenuAction>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  void _openDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DetailsSheet(data: data),
    );
  }
}

enum _MenuAction { details, reset, remove }

class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({required this.data});
  final BookDetailData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalhes do arquivo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _DetailRow(
              label: 'Adicionado em',
              value: _formatDate(data.book.dateAdded),
            ),
            _DetailRow(label: 'Capítulos', value: '${data.chapterCount}'),
            _DetailRow(
              label: 'Imagens embutidas',
              value: '${data.ebook.imageCount}',
            ),
            if (data.fileSizeBytes != null)
              _DetailRow(
                label: 'Tamanho do arquivo',
                value: _formatBytes(data.fileSizeBytes!),
              ),
            _DetailRow(
              label: 'Identificador',
              value: data.book.id,
              monospace: true,
            ),
            _DetailRow(
              label: 'Caminho',
              value: data.book.filePath,
              monospace: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });
  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              softWrap: true,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface,
                fontFamily: monospace ? 'monospace' : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

Color _colorForTitle(String title) {
  const palette = [
    Color(0xFFE0723A),
    Color(0xFF1F2D4A),
    Color(0xFF2F5D3A),
    Color(0xFF7A2E2E),
    Color(0xFF3B2E5A),
    Color(0xFFB36A1A),
    Color(0xFF2C6E8F),
    Color(0xFF4A2222),
    Color(0xFF5A3D7A),
  ];
  return palette[title.hashCode.abs() % palette.length];
}

String _formatDate(DateTime d) {
  final local = d.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _formatRelativeDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dDay = DateTime(d.year, d.month, d.day);
  final diff = today.difference(dDay).inDays;
  if (diff == 0) return 'hoje';
  if (diff == 1) return 'ontem';
  if (diff < 7) return 'há $diff dias';
  return _formatDate(d);
}

String _formatBytes(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
  return '$bytes B';
}

String _formatDurationCompact(Duration d) {
  if (d.inMinutes < 1) return '0m';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h${m}m';
}

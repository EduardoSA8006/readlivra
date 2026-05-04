import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../reader/screens/reader_screen.dart';
import '../../stats/screens/stats_screen.dart' show formatDuration;
import '../data/models/book_entry.dart';
import '../data/models/bookmark.dart';
import '../data/models/highlight.dart';
import '../providers.dart';
import '../viewmodels/book_detail_state.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookDetailViewModelProvider(bookId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Detalhes',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(bookDetailViewModelProvider(bookId)),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _CoverHero(book: data.book),
        const SizedBox(height: 16),
        Text(
          data.book.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.book.author ?? 'Autor desconhecido',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 18),
        _ContinueButton(data: data, onTap: () => openReader()),
        const SizedBox(height: 18),
        _StatsRow(data: data),
        const SizedBox(height: 18),
        _ProgressBar(data: data),
        const SizedBox(height: 24),
        _AnnotationsSection(
          bookId: bookId,
          data: data,
          onJump: ({required chapter, required block, required alignment}) =>
              openReader(
            chapter: chapter,
            anchorBlock: block,
            anchorAlignment: alignment,
          ),
        ),
        _DetailsExpansion(data: data),
        const SizedBox(height: 16),
        Text('Capítulos',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...List.generate(
          data.ebook.chapterCount,
          (i) => _ChapterRow(
            index: i,
            title: data.ebook.chapters[i].title,
            isCurrent: i == data.currentChapter,
            onTap: () => openReader(chapter: i),
          ),
        ),
        const SizedBox(height: 24),
        _DangerActions(
          onResetProgress: () async {
            final ok = await _confirm(
              context,
              title: 'Resetar progresso?',
              message:
                  'O progresso de leitura deste livro voltará ao início.',
              confirmLabel: 'Resetar',
            );
            if (ok) await vm.resetProgress();
          },
          onRemove: () async {
            final ok = await _confirm(
              context,
              title: 'Remover livro?',
              message:
                  '"${data.book.title}" será removido da biblioteca, junto com seu histórico de leitura.',
              confirmLabel: 'Remover',
            );
            if (!ok) return;
            await vm.remove();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    );
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

class _CoverHero extends StatelessWidget {
  const _CoverHero({required this.book});
  final BookEntry book;

  @override
  Widget build(BuildContext context) {
    final fallback = _colorForTitle(book.title);
    final decoration = BoxDecoration(
      color: fallback,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
    final cover = book.coverPath == null
        ? _FallbackCover(decoration: decoration, title: book.title)
        : ClipRRect(
            borderRadius: BorderRadius.circular(14),
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

    return Center(
      child: SizedBox(
        width: 180,
        height: 260,
        child: cover,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          title,
          maxLines: 6,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.data, required this.onTap});
  final BookDetailData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasProgress = data.currentChapter > 0 ||
        data.progress.blockIndex > 0 ||
        data.progress.blockAlignment > 0;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.textPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.menu_book_rounded),
        label: Text(
          hasProgress ? 'Continuar lendo' : 'Começar a ler',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});
  final BookDetailData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Tempo total',
            value: formatDuration(data.totalReadingTime),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Hoje',
            value: formatDuration(data.todayReadingTime),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Última leitura',
            value: data.lastReadAt == null
                ? '—'
                : _formatRelativeDate(data.lastReadAt!),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE7DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.data});
  final BookDetailData data;

  @override
  Widget build(BuildContext context) {
    final pct = (data.chapterProgress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Capítulo ${data.currentChapter + 1} de ${data.chapterCount}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              '$pct%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: data.chapterProgress,
            minHeight: 5,
            backgroundColor: const Color(0xFFEDE7DD),
            valueColor:
                const AlwaysStoppedAnimation(AppTheme.accent),
          ),
        ),
      ],
    );
  }
}

typedef _JumpHandler = void Function({
  required int chapter,
  required int block,
  required double alignment,
});

class _AnnotationsSection extends ConsumerWidget {
  const _AnnotationsSection({
    required this.bookId,
    required this.data,
    required this.onJump,
  });

  final String bookId;
  final BookDetailData data;
  final _JumpHandler onJump;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks =
        ref.watch(bookmarksProvider(bookId)).value ?? const <Bookmark>[];
    final highlights =
        ref.watch(highlightsProvider(bookId)).value ?? const <Highlight>[];
    if (bookmarks.isEmpty && highlights.isEmpty) {
      return const SizedBox.shrink();
    }

    String chapterTitle(int i) =>
        i >= 0 && i < data.ebook.chapterCount
            ? data.ebook.chapters[i].title
            : 'Capítulo ${i + 1}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Marcadores e destaques',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (bookmarks.isNotEmpty) ...[
          ...bookmarks.take(6).map(
                (b) => _MiniRow(
                  leading: const Icon(Icons.bookmark_rounded,
                      size: 16, color: AppTheme.accent),
                  chapterTitle: chapterTitle(b.chapterIndex),
                  snippet: b.snippet,
                  note: b.note,
                  onTap: () => onJump(
                    chapter: b.chapterIndex,
                    block: b.blockIndex,
                    alignment: b.blockAlignment,
                  ),
                ),
              ),
          if (bookmarks.length > 6)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '+ ${bookmarks.length - 6} marcadores',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
        if (highlights.isNotEmpty) ...[
          if (bookmarks.isNotEmpty) const SizedBox(height: 4),
          ...highlights.take(6).map(
                (h) => _MiniRow(
                  leading: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Color(h.color.background),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  chapterTitle: chapterTitle(h.chapterIndex),
                  snippet: h.snippet,
                  onTap: () => onJump(
                    chapter: h.chapterIndex,
                    block: h.blockIndex,
                    alignment: 0,
                  ),
                ),
              ),
          if (highlights.length > 6)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '+ ${highlights.length - 6} destaques',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({
    required this.leading,
    required this.chapterTitle,
    required this.snippet,
    required this.onTap,
    this.note,
  });

  final Widget leading;
  final String chapterTitle;
  final String snippet;
  final String? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEDE7DD)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 18, child: Center(child: leading)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapterTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      if (note != null && note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            note!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsExpansion extends StatelessWidget {
  const _DetailsExpansion({required this.data});
  final BookDetailData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE7DD)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          listTileTheme: const ListTileThemeData(
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: const Text(
            'Detalhes do arquivo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          children: [
            _DetailRow(
              label: 'Adicionado em',
              value: _formatDate(data.book.dateAdded),
            ),
            _DetailRow(
              label: 'Capítulos',
              value: '${data.chapterCount}',
            ),
            _DetailRow(
              label: 'Imagens embutidas',
              value: '${data.ebook.images.length}',
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.textPrimary,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.index,
    required this.title,
    required this.isCurrent,
    required this.onTap,
  });

  final int index;
  final String title;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: const Color(0xFFEDE7DD).withValues(alpha: 0.6)),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isCurrent
                        ? AppTheme.accent
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    fontWeight:
                        isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isCurrent)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.bookmark_rounded,
                      size: 16, color: AppTheme.accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerActions extends StatelessWidget {
  const _DangerActions({
    required this.onResetProgress,
    required this.onRemove,
  });

  final VoidCallback onResetProgress;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: onResetProgress,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Resetar progresso'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Remover livro da biblioteca'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFB35454),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ],
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
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFB35454)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
                onPressed: onRetry, child: const Text('Tentar de novo')),
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

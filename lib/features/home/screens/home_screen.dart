import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/models/book_entry.dart';
import '../../../core/theme/app_palette.dart';
import '../../library/providers.dart';
import '../../library/viewmodels/library_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _ContinueReadingSection(),
            SizedBox(height: 28),
            _QuickActions(),
            SizedBox(height: 28),
            _RecentlyReadSection(),
            _RecentSection(),
          ],
        ),
      ),
    );
  }
}

class _ContinueReadingSection extends ConsumerWidget {
  const _ContinueReadingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(continueReadingProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: async.when(
        loading: () => const _ContinuePlaceholder(message: 'Carregando…'),
        error: (_, _) => const _ContinuePlaceholder(
          message: 'Não foi possível carregar o último livro.',
        ),
        data: (info) {
          if (info == null) return const _ContinueEmpty();
          return _ContinueReadingCard(info: info);
        },
      ),
    );
  }
}

class _ContinueEmpty extends StatelessWidget {
  const _ContinueEmpty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 32,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nenhum livro aberto ainda',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Toque em "Importar" para começar.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinuePlaceholder extends StatelessWidget {
  const _ContinuePlaceholder({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({required this.info});
  final ContinueReadingInfo info;

  @override
  Widget build(BuildContext context) {
    final book = info.book;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        AppRoutes.reader(bookId: book.id, path: book.filePath),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppPalette.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            _SmallCover(entry: book, width: 84, height: 120),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTINUE LENDO',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontSize: 10.5,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author ?? 'Autor desconhecido',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: info.progress,
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(
                        AppPalette.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(info.progress * 100).round()}% concluído',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryViewModelProvider);
    final importing = libraryAsync.maybeWhen(
      data: (s) => s is LibraryLoaded && s.importing,
      orElse: () => false,
    );

    Future<void> handleImport() async {
      final entry = await ref
          .read(libraryViewModelProvider.notifier)
          .pickAndImportEpub();
      if (entry == null || !context.mounted) return;
      await Navigator.of(context).push(
        AppRoutes.reader(bookId: entry.id, path: entry.filePath),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.file_upload_outlined,
              label: importing ? 'Importando…' : 'Importar',
              onTap: importing ? null : handleImport,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: _QuickAction(icon: Icons.cloud_outlined, label: 'Nuvem'),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: _QuickAction(
              icon: Icons.bookmark_outline_rounded,
              label: 'Marcadores',
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline),
          ),
          child: Column(
            children: [
              Icon(icon, color: scheme.onSurface, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentlyReadSection extends ConsumerWidget {
  const _RecentlyReadSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentlyReadProvider);
    final books = async.value ?? const <BookEntry>[];
    if (books.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: _BookRow(title: 'Últimas leituras', books: books.take(8).toList()),
    );
  }
}

class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(libraryViewModelProvider);
    return async.maybeWhen(
      data: (state) {
        if (state is! LibraryLoaded || state.books.isEmpty) {
          return const SizedBox.shrink();
        }
        final books = state.books.take(8).toList();
        return _BookRow(title: 'Adicionados recentemente', books: books);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({required this.title, required this.books});
  final String title;
  final List<BookEntry> books;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final book = books[i];
              return GestureDetector(
                onTap: () => Navigator.of(context)
                    .push(AppRoutes.bookDetail(bookId: book.id)),
                child: _SmallCover(entry: book, width: 110, height: 160),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SmallCover extends StatelessWidget {
  const _SmallCover({
    required this.entry,
    required this.width,
    required this.height,
  });
  final BookEntry entry;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fallback = _colorForTitle(entry.title);
    final decoration = BoxDecoration(
      color: fallback,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );

    if (entry.coverPath == null) {
      return _FallbackCover(
        decoration: decoration,
        title: entry.title,
        width: width,
        height: height,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        height: height,
        decoration: decoration,
        child: Image.file(
          File(entry.coverPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _FallbackCover(
            decoration: decoration,
            title: entry.title,
            width: width,
            height: height,
          ),
        ),
      ),
    );
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
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover({
    required this.decoration,
    required this.title,
    required this.width,
    required this.height,
  });
  final Decoration decoration;
  final String title;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(10),
        decoration: decoration,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

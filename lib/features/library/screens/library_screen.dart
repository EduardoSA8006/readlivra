import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/models/book_entry.dart';
import '../providers.dart';
import '../viewmodels/library_state.dart';
import 'book_detail_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(libraryViewModelProvider);
    final vm = ref.read(libraryViewModelProvider.notifier);

    return SafeArea(
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: vm.reload,
        ),
        data: (state) => switch (state) {
          LibraryError(:final error) => _ErrorView(
              message: error.message,
              onRetry: vm.reload,
            ),
          LibraryLoading() =>
            const Center(child: CircularProgressIndicator()),
          LibraryLoaded() => _LibraryContent(state: state),
        },
      ),
    );
  }
}

class _LibraryContent extends ConsumerWidget {
  const _LibraryContent({required this.state});
  final LibraryLoaded state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(libraryViewModelProvider.notifier);

    if (state.lastError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.lastError!.message)),
        );
        vm.clearError();
      });
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Header(
            count: state.books.length,
            importing: state.importing,
            onImport: () => vm.pickAndImportEpub(),
          ),
        ),
        if (state.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 22,
                crossAxisSpacing: 16,
                childAspectRatio: 0.55,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _LibraryItem(
                  entry: state.books[i],
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookDetailScreen(
                        bookId: state.books[i].id,
                      ),
                    ),
                  ),
                  onLongPress: () => _confirmRemove(
                    context,
                    state.books[i],
                    vm.remove,
                  ),
                ),
                childCount: state.books.length,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    BookEntry entry,
    Future<void> Function(String) remove,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover livro?'),
        content: Text(
            'O arquivo "${entry.title}" será removido da biblioteca.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm == true) await remove(entry.id);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.importing,
    required this.onImport,
  });
  final int count;
  final bool importing;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Biblioteca',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (count > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$count ${count == 1 ? "livro" : "livros"}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          if (importing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            onPressed: importing ? null : onImport,
            icon: const Icon(Icons.add_rounded, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _LibraryItem extends StatelessWidget {
  const _LibraryItem({
    required this.entry,
    required this.onOpen,
    required this.onLongPress,
  });
  final BookEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.66,
            child: _CoverImage(entry: entry),
          ),
          const SizedBox(height: 8),
          Text(
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            entry.author ?? 'Autor desconhecido',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.entry});
  final BookEntry entry;

  @override
  Widget build(BuildContext context) {
    final fallbackColor = _colorForTitle(entry.title);
    final boxDecoration = BoxDecoration(
      color: fallbackColor,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );

    if (entry.coverPath == null) {
      return _FallbackCover(decoration: boxDecoration, title: entry.title);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: boxDecoration,
        child: Image.file(
          File(entry.coverPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _FallbackCover(decoration: boxDecoration, title: entry.title),
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
  const _FallbackCover({required this.decoration, required this.title});
  final Decoration decoration;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: decoration,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          title,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined,
                size: 56, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Sua biblioteca está vazia.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Toque em + para importar um arquivo .epub do dispositivo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFB35454)),
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

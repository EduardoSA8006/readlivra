import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/models/book_entry.dart';
import '../../../core/models/book_progress.dart';
import '../providers.dart';
import '../viewmodels/library_state.dart';
import '../viewmodels/library_ui_notifier.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(libraryViewModelProvider);
    final vm = ref.read(libraryViewModelProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              _ErrorView(message: e.toString(), onRetry: vm.reload),
          data: (state) => switch (state) {
            LibraryError(:final error) => _ErrorView(
              message: error.message,
              onRetry: vm.reload,
            ),
            LibraryLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            LibraryLoaded() => _buildLoaded(context, state, vm),
          },
        ),
      ),
      floatingActionButton: async.maybeWhen(
        data: (state) => state is LibraryLoaded
            ? FloatingActionButton.extended(
                onPressed: state.importing ? null : () => _import(vm),
                icon: state.importing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(state.importing ? 'Importando…' : 'Adicionar'),
              )
            : null,
        orElse: () => null,
      ),
    );
  }

  Future<void> _import(dynamic vm) async {
    await vm.pickAndImportEpub();
  }

  Widget _buildLoaded(BuildContext context, LibraryLoaded state, dynamic vm) {
    if (state.lastError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.lastError!.message)));
        vm.clearError();
      });
    }

    final ui = ref.watch(libraryUiProvider);
    final uiNotifier = ref.read(libraryUiProvider.notifier);

    // Keep the controller in sync if the UI state was reset externally.
    if (_searchController.text != ui.query) {
      _searchController.value = TextEditingValue(
        text: ui.query,
        selection: TextSelection.collapsed(offset: ui.query.length),
      );
    }

    final filtered = _applyFilters(state.books, ui);

    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              count: state.books.length,
              filteredCount: filtered.length,
              hasFilter: ui.query.isNotEmpty,
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: ui.searchVisible
                  ? _Toolbar(
                      controller: _searchController,
                      query: ui.query,
                      onQueryChanged: uiNotifier.setQuery,
                      sortMode: ui.sortMode,
                      onSortChanged: uiNotifier.setSortMode,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
          if (state.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyLibrary(),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptySearch(query: ui.query),
            )
          else
            ..._buildItems(context, filtered, vm, ui.viewMode),
          // FAB clearance
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  List<BookEntry> _applyFilters(List<BookEntry> input, LibraryUiState ui) {
    var list = [...input];
    if (ui.query.isNotEmpty) {
      final q = ui.query.toLowerCase();
      list = list.where((b) {
        return b.title.toLowerCase().contains(q) ||
            (b.author ?? '').toLowerCase().contains(q);
      }).toList();
    }
    switch (ui.sortMode) {
      case LibrarySortMode.recentlyAdded:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      case LibrarySortMode.title:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case LibrarySortMode.author:
        list.sort(
          (a, b) => (a.author ?? '~').toLowerCase().compareTo(
            (b.author ?? '~').toLowerCase(),
          ),
        );
    }
    return list;
  }

  List<Widget> _buildItems(
    BuildContext context,
    List<BookEntry> books,
    dynamic vm,
    LibraryViewMode viewMode,
  ) {
    if (viewMode == LibraryViewMode.grid) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 22,
              crossAxisSpacing: 16,
              childAspectRatio: 0.46,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _GridItem(
                entry: books[i],
                onOpen: () => _openDetail(context, books[i]),
                onLongPress: () => _confirmRemove(context, books[i], vm),
              ),
              childCount: books.length,
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _ListItem(
              entry: books[i],
              onOpen: () => _openDetail(context, books[i]),
              onLongPress: () => _confirmRemove(context, books[i], vm),
            ),
            childCount: books.length,
          ),
        ),
      ),
    ];
  }

  void _openDetail(BuildContext context, BookEntry entry) {
    Navigator.of(context).push(AppRoutes.bookDetail(bookId: entry.id));
  }

  Future<void> _confirmRemove(
    BuildContext context,
    BookEntry entry,
    dynamic vm,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover livro?'),
        content: Text('"${entry.title}" será removido da biblioteca.'),
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
    if (confirm == true) await vm.remove(entry.id);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.filteredCount,
    required this.hasFilter,
  });
  final int count;
  final int filteredCount;
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = hasFilter
        ? '$filteredCount de $count'
        : count == 0
        ? 'Nenhum livro ainda'
        : '$count ${count == 1 ? "livro" : "livros"}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.query,
    required this.onQueryChanged,
    required this.sortMode,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final LibrarySortMode sortMode;
  final ValueChanged<LibrarySortMode> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: controller,
                onChanged: onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar título ou autor',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 20,
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            controller.clear();
                            onQueryChanged('');
                          },
                          color: scheme.onSurfaceVariant,
                          splashRadius: 16,
                        ),
                  filled: true,
                  fillColor: scheme.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.primary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _IconAffordance(
            icon: Icons.sort_rounded,
            tooltip: 'Ordenar',
            onTap: () async {
              final selected = await showModalBottomSheet<LibrarySortMode>(
                context: context,
                builder: (_) => _SortSheet(current: sortMode),
              );
              if (selected != null) onSortChanged(selected);
            },
          ),
        ],
      ),
    );
  }
}

class _IconAffordance extends StatelessWidget {
  const _IconAffordance({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline),
          ),
          child: Icon(icon, size: 20, color: scheme.onSurface),
        ),
      ),
    );
  }
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current});
  final LibrarySortMode current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'ORDENAR POR',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final mode in LibrarySortMode.values)
              ListTile(
                title: Text(mode.label),
                leading: Icon(
                  mode == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: mode == current
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                onTap: () => Navigator.of(context).pop(mode),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _GridItem extends ConsumerWidget {
  const _GridItem({
    required this.entry,
    required this.onOpen,
    required this.onLongPress,
  });
  final BookEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final progressAsync = ref.watch(bookProgressProvider(entry.id));
    final progress = _progressFor(progressAsync.value, entry);
    return InkWell(
      onTap: onOpen,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(aspectRatio: 0.66, child: _CoverImage(entry: entry)),
          const SizedBox(height: 8),
          if (progress > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: scheme.outline,
                valueColor: AlwaysStoppedAnimation(scheme.primary),
              ),
            )
          else
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: scheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              entry.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            entry.author ?? 'Autor desconhecido',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ListItem extends ConsumerWidget {
  const _ListItem({
    required this.entry,
    required this.onOpen,
    required this.onLongPress,
  });
  final BookEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final progressAsync = ref.watch(bookProgressProvider(entry.id));
    final bookProgress = progressAsync.value;
    final progress = _progressFor(bookProgress, entry);
    final chapterCount = entry.chapterCount ?? 0;
    final currentChapter = ((bookProgress?.chapterIndex ?? 0) + 1).clamp(
      0,
      chapterCount,
    );
    final isCompleted = progress >= 1;
    final isReading = progress > 0 && !isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: onOpen,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  height: 96,
                  child: _CoverImage(entry: entry),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                          height: 1.25,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.author ?? 'Autor desconhecido',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _StatusRow(
                        scheme: scheme,
                        isCompleted: isCompleted,
                        isReading: isReading,
                        progress: progress,
                        currentChapter: currentChapter,
                        chapterCount: chapterCount,
                      ),
                      if (isReading) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: scheme.outline.withValues(
                              alpha: 0.6,
                            ),
                            valueColor: AlwaysStoppedAnimation(scheme.primary),
                          ),
                        ),
                      ],
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.scheme,
    required this.isCompleted,
    required this.isReading,
    required this.progress,
    required this.currentChapter,
    required this.chapterCount,
  });

  final ColorScheme scheme;
  final bool isCompleted;
  final bool isReading;
  final double progress;
  final int currentChapter;
  final int chapterCount;

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return _StatusBadge(
        icon: Icons.check_circle_rounded,
        label: 'Concluído',
        color: scheme.tertiary,
      );
    }
    if (isReading) {
      return Row(
        children: [
          _StatusBadge(
            icon: Icons.menu_book_rounded,
            label: '${(progress * 100).round()}%',
            color: scheme.primary,
          ),
          const SizedBox(width: 8),
          if (chapterCount > 0)
            Flexible(
              child: Text(
                'cap. $currentChapter de $chapterCount',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      );
    }
    return _StatusBadge(
      icon: Icons.fiber_new_rounded,
      label: chapterCount > 0
          ? '$chapterCount ${chapterCount == 1 ? "capítulo" : "capítulos"}'
          : 'Não iniciado',
      color: scheme.onSurfaceVariant,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

double _progressFor(BookProgress? progress, BookEntry entry) {
  if (progress == null) return 0;
  final count = entry.chapterCount ?? 0;
  if (count == 0) return 0;
  return ((progress.chapterIndex + 1) / count).clamp(0.0, 1.0);
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.entry});
  final BookEntry entry;

  @override
  Widget build(BuildContext context) {
    final fallbackColor = _colorForTitle(entry.title);
    final boxDecoration = BoxDecoration(
      color: fallbackColor,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
    if (entry.coverPath == null) {
      return _FallbackCover(decoration: boxDecoration, title: entry.title);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: decoration,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Tighter typography on small thumbnails (e.g. list rows).
            final compact = constraints.maxHeight < 110;
            return Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                title,
                maxLines: compact ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 9.5 : 11,
                  height: 1.2,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_outlined,
                size: 44,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sua biblioteca está vazia',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toque em "Adicionar" para importar seu primeiro arquivo .epub do dispositivo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum livro corresponde a "$query"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
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

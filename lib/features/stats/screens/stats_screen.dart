import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../library/data/models/book_entry.dart';
import '../../library/providers.dart';
import '../../library/screens/book_detail_screen.dart';
import '../../library/viewmodels/library_state.dart';
import '../data/models/reading_summary.dart';
import '../providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statsViewModelProvider);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(statsViewModelProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(statsViewModelProvider),
          ),
          data: (summary) => _SummaryView(summary: summary),
        ),
      ),
    );
  }
}

class _SummaryView extends ConsumerWidget {
  const _SummaryView({required this.summary});
  final ReadingSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryViewModelProvider);
    final books = libraryAsync.maybeWhen(
      data: (s) => s is LibraryLoaded ? s.books : const <BookEntry>[],
      orElse: () => const <BookEntry>[],
    );
    final byId = {for (final b in books) b.id: b};

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Estatísticas',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        _StreakCard(summary: summary),
        const SizedBox(height: 16),
        _StatGrid(summary: summary),
        const SizedBox(height: 24),
        Text('Por livro', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (summary.perBook.isEmpty)
          const _EmptyPerBook()
        else
          ...summary.perBook.map(
            (b) => _BookStatRow(
              stat: b,
              entry: byId[b.bookId],
              onTap: byId.containsKey(b.bookId)
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              BookDetailScreen(bookId: b.bookId),
                        ),
                      )
                  : null,
            ),
          ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.summary});
  final ReadingSummary summary;

  @override
  Widget build(BuildContext context) {
    final daysSinceInstall =
        DateTime.now().difference(summary.installedAt).inDays + 1;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E2148), Color(0xFF5C4B8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _StreakNumber(label: 'Dias seguidos', value: summary.currentStreak),
          Container(
            width: 1,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.white24,
          ),
          _StreakNumber(label: 'Dias com leitura', value: summary.activeDays),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'DESDE A INSTALAÇÃO',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9.5,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$daysSinceInstall ${daysSinceInstall == 1 ? "dia" : "dias"}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakNumber extends StatelessWidget {
  const _StreakNumber({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.summary});
  final ReadingSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(label: 'Hoje', value: summary.today),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(label: '7 dias', value: summary.last7Days),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(label: '30 dias', value: summary.last30Days),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(label: 'Total', value: summary.allTime),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final Duration value;

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
              formatDuration(value),
              style: const TextStyle(
                fontSize: 18,
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

class _BookStatRow extends StatelessWidget {
  const _BookStatRow({
    required this.stat,
    required this.entry,
    this.onTap,
  });
  final BookReadingTotal stat;
  final BookEntry? entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = entry?.title ?? 'Livro removido';
    final author = entry?.author ?? '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surface,
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: entry == null
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatDuration(stat.total),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (stat.today > Duration.zero)
                      Text(
                        'Hoje: ${formatDuration(stat.today)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                if (onTap != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPerBook extends StatelessWidget {
  const _EmptyPerBook();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE7DD)),
      ),
      child: Text(
        'Abra um livro para começar a acompanhar seu tempo de leitura.',
        style: Theme.of(context).textTheme.bodySmall,
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
                onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}

String formatDuration(Duration d) {
  if (d.inMinutes < 1) return '${d.inSeconds}s';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

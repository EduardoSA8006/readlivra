import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../library/data/models/book_entry.dart';
import '../../library/data/models/book_progress.dart';
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
    final hasAnyData = summary.allTime > Duration.zero;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _HeroCard(summary: summary),
        const SizedBox(height: 16),
        _MetricsGrid(summary: summary),
        const SizedBox(height: 24),
        _WeekChart(summary: summary),
        const SizedBox(height: 24),
        _BooksCard(
          stats: summary.perBook,
          booksById: byId,
          hasAnyData: hasAnyData,
          previewLimit: 3,
          onSeeAll: hasAnyData
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _AllBooksTimeScreen(
                      stats: summary.perBook,
                      booksById: byId,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.summary});
  final ReadingSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppPalette.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F4FCC).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TEMPO DE LEITURA HOJE',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDurationFull(summary.today),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1.0,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroBadge(
                icon: Icons.local_fire_department_rounded,
                label:
                    '${summary.currentStreak} '
                    '${summary.currentStreak == 1 ? "dia seguido" : "dias seguidos"}',
              ),
              const SizedBox(width: 10),
              _HeroBadge(
                icon: Icons.event_available_rounded,
                label:
                    '${summary.activeDays} '
                    '${summary.activeDays == 1 ? "dia ativo" : "dias ativos"}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.summary});
  final ReadingSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.calendar_view_week_rounded,
                label: 'Esta semana',
                value: formatDuration(summary.last7Days),
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                icon: Icons.calendar_month_rounded,
                label: 'Este mês',
                value: formatDuration(summary.last30Days),
                color: scheme.tertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.timer_rounded,
                label: 'Tempo total',
                value: formatDuration(summary.allTime),
                color: scheme.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                icon: Icons.timeline_rounded,
                label: 'Desde a instalação',
                value:
                    '${DateTime.now().difference(summary.installedAt).inDays + 1}d',
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                height: 1.1,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChartUnit { hours, minutes }

class _WeekChart extends StatefulWidget {
  const _WeekChart({required this.summary});
  final ReadingSummary summary;

  @override
  State<_WeekChart> createState() => _WeekChartState();
}

class _WeekChartState extends State<_WeekChart> {
  _ChartUnit _unit = _ChartUnit.hours;

  static const _weekdayLabels = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final localToday = DateTime(today.year, today.month, today.day);
    final days = List<DateTime>.generate(
      7,
      (i) => localToday.subtract(Duration(days: 6 - i)),
    );
    final values = days
        .map(
          (d) =>
              widget.summary.dailyTotals[DateTime(d.year, d.month, d.day)] ??
              Duration.zero,
        )
        .toList();
    final maxValue = values.fold<double>(0, (m, v) {
      final n = _toUnit(v, _unit);
      return n > m ? n : m;
    });
    final axisMax = _niceCeil(maxValue);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                    children: [const TextSpan(text: 'Atividade de leitura ')],
                  ),
                ),
              ),
              _UnitDropdown(
                unit: _unit,
                onChanged: (u) => setState(() => _unit = u),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 180,
            child: _ChartBody(
              days: days,
              values: values,
              labels: _weekdayLabels,
              unit: _unit,
              axisMax: axisMax,
              todayIndex: days.length - 1,
            ),
          ),
        ],
      ),
    );
  }

  static double _toUnit(Duration d, _ChartUnit unit) {
    final ms = d.inMilliseconds;
    if (unit == _ChartUnit.hours) return ms / (3600 * 1000);
    return ms / (60 * 1000);
  }

  /// Rounds [value] up to a "nice" axis maximum so the gridlines fall on
  /// readable round numbers. Always returns at least 1 for empty data.
  static double _niceCeil(double value) {
    if (value <= 0) return 1;
    final magnitudes = [
      0.5,
      1,
      2,
      4,
      8,
      12,
      16,
      24,
      30,
      45,
      60,
      90,
      120,
      180,
      240,
      360,
      480,
      600,
    ];
    for (final m in magnitudes) {
      if (value <= m) return m.toDouble();
    }
    return (value.ceilToDouble());
  }
}

class _ChartBody extends StatelessWidget {
  const _ChartBody({
    required this.days,
    required this.values,
    required this.labels,
    required this.unit,
    required this.axisMax,
    required this.todayIndex,
  });

  final List<DateTime> days;
  final List<Duration> values;
  final List<String> labels;
  final _ChartUnit unit;
  final double axisMax;
  final int todayIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 3 gridlines: 0, max/2, max
    final gridValues = [axisMax, axisMax / 2, 0.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Y axis numbers
        SizedBox(
          width: 28,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 26),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final v in gridValues)
                  Text(
                    _formatAxis(v, unit),
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // Gridlines
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var i = 0; i < gridValues.length; i++)
                            Container(
                              height: 1,
                              color: scheme.outline.withValues(alpha: 0.5),
                            ),
                        ],
                      ),
                    ),
                    // Bars
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var i = 0; i < days.length; i++)
                                Expanded(
                                  child: _Bar(
                                    value: values[i],
                                    unit: unit,
                                    axisMax: axisMax,
                                    isToday: i == todayIndex,
                                    plotHeight: c.maxHeight,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Labels
              Row(
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: Text(
                        labels[(days[i].weekday - 1) % 7],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: i == todayIndex
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: i == todayIndex
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatAxis(double value, _ChartUnit unit) {
    if (value == 0) return '0';
    if (unit == _ChartUnit.hours) {
      // Drop unnecessary decimals on integers, keep one otherwise.
      if (value == value.roundToDouble()) return value.toInt().toString();
      return value.toStringAsFixed(1).replaceAll('.', ',');
    }
    return value.toInt().toString();
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.unit,
    required this.axisMax,
    required this.isToday,
    required this.plotHeight,
  });

  final Duration value;
  final _ChartUnit unit;
  final double axisMax;
  final bool isToday;
  final double plotHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = _WeekChartState._toUnit(value, unit);
    final ratio = axisMax == 0 ? 0.0 : (n / axisMax).clamp(0.0, 1.0);
    final hasAny = value > Duration.zero;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (hasAny)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _formatBar(n, unit),
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            height: hasAny ? (plotHeight * ratio).clamp(6.0, plotHeight) : 0.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [scheme.primary, scheme.primary.withValues(alpha: 0.7)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
                bottom: Radius.circular(2),
              ),
              boxShadow: isToday
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatBar(double n, _ChartUnit unit) {
    if (unit == _ChartUnit.hours) {
      final str = n.toStringAsFixed(1).replaceAll('.', ',');
      return '${str}h';
    }
    return '${n.round()}m';
  }
}

class _UnitDropdown extends StatelessWidget {
  const _UnitDropdown({required this.unit, required this.onChanged});
  final _ChartUnit unit;
  final ValueChanged<_ChartUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<_ChartUnit>(
      onSelected: onChanged,
      tooltip: 'Unidade',
      position: PopupMenuPosition.under,
      itemBuilder: (_) => const [
        PopupMenuItem(value: _ChartUnit.hours, child: Text('Horas')),
        PopupMenuItem(value: _ChartUnit.minutes, child: Text('Minutos')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              unit == _ChartUnit.hours ? 'Horas' : 'Minutos',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _BooksCard extends StatelessWidget {
  const _BooksCard({
    required this.stats,
    required this.booksById,
    required this.hasAnyData,
    required this.previewLimit,
    this.onSeeAll,
  });

  final List<BookReadingTotal> stats;
  final Map<String, BookEntry> booksById;
  final bool hasAnyData;
  final int previewLimit;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = stats.take(previewLimit).toList();
    final hasMore = stats.length > previewLimit;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Livros mais lidos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (onSeeAll != null && hasMore)
                  TextButton(
                    onPressed: onSeeAll,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Ver todos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!hasAnyData)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _InlineEmpty(),
            )
          else
            ...List.generate(preview.length, (i) {
              final stat = preview[i];
              final entry = booksById[stat.bookId];
              return _BookProgressRow(
                stat: stat,
                entry: entry,
                showDivider: i < preview.length - 1,
                onTap: entry == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BookDetailScreen(bookId: stat.bookId),
                        ),
                      ),
              );
            }),
        ],
      ),
    );
  }
}

class _BookProgressRow extends ConsumerWidget {
  const _BookProgressRow({
    required this.stat,
    required this.entry,
    required this.showDivider,
    this.onTap,
  });

  final BookReadingTotal stat;
  final BookEntry? entry;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isMissing = entry == null;
    final progressAsync = isMissing
        ? null
        : ref.watch(bookProgressProvider(entry!.id));
    final progress = isMissing
        ? 0.0
        : _readingProgress(progressAsync?.value, entry!);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: showDivider
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: scheme.outline.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _MiniCover(entry: entry),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                entry?.title ?? 'Livro removido',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isMissing
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                                  height: 1.25,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                entry?.author ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            formatDuration(stat.total),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: scheme.secondary,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: scheme.outline.withValues(
                                alpha: 0.6,
                              ),
                              valueColor: AlwaysStoppedAnimation(
                                scheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${(progress * 100).round()}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: onTap == null ? scheme.outline : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _readingProgress(BookProgress? bookProgress, BookEntry entry) {
  final count = entry.chapterCount ?? 0;
  if (count == 0 || bookProgress == null) return 0;
  return (((bookProgress.chapterIndex + 1) / count)).clamp(0.0, 1.0);
}

enum _AllBooksSort { time, title, progress }

class _AllBooksTimeScreen extends ConsumerStatefulWidget {
  const _AllBooksTimeScreen({required this.stats, required this.booksById});

  final List<BookReadingTotal> stats;
  final Map<String, BookEntry> booksById;

  @override
  ConsumerState<_AllBooksTimeScreen> createState() =>
      _AllBooksTimeScreenState();
}

class _AllBooksTimeScreenState extends ConsumerState<_AllBooksTimeScreen> {
  _AllBooksSort _sort = _AllBooksSort.time;

  static const _sortLabels = {
    _AllBooksSort.time: 'Mais lidos',
    _AllBooksSort.title: 'Título (A–Z)',
    _AllBooksSort.progress: 'Progresso',
  };

  static const _sortIcons = {
    _AllBooksSort.time: Icons.timer_outlined,
    _AllBooksSort.title: Icons.sort_by_alpha_rounded,
    _AllBooksSort.progress: Icons.trending_up_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ordered = _applySort(widget.stats);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Livros mais lidos',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<_AllBooksSort>(
            tooltip: 'Ordenar',
            position: PopupMenuPosition.under,
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            icon: Icon(Icons.sort_rounded, color: scheme.onSurface),
            itemBuilder: (_) => [
              for (final sort in _AllBooksSort.values)
                PopupMenuItem<_AllBooksSort>(
                  value: sort,
                  child: Row(
                    children: [
                      Icon(
                        _sortIcons[sort],
                        size: 18,
                        color: sort == _sort
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _sortLabels[sort]!,
                        style: TextStyle(
                          fontWeight: sort == _sort
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: sort == _sort
                              ? scheme.primary
                              : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < ordered.length; i++)
                    _RankedBookRow(
                      rank: i + 1,
                      stat: ordered[i],
                      entry: widget.booksById[ordered[i].bookId],
                      showDivider: i < ordered.length - 1,
                      onTap: widget.booksById.containsKey(ordered[i].bookId)
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    BookDetailScreen(bookId: ordered[i].bookId),
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BookReadingTotal> _applySort(List<BookReadingTotal> input) {
    final out = [...input];
    switch (_sort) {
      case _AllBooksSort.time:
        out.sort((a, b) => b.total.compareTo(a.total));
      case _AllBooksSort.title:
        const missing = '~';
        out.sort((a, b) {
          final ta = widget.booksById[a.bookId]?.title.toLowerCase() ?? missing;
          final tb = widget.booksById[b.bookId]?.title.toLowerCase() ?? missing;
          return ta.compareTo(tb);
        });
      case _AllBooksSort.progress:
        out.sort((a, b) {
          final pa = _safeProgress(a.bookId);
          final pb = _safeProgress(b.bookId);
          return pb.compareTo(pa);
        });
    }
    return out;
  }

  double _safeProgress(String bookId) {
    final entry = widget.booksById[bookId];
    if (entry == null) return 0;
    final progress = ref.read(bookProgressProvider(bookId)).value;
    return _readingProgress(progress, entry);
  }
}

class _RankedBookRow extends ConsumerWidget {
  const _RankedBookRow({
    required this.rank,
    required this.stat,
    required this.entry,
    required this.showDivider,
    this.onTap,
  });

  final int rank;
  final BookReadingTotal stat;
  final BookEntry? entry;
  final bool showDivider;
  final VoidCallback? onTap;

  Color _rankColor(int rank, ColorScheme scheme) {
    switch (rank) {
      case 1:
        return const Color(0xFFE0A44A); // gold
      case 2:
        return const Color(0xFFB9C2CC); // silver
      case 3:
        return const Color(0xFFC4895A); // bronze
      default:
        return scheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isMissing = entry == null;
    final progressAsync = isMissing
        ? null
        : ref.watch(bookProgressProvider(entry!.id));
    final progress = isMissing
        ? 0.0
        : _readingProgress(progressAsync?.value, entry!);
    final rankColor = _rankColor(rank, scheme);
    final highlighted = rank <= 3;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: showDivider
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: scheme.outline.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: highlighted ? 18 : 15,
                    fontWeight: FontWeight.w900,
                    color: rankColor,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _MiniCover(entry: entry),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                entry?.title ?? 'Livro removido',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isMissing
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                entry?.author ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            formatDuration(stat.total),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: scheme.secondary,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              backgroundColor: scheme.outline.withValues(
                                alpha: 0.6,
                              ),
                              valueColor: AlwaysStoppedAnimation(
                                scheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${(progress * 100).round()}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(
          Icons.auto_stories_rounded,
          size: 32,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(height: 10),
        Text(
          'Abra um livro para começar a registrar seu tempo de leitura.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _MiniCover extends StatelessWidget {
  const _MiniCover({required this.entry});
  final BookEntry? entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = entry == null
        ? scheme.outline
        : _colorForTitle(entry!.title);
    final decoration = BoxDecoration(
      color: fallback,
      borderRadius: BorderRadius.circular(6),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
    final size = const Size(40, 56);
    if (entry?.coverPath == null) {
      return SizedBox(
        width: size.width,
        height: size.height,
        child: Container(decoration: decoration),
      );
    }
    return SizedBox(
      width: size.width,
      height: size.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: decoration,
          child: Image.file(
            File(entry!.coverPath!),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(decoration: decoration),
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

String formatDuration(Duration d) {
  if (d.inMinutes < 1) return '${d.inSeconds}s';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h${m}m';
}

String _formatDurationFull(Duration d) {
  if (d.inSeconds < 60) {
    final s = d.inSeconds;
    return '$s ${s == 1 ? "seg" : "segs"}';
  }
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}min';
  if (m == 0) return '${h}h';
  return '${h}h ${m}min';
}

import 'date_keys.dart';
import 'models/reading_summary.dart';

/// Pure composition of the reading summary, pulled out of the view model so
/// it can be exercised by unit tests without spinning up Riverpod.
///
/// [data] is the raw `bookId → {YYYY-MM-DD → ms}` snapshot from the repo.
/// [installedAt] anchors "since installation".
/// [now] defaults to [DateTime.now]; injected in tests to simulate timezone
/// changes or arbitrary clocks.
ReadingSummary composeReadingSummary({
  required Map<String, Map<String, int>> data,
  required DateTime installedAt,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final activeDates = <String>{};

  DateTime? mostRecent;
  for (final entry in data.entries) {
    for (final day in entry.value.entries) {
      if (day.value <= 0) continue;
      final date = parseDateKey(day.key);
      if (date == null) continue;
      activeDates.add(day.key);
      if (mostRecent == null || date.isAfter(mostRecent)) mostRecent = date;
    }
  }

  final localToday = DateTime(clock.year, clock.month, clock.day);
  final effectiveToday =
      mostRecent != null && mostRecent.isAfter(localToday)
          ? mostRecent
          : localToday;
  final effectiveTodayKey = dateKeyOf(effectiveToday);
  final last7Cutoff = effectiveToday.subtract(const Duration(days: 6));
  final last30Cutoff = effectiveToday.subtract(const Duration(days: 29));

  var todayMs = 0;
  var weekMs = 0;
  var monthMs = 0;
  var allMs = 0;
  final dailyMs = <DateTime, int>{};

  final perBookTotals = <String, ({int total, int today, DateTime? last})>{};

  for (final entry in data.entries) {
    final bookId = entry.key;
    var bookTotal = 0;
    var bookToday = 0;
    DateTime? lastForBook;

    for (final day in entry.value.entries) {
      final ms = day.value;
      if (ms <= 0) continue;
      final date = parseDateKey(day.key);
      if (date == null) continue;

      bookTotal += ms;
      allMs += ms;

      if (lastForBook == null || date.isAfter(lastForBook)) lastForBook = date;
      if (day.key == effectiveTodayKey) {
        todayMs += ms;
        bookToday += ms;
      }
      if (!date.isBefore(last7Cutoff)) weekMs += ms;
      if (!date.isBefore(last30Cutoff)) {
        monthMs += ms;
        dailyMs[date] = (dailyMs[date] ?? 0) + ms;
      }
    }

    perBookTotals[bookId] = (
      total: bookTotal,
      today: bookToday,
      last: lastForBook,
    );
  }

  final perBook = perBookTotals.entries
      .map((e) => BookReadingTotal(
            bookId: e.key,
            total: Duration(milliseconds: e.value.total),
            today: Duration(milliseconds: e.value.today),
            lastReadAt: e.value.last,
          ))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  return ReadingSummary(
    today: Duration(milliseconds: todayMs),
    last7Days: Duration(milliseconds: weekMs),
    last30Days: Duration(milliseconds: monthMs),
    allTime: Duration(milliseconds: allMs),
    currentStreak: _streak(activeDates, effectiveToday),
    activeDays: activeDates.length,
    installedAt: installedAt,
    perBook: perBook,
    dailyTotals: {
      for (final entry in dailyMs.entries)
        entry.key: Duration(milliseconds: entry.value),
    },
  );
}

int _streak(Set<String> activeDates, DateTime anchor) {
  var streak = 0;
  var cursor = anchor;
  while (activeDates.contains(dateKeyOf(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

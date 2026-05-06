class BookReadingTotal {
  const BookReadingTotal({
    required this.bookId,
    required this.total,
    required this.today,
    this.lastReadAt,
  });

  final String bookId;
  final Duration total;
  final Duration today;
  final DateTime? lastReadAt;
}

class ReadingSummary {
  const ReadingSummary({
    required this.today,
    required this.last7Days,
    required this.last30Days,
    required this.allTime,
    required this.currentStreak,
    required this.activeDays,
    required this.installedAt,
    required this.perBook,
    required this.dailyTotals,
  });

  final Duration today;
  final Duration last7Days;
  final Duration last30Days;
  final Duration allTime;
  final int currentStreak;
  final int activeDays;
  final DateTime installedAt;
  final List<BookReadingTotal> perBook;

  /// Total reading time per local calendar day. Keys are date-only
  /// (no time component). Used to draw the weekly histogram.
  final Map<DateTime, Duration> dailyTotals;
}

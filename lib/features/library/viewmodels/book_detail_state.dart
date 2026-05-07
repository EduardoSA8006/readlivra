import '../../../core/models/ebook.dart';
import '../../../core/models/book_entry.dart';
import '../../../core/models/book_progress.dart';

class BookDetailData {
  const BookDetailData({
    required this.book,
    required this.progress,
    required this.ebook,
    required this.totalReadingTime,
    required this.todayReadingTime,
    this.lastReadAt,
    this.fileSizeBytes,
  });

  final BookEntry book;
  final BookProgress progress;
  final Ebook ebook;
  final Duration totalReadingTime;
  final Duration todayReadingTime;
  final DateTime? lastReadAt;
  final int? fileSizeBytes;

  int get chapterCount => ebook.chapterCount;
  int get currentChapter => progress.chapterIndex;

  double get chapterProgress =>
      chapterCount == 0 ? 0 : ((currentChapter + 1) / chapterCount).clamp(0.0, 1.0);
}

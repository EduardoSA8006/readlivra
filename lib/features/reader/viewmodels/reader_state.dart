import '../../../core/result/app_exceptions.dart';
import '../data/models/ebook.dart';
import '../data/models/ebook_chapter.dart';

class ReaderAnchor {
  const ReaderAnchor({required this.blockIndex, required this.alignment});
  final int blockIndex;
  final double alignment;
}

sealed class ReaderState {
  const ReaderState();
}

final class ReaderIdle extends ReaderState {
  const ReaderIdle();
}

final class ReaderLoading extends ReaderState {
  const ReaderLoading();
}

final class ReaderReading extends ReaderState {
  const ReaderReading({
    required this.ebook,
    required this.chapterIndex,
    this.bookId,
    this.pendingAnchor,
  });

  final Ebook ebook;
  final int chapterIndex;
  final String? bookId;

  /// One-shot anchor the View should consume the first time the chapter
  /// settles in the layout, then null out via the view model.
  final ReaderAnchor? pendingAnchor;

  EbookChapter get currentChapter => ebook.chapters[chapterIndex];
  bool get hasNext => chapterIndex < ebook.chapters.length - 1;
  bool get hasPrevious => chapterIndex > 0;
  double get progress =>
      ebook.chapterCount == 0 ? 0 : (chapterIndex + 1) / ebook.chapterCount;

  ReaderReading copyWith({
    int? chapterIndex,
    ReaderAnchor? pendingAnchor,
    bool clearPendingAnchor = false,
  }) =>
      ReaderReading(
        ebook: ebook,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        bookId: bookId,
        pendingAnchor: clearPendingAnchor
            ? null
            : (pendingAnchor ?? this.pendingAnchor),
      );
}

final class ReaderError extends ReaderState {
  const ReaderError(this.error);
  final AppException error;
}

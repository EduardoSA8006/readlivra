import '../../../core/result/result.dart';
import '../../../core/models/bookmark.dart';
import '../../../core/models/highlight.dart';

abstract class AnnotationsRepository {
  Future<Result<List<Bookmark>>> listBookmarks(String bookId);
  Future<Result<List<Highlight>>> listHighlights(String bookId);

  Future<Result<Bookmark>> addBookmark(Bookmark bookmark);
  Future<Result<Highlight>> addHighlight(Highlight highlight);

  Future<Result<void>> updateBookmarkNote(String id, String? note);
  Future<Result<void>> removeBookmark(String id);
  Future<Result<void>> removeHighlight(String id);

  /// Removes any annotation linked to the given block (bookmark + every
  /// highlight on that block).
  Future<Result<void>> removeAnnotationsAt({
    required String bookId,
    required int chapterIndex,
    required int blockIndex,
  });

  /// Removes the bookmark for a specific block only (highlights are kept).
  Future<Result<void>> removeBookmarkAt({
    required String bookId,
    required int chapterIndex,
    required int blockIndex,
  });

  Future<Result<void>> clearForBook(String bookId);
}

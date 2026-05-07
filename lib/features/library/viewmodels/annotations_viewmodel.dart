import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/annotations_repository.dart';
import '../../../core/models/bookmark.dart';
import '../../../core/models/highlight.dart';
import '../providers.dart';

class AnnotationsViewModel extends Notifier<void> {
  @override
  void build() {}

  Future<AnnotationsRepository> _repo() =>
      ref.read(annotationsRepositoryProvider.future);

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(this).toRadixString(36)}';

  Future<void> addBookmark({
    required String bookId,
    required int chapterIndex,
    required int blockIndex,
    required double blockAlignment,
    required String snippet,
    String? note,
  }) async {
    final repo = await _repo();
    final bookmark = Bookmark(
      id: _newId(),
      bookId: bookId,
      chapterIndex: chapterIndex,
      blockIndex: blockIndex,
      blockAlignment: blockAlignment,
      snippet: snippet,
      createdAt: DateTime.now(),
      note: note,
    );
    await repo.addBookmark(bookmark);
    ref.invalidate(bookmarksProvider(bookId));
  }

  Future<void> addHighlight({
    required String bookId,
    required int chapterIndex,
    required int blockIndex,
    required String snippet,
    HighlightColor color = HighlightColor.yellow,
    int? startOffset,
    int? endOffset,
  }) async {
    final repo = await _repo();
    final highlight = Highlight(
      id: _newId(),
      bookId: bookId,
      chapterIndex: chapterIndex,
      blockIndex: blockIndex,
      snippet: snippet,
      color: color,
      createdAt: DateTime.now(),
      startOffset: startOffset,
      endOffset: endOffset,
    );
    await repo.addHighlight(highlight);
    ref.invalidate(highlightsProvider(bookId));
  }

  Future<void> removeBookmarkAt({
    required String bookId,
    required int chapterIndex,
    required int blockIndex,
  }) async {
    final repo = await _repo();
    await repo.removeBookmarkAt(
      bookId: bookId,
      chapterIndex: chapterIndex,
      blockIndex: blockIndex,
    );
    ref.invalidate(bookmarksProvider(bookId));
  }

  Future<void> removeBookmark(String bookId, String id) async {
    final repo = await _repo();
    await repo.removeBookmark(id);
    ref.invalidate(bookmarksProvider(bookId));
  }

  Future<void> removeHighlight(String bookId, String id) async {
    final repo = await _repo();
    await repo.removeHighlight(id);
    ref.invalidate(highlightsProvider(bookId));
  }

  Future<void> updateBookmarkNote(
    String bookId,
    String id,
    String? note,
  ) async {
    final repo = await _repo();
    await repo.updateBookmarkNote(id, note);
    ref.invalidate(bookmarksProvider(bookId));
  }

  Future<void> removeAt({
    required String bookId,
    required int chapterIndex,
    required int blockIndex,
  }) async {
    final repo = await _repo();
    await repo.removeAnnotationsAt(
      bookId: bookId,
      chapterIndex: chapterIndex,
      blockIndex: blockIndex,
    );
    ref.invalidate(bookmarksProvider(bookId));
    ref.invalidate(highlightsProvider(bookId));
  }
}

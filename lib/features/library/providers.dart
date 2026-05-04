import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/storage_providers.dart';
import 'data/annotations_repository.dart';
import 'data/annotations_repository_impl.dart';
import 'data/import_service.dart';
import 'data/library_repository.dart';
import 'data/library_repository_impl.dart';
import 'data/models/book_entry.dart';
import 'data/models/book_progress.dart';
import 'data/models/bookmark.dart';
import 'data/models/highlight.dart';
import 'data/progress_repository.dart';
import 'data/progress_repository_impl.dart';
import 'viewmodels/annotations_viewmodel.dart';
import 'viewmodels/book_detail_state.dart';
import 'viewmodels/book_detail_viewmodel.dart';
import 'viewmodels/library_state.dart';
import 'viewmodels/library_viewmodel.dart';

final libraryRepositoryProvider =
    FutureProvider<LibraryRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SharedPrefsLibraryRepository(prefs);
});

final progressRepositoryProvider =
    FutureProvider<ProgressRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SharedPrefsProgressRepository(prefs);
});

final importServiceProvider = Provider<ImportService>((ref) {
  return const ImportService();
});

final libraryViewModelProvider =
    AsyncNotifierProvider<LibraryViewModel, LibraryState>(
  LibraryViewModel.new,
);

final bookDetailViewModelProvider = AsyncNotifierProvider.family<
    BookDetailViewModel, BookDetailData, String>(
  BookDetailViewModel.new,
);

final annotationsRepositoryProvider =
    FutureProvider<AnnotationsRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SharedPrefsAnnotationsRepository(prefs);
});

final bookmarksProvider =
    FutureProvider.family<List<Bookmark>, String>((ref, bookId) async {
  final repo = await ref.watch(annotationsRepositoryProvider.future);
  final result = await repo.listBookmarks(bookId);
  return result.valueOrNull ?? const [];
});

final highlightsProvider =
    FutureProvider.family<List<Highlight>, String>((ref, bookId) async {
  final repo = await ref.watch(annotationsRepositoryProvider.future);
  final result = await repo.listHighlights(bookId);
  return result.valueOrNull ?? const [];
});

final annotationsViewModelProvider =
    NotifierProvider<AnnotationsViewModel, void>(AnnotationsViewModel.new);

class ContinueReadingInfo {
  const ContinueReadingInfo({
    required this.book,
    required this.bookProgress,
  });

  final BookEntry book;
  final BookProgress bookProgress;

  int get chapterIndex => bookProgress.chapterIndex;

  /// Coarse progress: completed chapters over total. The block-anchored
  /// position within a chapter is tracked separately and isn't useful for
  /// the home card.
  double get progress {
    final count = book.chapterCount ?? 0;
    if (count == 0) return 0;
    return ((chapterIndex + 1) / count).clamp(0.0, 1.0);
  }
}

final continueReadingProvider =
    FutureProvider<ContinueReadingInfo?>((ref) async {
  // Re-evaluate whenever the library changes.
  ref.watch(libraryViewModelProvider);

  final progress = await ref.watch(progressRepositoryProvider.future);
  final library = await ref.watch(libraryRepositoryProvider.future);

  final lastResult = await progress.getLastOpenedBookId();
  final lastId = lastResult.valueOrNull;
  if (lastId == null) return null;

  final bookResult = await library.getBook(lastId);
  final book = bookResult.valueOrNull;
  if (book == null) return null;

  final progressResult = await progress.getProgress(lastId);
  final bookProgress = progressResult.valueOrNull ?? BookProgress.empty;

  return ContinueReadingInfo(book: book, bookProgress: bookProgress);
});

import '../../../core/result/app_exceptions.dart';
import '../../../core/models/book_entry.dart';

sealed class LibraryState {
  const LibraryState();
}

final class LibraryLoading extends LibraryState {
  const LibraryLoading();
}

final class LibraryLoaded extends LibraryState {
  const LibraryLoaded({
    required this.books,
    this.importing = false,
    this.lastError,
  });

  final List<BookEntry> books;
  final bool importing;
  final AppException? lastError;

  bool get isEmpty => books.isEmpty;

  LibraryLoaded copyWith({
    List<BookEntry>? books,
    bool? importing,
    AppException? lastError,
    bool clearError = false,
  }) =>
      LibraryLoaded(
        books: books ?? this.books,
        importing: importing ?? this.importing,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

final class LibraryError extends LibraryState {
  const LibraryError(this.error);
  final AppException error;
}

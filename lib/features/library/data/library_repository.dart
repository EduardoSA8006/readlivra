import '../../../core/result/result.dart';
import 'models/book_entry.dart';

abstract class LibraryRepository {
  Future<Result<List<BookEntry>>> listBooks();
  Future<Result<BookEntry>> addBook(BookEntry entry);
  Future<Result<void>> removeBook(String id);
  Future<Result<BookEntry?>> getBook(String id);
}

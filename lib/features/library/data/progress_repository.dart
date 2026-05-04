import '../../../core/result/result.dart';
import 'models/book_progress.dart';

abstract class ProgressRepository {
  Future<Result<BookProgress>> getProgress(String bookId);
  Future<Result<void>> setProgress(String bookId, BookProgress progress);

  Future<Result<String?>> getLastOpenedBookId();
  Future<Result<void>> setLastOpenedBookId(String? id);

  Future<Result<void>> clear(String bookId);
}

import '../../../core/result/result.dart';

abstract class StatsRepository {
  Future<Result<void>> addReadingTime({
    required String bookId,
    required DateTime date,
    required Duration duration,
  });

  /// Returns a snapshot keyed by `bookId -> {YYYY-MM-DD -> ms}`.
  Future<Result<Map<String, Map<String, int>>>> readAll();

  Future<Result<void>> clearForBook(String bookId);
  Future<Result<void>> clearAll();
}

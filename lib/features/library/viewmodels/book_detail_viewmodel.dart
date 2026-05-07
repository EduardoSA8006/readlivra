import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/app_exceptions.dart';
import '../../../core/models/book_progress.dart';
import '../../reader/providers.dart';
import '../../stats/data/date_keys.dart';
import '../../stats/providers.dart';
import '../providers.dart';
import 'book_detail_state.dart';

class BookDetailViewModel extends AsyncNotifier<BookDetailData> {
  BookDetailViewModel(this.bookId);
  final String bookId;

  @override
  Future<BookDetailData> build() async {
    final libraryRepo = await ref.watch(libraryRepositoryProvider.future);
    final progressRepo = await ref.watch(progressRepositoryProvider.future);
    final readerRepo = ref.watch(readerRepositoryProvider);
    final statsRepo = await ref.watch(statsRepositoryProvider.future);
    // Re-evaluate when stats change so the badge updates after a session.
    ref.watch(statsViewModelProvider);

    final entryResult = await libraryRepo.getBook(bookId);
    final entry = entryResult.valueOrNull;
    if (entry == null) {
      throw const NotFoundException(
        'Livro não encontrado na biblioteca.',
      );
    }

    final progressResult = await progressRepo.getProgress(bookId);
    final progress = progressResult.valueOrNull ?? BookProgress.empty;

    final ebookResult = await readerRepo.openEpub(entry.filePath);
    if (ebookResult.isErr) throw ebookResult.errorOrNull!;
    final ebook = ebookResult.valueOrNull!;

    final allStatsResult = await statsRepo.readAll();
    final raw = allStatsResult.valueOrNull ??
        const <String, Map<String, int>>{};
    final perDay = raw[bookId] ?? const <String, int>{};

    final todayKey = dateKeyOf(DateTime.now());
    var totalMs = 0;
    var todayMs = 0;
    DateTime? lastReadAt;
    for (final day in perDay.entries) {
      totalMs += day.value;
      if (day.key == todayKey) todayMs += day.value;
      final date = parseDateKey(day.key);
      if (date != null && (lastReadAt == null || date.isAfter(lastReadAt))) {
        lastReadAt = date;
      }
    }

    int? size;
    try {
      size = await File(entry.filePath).length();
    } catch (_) {
      size = null;
    }

    return BookDetailData(
      book: entry,
      progress: progress,
      ebook: ebook,
      totalReadingTime: Duration(milliseconds: totalMs),
      todayReadingTime: Duration(milliseconds: todayMs),
      lastReadAt: lastReadAt,
      fileSizeBytes: size,
    );
  }

  Future<bool> remove() async {
    final libraryVm = ref.read(libraryViewModelProvider.notifier);
    await libraryVm.remove(bookId);
    final statsRepo = await ref.read(statsRepositoryProvider.future);
    await statsRepo.clearForBook(bookId);
    final progressRepo = await ref.read(progressRepositoryProvider.future);
    await progressRepo.clear(bookId);
    ref.invalidate(statsViewModelProvider);
    return true;
  }

  Future<void> resetProgress() async {
    final progressRepo = await ref.read(progressRepositoryProvider.future);
    await progressRepo.setProgress(bookId, BookProgress.empty);
    ref.invalidateSelf();
  }
}

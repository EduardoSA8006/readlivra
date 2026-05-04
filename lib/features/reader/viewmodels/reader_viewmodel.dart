import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/app_exceptions.dart';
import '../../library/data/models/book_progress.dart';
import '../../library/data/progress_repository.dart';
import '../../library/providers.dart';
import '../data/reader_repository.dart';
import '../providers.dart';
import 'reader_state.dart';

class ReaderViewModel extends Notifier<ReaderState> {
  late final ReaderRepository _repository;

  int _lastSavedBlock = 0;
  double _lastSavedAlignment = 0;
  DateTime _lastSaveAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  ReaderState build() {
    _repository = ref.read(readerRepositoryProvider);
    return const ReaderIdle();
  }

  Future<void> pickAndOpenEpub() async {
    state = const ReaderLoading();
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['epub'],
        withData: false,
      );
      if (picked == null || picked.files.single.path == null) {
        state = const ReaderIdle();
        return;
      }
      await openEpub(picked.files.single.path!);
    } catch (e, s) {
      state = ReaderError(
        FileAccessException(
          'Não foi possível abrir o seletor de arquivos.',
          cause: e,
          stackTrace: s,
        ),
      );
    }
  }

  Future<void> openEpub(
    String path, {
    String? bookId,
    int? initialChapter,
    ReaderAnchor? initialAnchor,
  }) async {
    state = const ReaderLoading();
    final result = await _repository.openEpub(path);

    await result.when(
      ok: (ebook) async {
        var chapter = 0;
        ReaderAnchor? pending;
        if (initialChapter != null) {
          final lastIndex =
              ebook.chapterCount > 0 ? ebook.chapterCount - 1 : 0;
          chapter = initialChapter.clamp(0, lastIndex).toInt();
          pending = initialAnchor;
          if (bookId != null) {
            final progress = await _progressRepo();
            await progress.setLastOpenedBookId(bookId);
            await progress.setProgress(
              bookId,
              BookProgress(
                chapterIndex: chapter,
                blockIndex: initialAnchor?.blockIndex ?? 0,
                blockAlignment: initialAnchor?.alignment ?? 0,
                updatedAt: DateTime.now(),
              ),
            );
          }
        } else if (bookId != null) {
          final progress = await _progressRepo();
          final saved = await progress.getProgress(bookId);
          final bp = saved.valueOrNull ?? BookProgress.empty;
          chapter = bp.chapterIndex;
          if (chapter < 0 || chapter >= ebook.chapterCount) chapter = 0;
          if (bp.hasAnchor) {
            pending = ReaderAnchor(
              blockIndex: bp.blockIndex,
              alignment: bp.blockAlignment,
            );
          }
          await progress.setLastOpenedBookId(bookId);
        }
        _resetSaveTracking(pending);
        state = ReaderReading(
          ebook: ebook,
          chapterIndex: chapter,
          bookId: bookId,
          pendingAnchor: pending,
        );
      },
      err: (error) async {
        state = ReaderError(error);
      },
    );
  }

  void nextChapter() {
    final s = state;
    if (s is ReaderReading && s.hasNext) {
      _resetSaveTracking(null);
      state = ReaderReading(
        ebook: s.ebook,
        chapterIndex: s.chapterIndex + 1,
        bookId: s.bookId,
        pendingAnchor: null,
      );
      _persist(s.bookId, s.chapterIndex + 1, 0, 0);
    }
  }

  void previousChapter() {
    final s = state;
    if (s is ReaderReading && s.hasPrevious) {
      _resetSaveTracking(null);
      state = ReaderReading(
        ebook: s.ebook,
        chapterIndex: s.chapterIndex - 1,
        bookId: s.bookId,
        pendingAnchor: null,
      );
      _persist(s.bookId, s.chapterIndex - 1, 0, 0);
    }
  }

  void goToChapter(int index) {
    final s = state;
    if (s is ReaderReading &&
        index >= 0 &&
        index < s.ebook.chapterCount) {
      _resetSaveTracking(null);
      state = ReaderReading(
        ebook: s.ebook,
        chapterIndex: index,
        bookId: s.bookId,
        pendingAnchor: null,
      );
      _persist(s.bookId, index, 0, 0);
    }
  }

  /// Used by the annotations list to teleport the reader to a saved
  /// position. Always sets a pending anchor so the view restores scroll.
  void jumpToAnchor({
    required int chapterIndex,
    required int blockIndex,
    required double blockAlignment,
  }) {
    final s = state;
    if (s is! ReaderReading) return;
    if (chapterIndex < 0 || chapterIndex >= s.ebook.chapterCount) return;
    final anchor = ReaderAnchor(
      blockIndex: blockIndex,
      alignment: blockAlignment,
    );
    _resetSaveTracking(anchor);
    state = ReaderReading(
      ebook: s.ebook,
      chapterIndex: chapterIndex,
      bookId: s.bookId,
      pendingAnchor: anchor,
    );
    _persist(s.bookId, chapterIndex, blockIndex, blockAlignment);
  }

  /// Called by the View whenever the visible block changes. Debounced —
  /// both in time and delta — so we don't hammer SharedPreferences.
  void reportBlockPosition(int blockIndex, double alignment) {
    final s = state;
    if (s is! ReaderReading || s.bookId == null) return;
    final now = DateTime.now();
    final blockChanged = blockIndex != _lastSavedBlock;
    final alignmentDelta = (alignment - _lastSavedAlignment).abs();
    final elapsed = now.difference(_lastSaveAt);
    final shouldSave = blockChanged ||
        alignmentDelta > 0.15 ||
        elapsed.inMilliseconds > 1500;
    if (!shouldSave) return;
    _lastSavedBlock = blockIndex;
    _lastSavedAlignment = alignment;
    _lastSaveAt = now;
    _persist(s.bookId, s.chapterIndex, blockIndex, alignment);
  }

  void clearPendingAnchor() {
    final s = state;
    if (s is ReaderReading && s.pendingAnchor != null) {
      state = s.copyWith(clearPendingAnchor: true);
    }
  }

  void close() {
    state = const ReaderIdle();
  }

  void _resetSaveTracking(ReaderAnchor? anchor) {
    _lastSavedBlock = anchor?.blockIndex ?? 0;
    _lastSavedAlignment = anchor?.alignment ?? 0;
    _lastSaveAt = DateTime.now();
  }

  Future<ProgressRepository> _progressRepo() =>
      ref.read(progressRepositoryProvider.future);

  Future<void> _persist(
    String? bookId,
    int chapter,
    int blockIndex,
    double alignment,
  ) async {
    if (bookId == null) return;
    final repo = await _progressRepo();
    await repo.setProgress(
      bookId,
      BookProgress(
        chapterIndex: chapter,
        blockIndex: blockIndex,
        blockAlignment: alignment,
        updatedAt: DateTime.now(),
      ),
    );
  }
}

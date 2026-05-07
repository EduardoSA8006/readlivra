import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../data/import_service.dart';
import '../data/library_repository.dart';
import '../../../core/models/book_entry.dart';
import '../providers.dart';
import 'library_state.dart';

class LibraryViewModel extends AsyncNotifier<LibraryState> {
  late final LibraryRepository _repository;
  late final ImportService _importService;
  Directory? _booksDir;
  bool _autoDiscoverScheduled = false;

  @override
  Future<LibraryState> build() async {
    _repository = await ref.read(libraryRepositoryProvider.future);
    _importService = ref.read(importServiceProvider);
    _booksDir = await ref.read(booksDirectoryProvider.future);

    final result = await _repository.listBooks();
    final loaded = result.when(
      ok: (books) => LibraryLoaded(books: books),
      err: LibraryError.new,
    );

    // Once per session, look for EPUBs that landed in the books directory
    // outside the in-app importer (sideloads, reinstalls). Runs after the
    // first frame so the cached list paints immediately.
    if (!_autoDiscoverScheduled && loaded is LibraryLoaded) {
      _autoDiscoverScheduled = true;
      Future.microtask(refresh);
    }

    return loaded;
  }

  /// Hard reload: throws away the in-memory state and reads the persisted
  /// catalog again. Surfaces a loading spinner — used by the error view's
  /// retry button when [build] failed.
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await _repository.listBooks();
      return result.when(
        ok: (books) => LibraryLoaded(books: books),
        err: LibraryError.new,
      );
    });
  }

  /// Streams in any EPUBs that landed in the books directory outside the
  /// in-app importer, persisting them and pushing them into the state in
  /// small batches so the user sees books appearing instead of waiting
  /// for the whole scan to finish. Doesn't toggle the loading state.
  Future<void> refresh() async {
    final dir = _booksDir;
    if (dir == null) return;

    final initial = _currentLoaded();
    final known = {for (final b in initial.books) b.filePath};
    final pending = <BookEntry>[];
    var lastFlush = DateTime.now();

    void flush() {
      if (pending.isEmpty) return;
      final current = _currentLoaded();
      final merged = [...pending, ...current.books]
        ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      state = AsyncData(current.copyWith(books: merged));
      pending.clear();
      lastFlush = DateTime.now();
    }

    await for (final entry in _importService.discoverNew(
      booksDir: dir,
      knownPaths: known,
    )) {
      final saved = await _repository.addBook(entry);
      saved.when(ok: pending.add, err: (_) {});
      // Commit at most ~5 books per batch and never sit on entries for
      // longer than 250ms — keeps the list growing smoothly without
      // rebuilding the screen on every single file.
      if (pending.length >= 5 ||
          DateTime.now().difference(lastFlush).inMilliseconds >= 250) {
        flush();
      }
    }
    flush();
  }

  Future<BookEntry?> pickAndImportEpub() async {
    final loaded = _currentLoaded();
    state = AsyncData(loaded.copyWith(importing: true, clearError: true));

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['epub'],
      withData: false,
    );
    if (picked == null || picked.files.single.path == null) {
      state = AsyncData(loaded.copyWith(importing: false));
      return null;
    }

    final result = await _importService.importEpub(
      sourcePath: picked.files.single.path!,
      booksDir: _booksDir!,
    );

    return result.when(
      ok: (entry) async {
        final saved = await _repository.addBook(entry);
        return saved.when(
          ok: (b) {
            final updated = [b, ...loaded.books.where((x) => x.id != b.id)];
            state = AsyncData(LibraryLoaded(books: updated));
            return b;
          },
          err: (e) {
            state = AsyncData(loaded.copyWith(
              importing: false,
              lastError: e,
            ));
            return null;
          },
        );
      },
      err: (e) {
        state = AsyncData(loaded.copyWith(
          importing: false,
          lastError: e,
        ));
        return null;
      },
    );
  }

  Future<void> remove(String id) async {
    final loaded = _currentLoaded();
    final result = await _repository.removeBook(id);
    state = result.when(
      ok: (_) => AsyncData(LibraryLoaded(
        books: loaded.books.where((b) => b.id != id).toList(),
      )),
      err: (e) => AsyncData(loaded.copyWith(lastError: e)),
    );
  }

  void clearError() {
    final loaded = _currentLoaded();
    state = AsyncData(loaded.copyWith(clearError: true));
  }

  LibraryLoaded _currentLoaded() {
    final value = state.value;
    if (value is LibraryLoaded) return value;
    return const LibraryLoaded(books: []);
  }
}


import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../data/import_service.dart';
import '../data/library_repository.dart';
import '../data/models/book_entry.dart';
import '../providers.dart';
import 'library_state.dart';

class LibraryViewModel extends AsyncNotifier<LibraryState> {
  late final LibraryRepository _repository;
  late final ImportService _importService;
  Directory? _booksDir;

  @override
  Future<LibraryState> build() async {
    _repository = await ref.read(libraryRepositoryProvider.future);
    _importService = ref.read(importServiceProvider);
    _booksDir = await ref.read(booksDirectoryProvider.future);

    final result = await _repository.listBooks();
    return result.when(
      ok: (books) => LibraryLoaded(books: books),
      err: LibraryError.new,
    );
  }

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


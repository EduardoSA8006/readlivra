import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/result/app_exceptions.dart';
import '../../../core/result/result.dart';
import 'library_repository.dart';
import '../../../core/models/book_entry.dart';

class SharedPrefsLibraryRepository implements LibraryRepository {
  SharedPrefsLibraryRepository(this._prefs);

  static const _key = 'library.books.v1';
  final SharedPreferences _prefs;

  @override
  Future<Result<List<BookEntry>>> listBooks() async {
    try {
      final raw = _prefs.getStringList(_key) ?? const [];
      final books = raw
          .map((s) => BookEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
      books.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      return Ok(books);
    } catch (e, s) {
      return Err(ParseException(
        'Não foi possível ler a biblioteca salva.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<BookEntry>> addBook(BookEntry entry) async {
    final current = await listBooks();
    if (current is Err<List<BookEntry>>) return Err(current.error);
    final list = (current as Ok<List<BookEntry>>).value
        .where((b) => b.id != entry.id)
        .toList()
      ..add(entry);
    return _persist(list).when(
      ok: (_) => Ok(entry),
      err: Err.new,
    );
  }

  @override
  Future<Result<void>> removeBook(String id) async {
    final current = await listBooks();
    if (current is Err<List<BookEntry>>) return Err(current.error);
    final list = (current as Ok<List<BookEntry>>).value;
    final removed = list.where((b) => b.id == id).toList();
    final remaining = list.where((b) => b.id != id).toList();

    for (final book in removed) {
      await _safeDelete(book.filePath);
      if (book.coverPath != null) await _safeDelete(book.coverPath!);
    }
    return _persist(remaining);
  }

  @override
  Future<Result<BookEntry?>> getBook(String id) async {
    final current = await listBooks();
    return current.when(
      ok: (list) {
        final found = list.where((b) => b.id == id).cast<BookEntry?>();
        return Ok(found.isEmpty ? null : found.first);
      },
      err: Err.new,
    );
  }

  Result<void> _persist(List<BookEntry> list) {
    try {
      final raw = list.map((b) => jsonEncode(b.toJson())).toList();
      _prefs.setStringList(_key, raw);
      return const Ok(null);
    } catch (e, s) {
      return Err(ParseException(
        'Não foi possível salvar a biblioteca.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best-effort: cleaning up files is a courtesy, not a guarantee.
    }
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/result/app_exceptions.dart';
import '../../../core/result/result.dart';
import 'annotations_repository.dart';
import 'models/bookmark.dart';
import 'models/highlight.dart';

class SharedPrefsAnnotationsRepository implements AnnotationsRepository {
  SharedPrefsAnnotationsRepository(this._prefs);

  static const _bookmarksKey = 'annotations.bookmarks.v1';
  static const _highlightsKey = 'annotations.highlights.v1';
  final SharedPreferences _prefs;

  Map<String, List<Bookmark>> _readBookmarks() {
    final raw = _prefs.getString(_bookmarksKey);
    if (raw == null || raw.isEmpty) return {};
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return json.map((k, v) {
      final list = (v as List<dynamic>)
          .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
          .toList();
      return MapEntry(k, list);
    });
  }

  Map<String, List<Highlight>> _readHighlights() {
    final raw = _prefs.getString(_highlightsKey);
    if (raw == null || raw.isEmpty) return {};
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return json.map((k, v) {
      final list = (v as List<dynamic>)
          .map((e) => Highlight.fromJson(e as Map<String, dynamic>))
          .toList();
      return MapEntry(k, list);
    });
  }

  Future<void> _writeBookmarks(Map<String, List<Bookmark>> data) async {
    final encoded = data.map(
      (k, v) => MapEntry(k, v.map((b) => b.toJson()).toList()),
    );
    await _prefs.setString(_bookmarksKey, jsonEncode(encoded));
  }

  Future<void> _writeHighlights(Map<String, List<Highlight>> data) async {
    final encoded = data.map(
      (k, v) => MapEntry(k, v.map((h) => h.toJson()).toList()),
    );
    await _prefs.setString(_highlightsKey, jsonEncode(encoded));
  }

  @override
  Future<Result<List<Bookmark>>> listBookmarks(String bookId) async {
    try {
      final all = _readBookmarks();
      final list = List<Bookmark>.from(all[bookId] ?? const [])
        ..sort(_byPosition);
      return Ok(list);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao ler marcadores.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<List<Highlight>>> listHighlights(String bookId) async {
    try {
      final all = _readHighlights();
      final list = List<Highlight>.from(all[bookId] ?? const [])
        ..sort(_byPosition);
      return Ok(list);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao ler destaques.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<Bookmark>> addBookmark(Bookmark bookmark) async {
    try {
      final all = _readBookmarks();
      final list = List<Bookmark>.from(all[bookmark.bookId] ?? const [])
        ..removeWhere((b) =>
            b.chapterIndex == bookmark.chapterIndex &&
            b.blockIndex == bookmark.blockIndex)
        ..add(bookmark);
      all[bookmark.bookId] = list;
      await _writeBookmarks(all);
      return Ok(bookmark);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao salvar marcador.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<Highlight>> addHighlight(Highlight highlight) async {
    try {
      final all = _readHighlights();
      final list = List<Highlight>.from(all[highlight.bookId] ?? const [])
        ..removeWhere((h) =>
            h.chapterIndex == highlight.chapterIndex &&
            h.blockIndex == highlight.blockIndex &&
            h.startOffset == highlight.startOffset &&
            h.endOffset == highlight.endOffset)
        ..add(highlight);
      all[highlight.bookId] = list;
      await _writeHighlights(all);
      return Ok(highlight);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao salvar destaque.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<void>> updateBookmarkNote(String id, String? note) async {
    try {
      final all = _readBookmarks();
      var changed = false;
      final updated = all.map((bookId, list) {
        final newList = list.map((b) {
          if (b.id != id) return b;
          changed = true;
          return b.copyWith(note: note);
        }).toList();
        return MapEntry(bookId, newList);
      });
      if (changed) await _writeBookmarks(updated);
      return const Ok(null);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao atualizar marcador.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<void>> removeBookmark(String id) async {
    try {
      final all = _readBookmarks();
      final updated = all.map(
        (bookId, list) =>
            MapEntry(bookId, list.where((b) => b.id != id).toList()),
      );
      await _writeBookmarks(updated);
      return const Ok(null);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao remover marcador.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<void>> removeHighlight(String id) async {
    try {
      final all = _readHighlights();
      final updated = all.map(
        (bookId, list) =>
            MapEntry(bookId, list.where((h) => h.id != id).toList()),
      );
      await _writeHighlights(updated);
      return const Ok(null);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao remover destaque.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<void>> removeAnnotationsAt({
    required String bookId,
    required int chapterIndex,
    required int blockIndex,
  }) async {
    try {
      final bookmarks = _readBookmarks();
      final highlights = _readHighlights();
      bookmarks[bookId] = (bookmarks[bookId] ?? const [])
          .where((b) => !(b.chapterIndex == chapterIndex &&
              b.blockIndex == blockIndex))
          .toList();
      highlights[bookId] = (highlights[bookId] ?? const [])
          .where((h) => !(h.chapterIndex == chapterIndex &&
              h.blockIndex == blockIndex))
          .toList();
      await _writeBookmarks(bookmarks);
      await _writeHighlights(highlights);
      return const Ok(null);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao remover anotações.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<void>> removeBookmarkAt({
    required String bookId,
    required int chapterIndex,
    required int blockIndex,
  }) async {
    try {
      final all = _readBookmarks();
      all[bookId] = (all[bookId] ?? const [])
          .where((b) => !(b.chapterIndex == chapterIndex &&
              b.blockIndex == blockIndex))
          .toList();
      await _writeBookmarks(all);
      return const Ok(null);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao remover marcador do bloco.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<void>> clearForBook(String bookId) async {
    try {
      final bookmarks = _readBookmarks()..remove(bookId);
      final highlights = _readHighlights()..remove(bookId);
      await _writeBookmarks(bookmarks);
      await _writeHighlights(highlights);
      return const Ok(null);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao limpar anotações do livro.',
        cause: e,
        stackTrace: s,
      ));
    }
  }
}

int _byPosition(dynamic a, dynamic b) {
  final ac = (a.chapterIndex as int).compareTo(b.chapterIndex as int);
  if (ac != 0) return ac;
  return (a.blockIndex as int).compareTo(b.blockIndex as int);
}

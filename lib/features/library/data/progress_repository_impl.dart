import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/result/app_exceptions.dart';
import '../../../core/result/result.dart';
import 'models/book_progress.dart';
import 'progress_repository.dart';

class SharedPrefsProgressRepository implements ProgressRepository {
  SharedPrefsProgressRepository(this._prefs);

  static const _progressPrefix = 'progress.book.v3.';
  static const _legacyV2Prefix = 'progress.book.v2.';
  static const _legacyChapterPrefix = 'progress.chapter.';
  static const _lastOpenedKey = 'progress.lastOpened';

  final SharedPreferences _prefs;

  @override
  Future<Result<BookProgress>> getProgress(String bookId) async {
    try {
      final v3 = _prefs.getString('$_progressPrefix$bookId');
      if (v3 != null) {
        return Ok(BookProgress.fromJson(
            jsonDecode(v3) as Map<String, dynamic>));
      }
      final v2 = _prefs.getString('$_legacyV2Prefix$bookId');
      if (v2 != null) {
        return Ok(BookProgress.fromJson(
            jsonDecode(v2) as Map<String, dynamic>));
      }
      final legacyChapter = _prefs.getInt('$_legacyChapterPrefix$bookId');
      if (legacyChapter != null) {
        return Ok(BookProgress(chapterIndex: legacyChapter));
      }
      return const Ok(BookProgress.empty);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao ler progresso.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<void>> setProgress(String bookId, BookProgress progress) async {
    try {
      final json = jsonEncode(progress.toJson());
      await _prefs.setString('$_progressPrefix$bookId', json);
      // Drop legacy entries so they don't shadow the new schema later.
      await _prefs.remove('$_legacyV2Prefix$bookId');
      await _prefs.remove('$_legacyChapterPrefix$bookId');
      return const Ok(null);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao salvar progresso.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<String?>> getLastOpenedBookId() async {
    try {
      return Ok(_prefs.getString(_lastOpenedKey));
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao ler último livro aberto.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<void>> setLastOpenedBookId(String? id) async {
    try {
      if (id == null) {
        await _prefs.remove(_lastOpenedKey);
      } else {
        await _prefs.setString(_lastOpenedKey, id);
      }
      return const Ok(null);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao registrar último livro aberto.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<void>> clear(String bookId) async {
    try {
      await _prefs.remove('$_progressPrefix$bookId');
      await _prefs.remove('$_legacyV2Prefix$bookId');
      await _prefs.remove('$_legacyChapterPrefix$bookId');
      final last = _prefs.getString(_lastOpenedKey);
      if (last == bookId) await _prefs.remove(_lastOpenedKey);
      return const Ok(null);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao limpar progresso.',
        cause: e,
        stackTrace: s,
      ));
    }
  }
}

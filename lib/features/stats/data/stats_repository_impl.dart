import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/result/app_exceptions.dart';
import '../../../core/result/result.dart';
import 'stats_repository.dart';

String dateKeyOf(DateTime d) {
  final local = d.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

DateTime? parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

class SharedPrefsStatsRepository implements StatsRepository {
  SharedPrefsStatsRepository(this._prefs);

  static const _key = 'stats.dailyByBook.v1';
  final SharedPreferences _prefs;

  Map<String, Map<String, int>> _readSync() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return json.map((bookId, value) {
      final inner = (value as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      );
      return MapEntry(bookId, inner);
    });
  }

  Future<void> _writeSync(Map<String, Map<String, int>> data) async {
    await _prefs.setString(_key, jsonEncode(data));
  }

  @override
  Future<Result<void>> addReadingTime({
    required String bookId,
    required DateTime date,
    required Duration duration,
  }) async {
    if (duration.inMilliseconds <= 0) return const Ok(null);
    try {
      final all = _readSync();
      final byDay = all.putIfAbsent(bookId, () => <String, int>{});
      final key = dateKeyOf(date);
      byDay[key] = (byDay[key] ?? 0) + duration.inMilliseconds;
      await _writeSync(all);
      return const Ok(null);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao salvar tempo de leitura.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<Map<String, Map<String, int>>>> readAll() async {
    try {
      return Ok(_readSync());
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao ler estatísticas.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<void>> clearForBook(String bookId) async {
    try {
      final all = _readSync();
      all.remove(bookId);
      await _writeSync(all);
      return const Ok(null);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao limpar estatísticas do livro.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<void>> clearAll() async {
    try {
      await _prefs.remove(_key);
      return const Ok(null);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao limpar estatísticas.',
        cause: e,
        stackTrace: s,
      ));
    }
  }
}

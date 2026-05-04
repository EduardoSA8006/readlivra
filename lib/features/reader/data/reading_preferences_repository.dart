import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/result/app_exceptions.dart';
import '../../../core/result/result.dart';
import 'models/reading_preferences.dart';

abstract class ReadingPreferencesRepository {
  Future<Result<ReadingPreferences>> get();
  Future<Result<void>> save(ReadingPreferences preferences);
}

class SharedPrefsReadingPreferencesRepository
    implements ReadingPreferencesRepository {
  SharedPrefsReadingPreferencesRepository(this._prefs);

  static const _key = 'reader.prefs.v1';
  final SharedPreferences _prefs;

  @override
  Future<Result<ReadingPreferences>> get() async {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return const Ok(ReadingPreferences.defaults);
      return Ok(ReadingPreferences.fromJson(
          jsonDecode(raw) as Map<String, dynamic>));
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao ler preferências de leitura.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<void>> save(ReadingPreferences preferences) async {
    try {
      await _prefs.setString(_key, jsonEncode(preferences.toJson()));
      return const Ok(null);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao salvar preferências de leitura.',
        cause: e,
        stackTrace: s,
      ));
    }
  }
}

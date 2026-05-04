import 'package:shared_preferences/shared_preferences.dart';

import '../result/app_exceptions.dart';
import '../result/result.dart';

abstract class AppMetaRepository {
  Future<Result<DateTime>> getInstalledAt();
}

class SharedPrefsAppMetaRepository implements AppMetaRepository {
  SharedPrefsAppMetaRepository(this._prefs);

  static const _key = 'app.installedAt';
  final SharedPreferences _prefs;

  @override
  Future<Result<DateTime>> getInstalledAt() async {
    try {
      final raw = _prefs.getString(_key);
      if (raw != null) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return Ok(parsed);
      }
      final now = DateTime.now();
      await _prefs.setString(_key, now.toIso8601String());
      return Ok(now);
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao ler data de instalação.',
        cause: e,
        stackTrace: s,
      ));
    }
  }
}

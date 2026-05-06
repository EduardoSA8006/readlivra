import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

abstract class ThemeModeRepository {
  Future<AppThemeMode> get();
  Future<void> set(AppThemeMode mode);
}

class SharedPrefsThemeModeRepository implements ThemeModeRepository {
  SharedPrefsThemeModeRepository(this._prefs);

  static const _key = 'app.themeMode.v1';
  final SharedPreferences _prefs;

  @override
  Future<AppThemeMode> get() async {
    final raw = _prefs.getString(_key);
    return _parse(raw);
  }

  @override
  Future<void> set(AppThemeMode mode) async {
    await _prefs.setString(_key, mode.name);
  }

  AppThemeMode _parse(String? raw) {
    for (final m in AppThemeMode.values) {
      if (m.name == raw) return m;
    }
    return AppThemeMode.system;
  }
}

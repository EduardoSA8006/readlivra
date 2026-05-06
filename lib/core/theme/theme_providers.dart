import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';
import 'theme_mode_repository.dart';

final themeModeRepositoryProvider =
    FutureProvider<ThemeModeRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SharedPrefsThemeModeRepository(prefs);
});

class ThemeModeNotifier extends AsyncNotifier<AppThemeMode> {
  late final ThemeModeRepository _repo;

  @override
  Future<AppThemeMode> build() async {
    _repo = await ref.read(themeModeRepositoryProvider.future);
    return _repo.get();
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = AsyncData(mode);
    await _repo.set(mode);
  }
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);

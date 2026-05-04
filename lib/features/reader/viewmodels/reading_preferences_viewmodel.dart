import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/reading_preferences.dart';
import '../data/reading_preferences_repository.dart';
import '../providers.dart';

class ReadingPreferencesViewModel
    extends AsyncNotifier<ReadingPreferences> {
  late final ReadingPreferencesRepository _repository;

  @override
  Future<ReadingPreferences> build() async {
    _repository =
        await ref.read(readingPreferencesRepositoryProvider.future);
    final result = await _repository.get();
    return result.valueOrNull ?? ReadingPreferences.defaults;
  }

  Future<void> save(ReadingPreferences preferences) async {
    state = AsyncData(preferences);
    await _repository.save(preferences);
  }

  Future<void> patch({
    ReadingFont? font,
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    double? paragraphSpacing,
  }) async {
    final current = state.value ?? ReadingPreferences.defaults;
    final next = current.copyWith(
      font: font,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      paragraphSpacing: paragraphSpacing,
    );
    await save(next);
  }

  Future<void> resetToDefaults() => save(ReadingPreferences.defaults);
}

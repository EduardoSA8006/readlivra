import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';
import 'app_meta_repository.dart';

final appMetaRepositoryProvider =
    FutureProvider<AppMetaRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SharedPrefsAppMetaRepository(prefs);
});

final installedAtProvider = FutureProvider<DateTime>((ref) async {
  final repo = await ref.watch(appMetaRepositoryProvider.future);
  final result = await repo.getInstalledAt();
  return result.valueOrNull ?? DateTime.now();
});

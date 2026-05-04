import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/storage_providers.dart';
import 'data/models/reading_summary.dart';
import 'data/reading_session_service.dart';
import 'data/stats_repository.dart';
import 'data/stats_repository_impl.dart';
import 'viewmodels/stats_viewmodel.dart';

final statsRepositoryProvider = FutureProvider<StatsRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SharedPrefsStatsRepository(prefs);
});

final readingSessionServiceProvider =
    FutureProvider<ReadingSessionService>((ref) async {
  final repo = await ref.watch(statsRepositoryProvider.future);
  final service = ReadingSessionService(
    repo,
    onSessionFlushed: () {
      ref.invalidate(statsViewModelProvider);
    },
  );
  // Best-effort flush if the service is torn down mid-session.
  ref.onDispose(() {
    service.stop();
  });
  return service;
});

final statsViewModelProvider =
    AsyncNotifierProvider<StatsViewModel, ReadingSummary>(StatsViewModel.new);

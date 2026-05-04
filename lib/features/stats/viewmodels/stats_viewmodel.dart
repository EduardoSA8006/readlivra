import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_meta/providers.dart';
import '../../library/providers.dart';
import '../data/models/reading_summary.dart';
import '../data/reading_summary_compose.dart';
import '../providers.dart';

class StatsViewModel extends AsyncNotifier<ReadingSummary> {
  @override
  Future<ReadingSummary> build() async {
    final repo = await ref.watch(statsRepositoryProvider.future);
    final installedAt = await ref.watch(installedAtProvider.future);
    // Re-evaluate when the library changes (book add/remove).
    ref.watch(libraryViewModelProvider);

    final result = await repo.readAll();
    final raw = result.valueOrNull ?? const <String, Map<String, int>>{};
    return composeReadingSummary(data: raw, installedAt: installedAt);
  }
}

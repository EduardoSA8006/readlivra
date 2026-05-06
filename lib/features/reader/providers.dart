import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/storage_providers.dart';
import '../../core/theme/reader_palette.dart';
import 'data/models/reading_preferences.dart';
import 'data/reader_repository.dart';
import 'data/reader_repository_impl.dart';
import 'data/reading_preferences_repository.dart';
import 'viewmodels/reader_state.dart';
import 'viewmodels/reader_viewmodel.dart';
import 'viewmodels/reading_preferences_viewmodel.dart';

final readerRepositoryProvider = Provider<ReaderRepository>((ref) {
  return const EpubReaderRepository();
});

final readerViewModelProvider =
    NotifierProvider<ReaderViewModel, ReaderState>(ReaderViewModel.new);

final readingPreferencesRepositoryProvider =
    FutureProvider<ReadingPreferencesRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SharedPrefsReadingPreferencesRepository(prefs);
});

final readingPreferencesProvider =
    AsyncNotifierProvider<ReadingPreferencesViewModel, ReadingPreferences>(
  ReadingPreferencesViewModel.new,
);

/// Convenience: the [ReaderPalette] currently active for the reader,
/// derived from the user's stored theme preference.
final readerPaletteProvider = Provider<ReaderPalette>((ref) {
  final prefs =
      ref.watch(readingPreferencesProvider).value ?? ReadingPreferences.defaults;
  return ReaderPalette.of(prefs.theme);
});

typedef ReadingPosition = ({
  int chapterIndex,
  int blockIndex,
  double alignment,
});

class ReadingPositionNotifier extends Notifier<ReadingPosition?> {
  @override
  ReadingPosition? build() => null;

  void update(ReadingPosition? value) => state = value;
}

/// Tracks the topmost block currently visible in the reader. The reading
/// view publishes updates as the user scrolls so the bottom bar can offer
/// a "bookmark current position" toggle.
final readingPositionProvider =
    NotifierProvider<ReadingPositionNotifier, ReadingPosition?>(
  ReadingPositionNotifier.new,
);

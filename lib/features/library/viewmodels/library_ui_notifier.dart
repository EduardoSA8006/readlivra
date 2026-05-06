import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LibrarySortMode {
  recentlyAdded('Adicionados recentemente'),
  title('Título (A–Z)'),
  author('Autor (A–Z)');

  const LibrarySortMode(this.label);
  final String label;
}

enum LibraryViewMode { grid, list }

class LibraryUiState {
  const LibraryUiState({
    this.searchVisible = false,
    this.query = '',
    this.sortMode = LibrarySortMode.recentlyAdded,
    this.viewMode = LibraryViewMode.grid,
  });

  final bool searchVisible;
  final String query;
  final LibrarySortMode sortMode;
  final LibraryViewMode viewMode;

  LibraryUiState copyWith({
    bool? searchVisible,
    String? query,
    LibrarySortMode? sortMode,
    LibraryViewMode? viewMode,
  }) =>
      LibraryUiState(
        searchVisible: searchVisible ?? this.searchVisible,
        query: query ?? this.query,
        sortMode: sortMode ?? this.sortMode,
        viewMode: viewMode ?? this.viewMode,
      );
}

class LibraryUiNotifier extends Notifier<LibraryUiState> {
  @override
  LibraryUiState build() => const LibraryUiState();

  void toggleSearch() {
    final next = !state.searchVisible;
    state = state.copyWith(
      searchVisible: next,
      // Closing the search clears the query so the list resets immediately.
      query: next ? state.query : '',
    );
  }

  void setQuery(String value) => state = state.copyWith(query: value);

  void setSortMode(LibrarySortMode mode) =>
      state = state.copyWith(sortMode: mode);

  void toggleViewMode() {
    state = state.copyWith(
      viewMode: state.viewMode == LibraryViewMode.grid
          ? LibraryViewMode.list
          : LibraryViewMode.grid,
    );
  }
}

final libraryUiProvider =
    NotifierProvider<LibraryUiNotifier, LibraryUiState>(LibraryUiNotifier.new);

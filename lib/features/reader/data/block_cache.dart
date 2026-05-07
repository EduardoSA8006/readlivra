/// Holds parsed block lists per chapter, keeping only the entries within
/// [keepAround] chapters of the most recently used index.
///
/// Pulled out of the widget so the eviction policy can be exercised in
/// unit tests without spinning up the reader.
class BlockCache {
  BlockCache({this.keepAround = 1});

  final int keepAround;
  final Map<int, List<String>> _entries = <int, List<String>>{};

  List<String>? get(int chapterIndex) => _entries[chapterIndex];

  bool contains(int chapterIndex) => _entries.containsKey(chapterIndex);

  void put(int chapterIndex, List<String> blocks) {
    _entries[chapterIndex] = blocks;
  }

  /// Removes every cached chapter that is more than [keepAround] away from
  /// [currentIndex]. Returns the indices that were evicted, so callers
  /// can release any sibling resources (e.g. the chapter HTML cached on
  /// the [EbookChapter] itself).
  List<int> evictFar(int currentIndex) {
    final keys = _entries.keys
        .where((k) => (k - currentIndex).abs() > keepAround)
        .toList(growable: false);
    for (final k in keys) {
      _entries.remove(k);
    }
    return keys;
  }

  Iterable<int> get indices => _entries.keys;
  int get size => _entries.length;

  void clear() => _entries.clear();
}

import 'dart:typed_data';

import 'package:archive/archive_io.dart';

/// Resolves embedded EPUB image bytes by their `<img src=...>` reference.
///
/// Implementations may keep bytes in memory or fetch them from the underlying
/// archive on demand — the reader UI doesn't care, it just `await`s [get].
abstract class EbookImageSource {
  /// Number of distinct images discovered in the EPUB.
  int get count;

  /// Returns the bytes for [src] (an `<img src>` value) or `null` when no
  /// matching entry exists. Implementations should match by absolute path
  /// first and fall back to the basename — chapter HTML often uses paths
  /// relative to the chapter file.
  Future<Uint8List?> get(String src);

  /// Releases any resources held by the source.
  void dispose();

  static const empty = _EmptyImageSource();
}

class _EmptyImageSource implements EbookImageSource {
  const _EmptyImageSource();

  @override
  int get count => 0;

  @override
  Future<Uint8List?> get(String src) async => null;

  @override
  void dispose() {}
}

/// Reads image bytes lazily from a parsed ZIP [Archive], caching the most
/// recently used decoded entries to keep scrolling smooth.
///
/// When the archive was constructed from a file-backed [InputFileStream],
/// pass it via [owningStream] so [dispose] can release the underlying file
/// handle once the reader is torn down.
class LazyArchiveImageSource implements EbookImageSource {
  LazyArchiveImageSource({
    required Archive archive,
    required Set<String> imagePaths,
    InputFileStream? owningStream,
    int cacheCapacity = 16,
  })  : _archive = archive,
        _imagePaths = imagePaths,
        _owningStream = owningStream,
        _normalizedIndex = _buildIndex(imagePaths),
        _cache = _LinkedLru<String, Uint8List>(cacheCapacity);

  final Archive _archive;
  final Set<String> _imagePaths;
  final InputFileStream? _owningStream;
  final Map<String, String> _normalizedIndex;
  final _LinkedLru<String, Uint8List> _cache;

  @override
  int get count => _imagePaths.length;

  @override
  Future<Uint8List?> get(String src) async {
    final path = _resolve(src);
    if (path == null) return null;
    final cached = _cache.get(path);
    if (cached != null) return cached;
    final entry = _archive.findFile(path);
    if (entry == null) return null;
    final raw = entry.content;
    final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw as List<int>);
    _cache.put(path, bytes);
    return bytes;
  }

  String? _resolve(String src) {
    if (_imagePaths.contains(src)) return src;
    final normalized = src.replaceAll('\\', '/');
    if (_imagePaths.contains(normalized)) return normalized;
    final basename = normalized.split('/').last.toLowerCase();
    if (basename.isEmpty) return null;
    return _normalizedIndex[basename];
  }

  static Map<String, String> _buildIndex(Set<String> paths) {
    final out = <String, String>{};
    for (final p in paths) {
      final name = p.split('/').last.toLowerCase();
      out.putIfAbsent(name, () => p);
    }
    return out;
  }

  @override
  void dispose() {
    _cache.clear();
    try {
      _owningStream?.closeSync();
    } catch (_) {
      // Closing the file handle is best-effort.
    }
  }
}

class _LinkedLru<K, V> {
  _LinkedLru(this.capacity);
  final int capacity;
  final Map<K, V> _map = <K, V>{};

  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) _map[key] = value;
    return value;
  }

  void put(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    if (_map.length > capacity) {
      _map.remove(_map.keys.first);
    }
  }

  void clear() => _map.clear();
}

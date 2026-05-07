import 'dart:typed_data';

import 'package:archive/archive_io.dart';

import '../../../core/models/ebook_image_source.dart';
import 'lazy_archive_chapter_source.dart';

/// Reads image bytes lazily from a parsed ZIP via an [ArchiveIndex] (so
/// hrefs that are relative to the OPF resolve to the correct archive
/// entry without per-call scanning), caching the most recently used
/// decoded bytes to keep scrolling smooth.
///
/// When the archive was constructed from a file-backed [InputFileStream],
/// pass it via [owningStream] so [dispose] can release the underlying
/// file handle once the reader is torn down.
class LazyArchiveImageSource implements EbookImageSource {
  LazyArchiveImageSource({
    required ArchiveIndex index,
    required Set<String> imagePaths,
    InputFileStream? owningStream,
    int cacheCapacity = 256,
  }) : _index = index,
       _imagePaths = imagePaths,
       _owningStream = owningStream,
       _cache = _LinkedLru<String, Uint8List>(cacheCapacity);

  final ArchiveIndex _index;
  final Set<String> _imagePaths;
  final InputFileStream? _owningStream;
  final _LinkedLru<String, Uint8List> _cache;

  @override
  int get count => _imagePaths.length;

  @override
  Future<Uint8List?> get(String src) async {
    final candidate = _normalize(src);
    if (candidate.isEmpty) return null;
    final cached = _cache.get(candidate);
    if (cached != null) return cached;
    final entry = _index.find(candidate);
    if (entry == null) return null;
    final raw = entry.content;
    final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw as List<int>);
    _cache.put(candidate, bytes);
    return bytes;
  }

  /// Strips leading `./` and `../` segments — the archive index already
  /// resolves any tail of an entry, so the relative prefix is noise.
  String _normalize(String src) {
    var s = src.replaceAll('\\', '/');
    while (s.startsWith('./')) {
      s = s.substring(2);
    }
    while (s.startsWith('../')) {
      s = s.substring(3);
    }
    return s;
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

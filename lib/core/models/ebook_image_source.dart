import 'dart:typed_data';

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

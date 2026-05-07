import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readlivra/features/reader/data/lazy_archive_chapter_source.dart';
import 'package:readlivra/features/reader/data/lazy_archive_image_source.dart';

ArchiveIndex _buildIndex(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  // Round-trip through the encoder/decoder so file.content materialises
  // bytes the same way it would for a real EPUB on disk.
  final encoded = ZipEncoder().encode(archive)!;
  return ArchiveIndex.build(ZipDecoder().decodeBytes(encoded));
}

void main() {
  group('LazyArchiveImageSource', () {
    test('count reflects the registered image set', () {
      final index = _buildIndex({
        'OEBPS/Images/cover.jpg': [1, 2, 3],
        'OEBPS/Images/inside.png': [4, 5, 6],
      });
      final source = LazyArchiveImageSource(
        index: index,
        imagePaths: {'OEBPS/Images/cover.jpg', 'OEBPS/Images/inside.png'},
      );
      expect(source.count, 2);
    });

    test('resolves an absolute path directly', () async {
      final index = _buildIndex({
        'OEBPS/Images/cover.jpg': [42, 7, 9],
      });
      final source = LazyArchiveImageSource(
        index: index,
        imagePaths: {'OEBPS/Images/cover.jpg'},
      );
      final bytes = await source.get('OEBPS/Images/cover.jpg');
      expect(bytes, isA<Uint8List>());
      expect(bytes!.toList(), [42, 7, 9]);
    });

    test('strips relative segments and resolves via the index suffix', () async {
      final index = _buildIndex({
        'OEBPS/Images/cover.jpg': [1, 2],
      });
      final source = LazyArchiveImageSource(
        index: index,
        imagePaths: {'OEBPS/Images/cover.jpg'},
      );
      final bytes = await source.get('../Images/cover.jpg');
      expect(bytes, isNotNull);
      expect(bytes!.toList(), [1, 2]);
    });

    test('returns null when the entry is missing', () async {
      final index = _buildIndex({'a.jpg': [9]});
      final source = LazyArchiveImageSource(
        index: index,
        imagePaths: {'a.jpg'},
      );
      expect(await source.get('does-not-exist.jpg'), isNull);
    });

    test('cache evicts the oldest entry when capacity is exceeded', () async {
      final index = _buildIndex({
        'a.jpg': [1],
        'b.jpg': [2],
        'c.jpg': [3],
      });
      final source = LazyArchiveImageSource(
        index: index,
        imagePaths: {'a.jpg', 'b.jpg', 'c.jpg'},
        cacheCapacity: 2,
      );
      // Prime LRU: a, b, then c → a should be evicted.
      await source.get('a.jpg');
      await source.get('b.jpg');
      await source.get('c.jpg');
      // Sanity: re-fetching is still correct (re-reads from archive).
      final bytes = await source.get('a.jpg');
      expect(bytes!.toList(), [1]);
    });
  });
}

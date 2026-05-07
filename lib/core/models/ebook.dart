import 'dart:typed_data';

import 'ebook_image_source.dart';
import 'ebook_chapter.dart';

class Ebook {
  const Ebook({
    required this.title,
    required this.author,
    required this.chapters,
    this.cover,
    this.imageSource = EbookImageSource.empty,
  });

  final String title;
  final String? author;
  final List<EbookChapter> chapters;
  final Uint8List? cover;

  /// Lazy resolver for embedded images. Replaces the older eager
  /// `Map<String, Uint8List>` so a 100 MB illustrated EPUB no longer
  /// keeps everything pinned in memory while reading.
  final EbookImageSource imageSource;

  bool get hasChapters => chapters.isNotEmpty;
  int get chapterCount => chapters.length;
  int get imageCount => imageSource.count;

  Future<Uint8List?> resolveImage(String src) => imageSource.get(src);
}

import 'dart:typed_data';

import 'ebook_chapter.dart';

class Ebook {
  const Ebook({
    required this.title,
    required this.author,
    required this.chapters,
    this.cover,
    this.images = const {},
  });

  final String title;
  final String? author;
  final List<EbookChapter> chapters;
  final Uint8List? cover;

  /// Image bytes keyed by their original path inside the EPUB
  /// (e.g. `OEBPS/Images/cover.jpg`).
  final Map<String, Uint8List> images;

  bool get hasChapters => chapters.isNotEmpty;
  int get chapterCount => chapters.length;

  /// Resolve an `<img src="...">` against the embedded image table.
  /// Falls back to a basename match because EPUB chapters often use
  /// paths relative to the chapter file (`../Images/x.jpg`).
  Uint8List? resolveImage(String src) {
    if (images.isEmpty) return null;
    final direct = images[src];
    if (direct != null) return direct;

    final normalized = src.replaceAll('\\', '/');
    final basename = normalized.split('/').last.toLowerCase();
    if (basename.isEmpty) return null;

    for (final entry in images.entries) {
      if (entry.key.toLowerCase().endsWith(basename)) return entry.value;
    }
    return null;
  }
}

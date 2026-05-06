import 'dart:convert';

import 'package:archive/archive_io.dart';

/// Loads a chapter's XHTML content on demand.
abstract class ChapterContentSource {
  Future<String> load();
}

class StaticChapterContentSource implements ChapterContentSource {
  StaticChapterContentSource(this._html);
  final String _html;

  @override
  Future<String> load() async => _html;
}

/// Reads chapter XHTML from a lazy ZIP [Archive] backed by a file stream.
/// Decoding happens only when [load] is called for the first time; the
/// caller (typically [EbookChapter]) caches the result.
class LazyArchiveChapterSource implements ChapterContentSource {
  LazyArchiveChapterSource({
    required this.archive,
    required this.path,
  });

  final Archive archive;
  final String path;

  @override
  Future<String> load() async {
    final entry = archive.findFile(path);
    if (entry == null) return '';
    final raw = entry.content;
    final bytes = raw is List<int> ? raw : (raw as dynamic) as List<int>;
    return utf8.decode(bytes, allowMalformed: true);
  }
}

import 'dart:convert';

import 'package:archive/archive_io.dart';

import '../../../core/models/chapter_content_source.dart';

/// Reads chapter XHTML from a lazy ZIP [Archive] backed by a file stream.
/// Decoding happens only when [load] is called for the first time; the
/// caller (typically [EbookChapter]) caches the result.
class LazyArchiveChapterSource implements ChapterContentSource {
  LazyArchiveChapterSource({required this.index, required this.path});

  final ArchiveIndex index;
  final String path;

  @override
  Future<String> load() async => decodeArchiveFile(index.find(path)) ?? '';
}

/// Strips a TOC `#fragment` from an EPUB path. Empty/null becomes `''`.
String stripFragment(String? path) {
  if (path == null || path.isEmpty) return '';
  final hash = path.indexOf('#');
  return hash >= 0 ? path.substring(0, hash) : path;
}

/// Constant-time path → entry index for an EPUB archive. Built once per
/// open, it tolerates the two common path quirks of EPUBs:
///
/// * a TOC `#fragment` (e.g. `chapter1.xhtml#capi1`);
/// * an OPF-relative href whose archive entry lives under the OPF
///   directory (e.g. TOC says `chapter_0096.xhtml`, archive entry is
///   `EPUB/chapter_0096.xhtml`).
///
/// Both forms map to the same entry without scanning the file list per
/// chapter — every `/`-separated suffix of each entry is indexed.
class ArchiveIndex {
  ArchiveIndex._(this._byPath);

  factory ArchiveIndex.build(Archive archive) {
    final map = <String, ArchiveFile>{};
    for (final f in archive.files) {
      if (!f.isFile) continue;
      map[f.name] = f;
      var suffix = f.name;
      while (true) {
        final slash = suffix.indexOf('/');
        if (slash < 0) break;
        suffix = suffix.substring(slash + 1);
        map.putIfAbsent(suffix, () => f);
      }
    }
    return ArchiveIndex._(map);
  }

  final Map<String, ArchiveFile> _byPath;

  ArchiveFile? find(String? path) {
    final key = stripFragment(path);
    return key.isEmpty ? null : _byPath[key];
  }
}

/// Decodes an archive entry as UTF-8, tolerating malformed bytes.
String? decodeArchiveFile(ArchiveFile? file) {
  if (file == null) return null;
  final raw = file.content;
  final bytes = raw is List<int> ? raw : (raw as dynamic) as List<int>;
  return utf8.decode(bytes, allowMalformed: true);
}

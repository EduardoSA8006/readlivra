import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart' as epubx;

import '../../../core/result/app_exceptions.dart';
import '../../../core/result/result.dart';
import '../../../core/models/book_entry.dart';

class ImportService {
  const ImportService();

  Future<Result<BookEntry>> importEpub({
    required String sourcePath,
    required Directory booksDir,
  }) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) {
        return const Err(
          FileAccessException('O arquivo selecionado não existe.'),
        );
      }
      if (!sourcePath.toLowerCase().endsWith('.epub')) {
        return const Err(
          UnsupportedFormatException('Apenas arquivos .epub são aceitos.'),
        );
      }

      final bytes = await source.readAsBytes();
      final epubBook = await epubx.EpubReader.readBook(bytes);

      final id = _buildId(sourcePath);
      final destFile = File('${booksDir.path}/$id.epub');
      await destFile.writeAsBytes(bytes, flush: true);

      String? coverPath;
      final coverBytes = _findCoverBytes(epubBook);
      if (coverBytes != null) {
        final coverFile = File('${booksDir.path}/$id.cover');
        await coverFile.writeAsBytes(coverBytes, flush: true);
        coverPath = coverFile.path;
      }

      final title = (epubBook.Title ?? '').trim().isEmpty
          ? _basenameWithoutExtension(sourcePath)
          : epubBook.Title!.trim();
      final author = (epubBook.Author ?? '').trim().isEmpty
          ? null
          : epubBook.Author!.trim();
      final chapterCount = _flatten(epubBook.Chapters ?? const []).length;

      return Ok(BookEntry(
        id: id,
        title: title,
        author: author,
        filePath: destFile.path,
        coverPath: coverPath,
        dateAdded: DateTime.now(),
        chapterCount: chapterCount,
      ));
    } on FileSystemException catch (e, s) {
      return Err(FileAccessException(
        'Falha ao copiar o arquivo para a biblioteca.',
        cause: e,
        stackTrace: s,
      ));
    } catch (e, s) {
      return Err(ParseException(
        'Falha ao importar o EPUB.',
        cause: e,
        stackTrace: s,
      ));
    }
  }

  /// Scans [booksDir] for `.epub` files not in [knownPaths], yielding a
  /// [BookEntry] per file as it's parsed. Files are left in place — this
  /// is the discovery counterpart of [importEpub], which copies an
  /// outside file in. Useful for picking up books sideloaded into the
  /// app's documents directory or after a reinstall when the catalog was
  /// cleared but the EPUBs remained on disk.
  ///
  /// Each parse yields back to the event loop so a directory of dozens of
  /// EPUBs doesn't block the UI thread for seconds at a time.
  Stream<BookEntry> discoverNew({
    required Directory booksDir,
    required Set<String> knownPaths,
  }) async* {
    if (!await booksDir.exists()) return;
    await for (final entity in booksDir.list(followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!path.toLowerCase().endsWith('.epub')) continue;
      if (knownPaths.contains(path)) continue;

      final entry = await _entryForExisting(entity, booksDir);
      if (entry != null) yield entry;
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<BookEntry?> _entryForExisting(File source, Directory booksDir) async {
    try {
      final bytes = await source.readAsBytes();
      final epubBook = await epubx.EpubReader.readBook(bytes);

      final id = _buildId(source.path);
      String? coverPath;
      final coverBytes = _findCoverBytes(epubBook);
      if (coverBytes != null) {
        final coverFile = File('${booksDir.path}/$id.cover');
        await coverFile.writeAsBytes(coverBytes, flush: true);
        coverPath = coverFile.path;
      }

      final title = (epubBook.Title ?? '').trim().isEmpty
          ? _basenameWithoutExtension(source.path)
          : epubBook.Title!.trim();
      final author = (epubBook.Author ?? '').trim().isEmpty
          ? null
          : epubBook.Author!.trim();
      final chapterCount = _flatten(epubBook.Chapters ?? const []).length;

      return BookEntry(
        id: id,
        title: title,
        author: author,
        filePath: source.path,
        coverPath: coverPath,
        dateAdded: DateTime.now(),
        chapterCount: chapterCount,
      );
    } catch (_) {
      // Skip unreadable files — discovery is best-effort.
      return null;
    }
  }

  String _buildId(String sourcePath) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final base = _basenameWithoutExtension(sourcePath)
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '${stamp}_$base';
  }

  String _basenameWithoutExtension(String path) {
    final segments = path.replaceAll('\\', '/').split('/');
    final last = segments.isEmpty ? path : segments.last;
    final dot = last.lastIndexOf('.');
    return dot <= 0 ? last : last.substring(0, dot);
  }

  Uint8List? _findCoverBytes(epubx.EpubBook book) {
    final imgs = book.Content?.Images;
    if (imgs == null || imgs.isEmpty) return null;

    for (final entry in imgs.entries) {
      if (entry.key.toLowerCase().contains('cover')) {
        final b = entry.value.Content;
        if (b != null && b.isNotEmpty) return Uint8List.fromList(b);
      }
    }
    final first = imgs.values.first.Content;
    if (first != null && first.isNotEmpty) return Uint8List.fromList(first);
    return null;
  }

  List<epubx.EpubChapter> _flatten(List<epubx.EpubChapter> input) {
    final out = <epubx.EpubChapter>[];
    for (final ch in input) {
      out.add(ch);
      final subs = ch.SubChapters;
      if (subs != null) out.addAll(_flatten(subs));
    }
    return out;
  }
}

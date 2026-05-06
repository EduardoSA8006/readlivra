import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:epubx/epubx.dart' as epubx;

import '../../../core/result/app_exceptions.dart';
import '../../../core/result/result.dart';
import 'chapter_content_source.dart';
import 'ebook_image_source.dart';
import 'models/ebook.dart';
import 'models/ebook_chapter.dart';
import 'reader_repository.dart';

class EpubReaderRepository implements ReaderRepository {
  const EpubReaderRepository();

  @override
  Future<Result<Ebook>> openEpub(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return const Err(
          FileAccessException('Arquivo não encontrado no caminho informado.'),
        );
      }

      final lower = path.toLowerCase();
      if (!lower.endsWith('.epub')) {
        return const Err(
          UnsupportedFormatException(
              'Por enquanto só arquivos .epub são suportados.'),
        );
      }

      // Use the lazy `openBook` API to list the spine + metadata without
      // materialising every chapter's HTML up-front.
      final eagerBytes = await file.readAsBytes();
      final bookRef = await epubx.EpubReader.openBook(eagerBytes);

      final title = (bookRef.Title ?? '').trim().isEmpty
          ? 'Sem título'
          : bookRef.Title!.trim();
      final author = (bookRef.Author ?? '').trim().isEmpty
          ? null
          : bookRef.Author!.trim();

      // Capture the metadata we need (title + path) and let the bookRef
      // (along with the in-memory bytes it owns) go out of scope.
      final chapterEntries =
          _flattenAndPrune(await bookRef.getChapters());

      final imagePaths = bookRef.Content?.Images?.keys.toSet();

      // Open a file-backed archive — bytes are fetched on demand from disk.
      final stream = InputFileStream(path);
      final lazyArchive = ZipDecoder().decodeBuffer(stream);

      final chapters = chapterEntries
          .map(
            (entry) => EbookChapter(
              title: entry.title,
              source: LazyArchiveChapterSource(
                archive: lazyArchive,
                path: entry.path,
              ),
            ),
          )
          .toList(growable: false);

      if (chapters.isEmpty) {
        stream.closeSync();
        return const Err(
          ParseException('EPUB não contém capítulos legíveis.'),
        );
      }

      final paths = imagePaths ??
          lazyArchive.files
              .where((f) => f.isFile && _looksLikeImage(f.name))
              .map((f) => f.name)
              .toSet();

      return Ok(
        Ebook(
          title: title,
          author: author,
          chapters: chapters,
          imageSource: LazyArchiveImageSource(
            archive: lazyArchive,
            imagePaths: paths,
            owningStream: stream,
          ),
        ),
      );
    } on FileSystemException catch (e, s) {
      return Err(
        FileAccessException(
          'Não foi possível acessar o arquivo.',
          cause: e,
          stackTrace: s,
        ),
      );
    } catch (e, s) {
      return Err(
        ParseException(
          'Falha ao interpretar o EPUB.',
          cause: e,
          stackTrace: s,
        ),
      );
    }
  }

  bool _looksLikeImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.svg');
  }

  /// Walks the (possibly nested) TOC and returns a flat list of chapter
  /// entries, dropping nodes that look like a navigation stub for their
  /// own children. A node is considered a stub when:
  ///
  /// * its [ContentFileName] matches a descendant's content file (parent
  ///   and child point to the same xhtml — parent only renders the
  ///   heading at the top of that file);
  /// * its title is a prefix of a direct child's title (e.g. "Capítulo 2"
  ///   parent whose only child is "Capítulo 2 - O Início" — the parent's
  ///   own page typically holds just the heading).
  ///
  /// In both cases the parent is omitted and the children are surfaced
  /// directly. Otherwise the parent is kept alongside its descendants.
  List<_ChapterEntry> _flattenAndPrune(List<epubx.EpubChapterRef> nodes) {
    final out = <_ChapterEntry>[];

    void walk(List<epubx.EpubChapterRef> level) {
      for (final node in level) {
        final subs = node.SubChapters ?? const <epubx.EpubChapterRef>[];
        final hasSubs = subs.isNotEmpty;
        final myFile = _baseFile(node.ContentFileName);
        final myTitle = (node.Title ?? '').trim();

        final keepSelf = myFile.isNotEmpty &&
            (!hasSubs || _shouldKeepParent(node, subs));
        if (keepSelf) {
          out.add(_ChapterEntry(
            title: myTitle.isEmpty ? 'Sem título' : myTitle,
            path: node.ContentFileName ?? '',
          ));
        }
        if (hasSubs) walk(subs);
      }
    }

    walk(nodes);
    return out;
  }

  bool _shouldKeepParent(
    epubx.EpubChapterRef parent,
    List<epubx.EpubChapterRef> children,
  ) {
    final parentFile = _baseFile(parent.ContentFileName);
    if (parentFile.isEmpty) return false;

    final descendantFiles = <String>{};
    void collect(List<epubx.EpubChapterRef> level) {
      for (final n in level) {
        final f = _baseFile(n.ContentFileName);
        if (f.isNotEmpty) descendantFiles.add(f);
        final s = n.SubChapters;
        if (s != null && s.isNotEmpty) collect(s);
      }
    }

    collect(children);
    if (descendantFiles.contains(parentFile)) return false;

    final pTitle = (parent.Title ?? '').trim().toLowerCase();
    if (pTitle.isNotEmpty) {
      for (final c in children) {
        final cTitle = (c.Title ?? '').trim().toLowerCase();
        if (cTitle.length > pTitle.length && cTitle.startsWith(pTitle)) {
          return false;
        }
      }
    }

    return true;
  }

  String _baseFile(String? path) {
    if (path == null || path.isEmpty) return '';
    final hash = path.indexOf('#');
    return hash >= 0 ? path.substring(0, hash) : path;
  }
}

class _ChapterEntry {
  const _ChapterEntry({required this.title, required this.path});
  final String title;
  final String path;
}

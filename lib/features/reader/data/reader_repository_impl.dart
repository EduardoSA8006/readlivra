import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:epubx/epubx.dart' as epubx;

import '../../../core/models/ebook.dart';
import '../../../core/models/ebook_chapter.dart';
import '../../../core/result/app_exceptions.dart';
import '../../../core/result/result.dart';
import 'lazy_archive_chapter_source.dart';
import 'lazy_archive_image_source.dart';
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

      if (!path.toLowerCase().endsWith('.epub')) {
        return const Err(
          UnsupportedFormatException(
            'Por enquanto só arquivos .epub são suportados.',
          ),
        );
      }

      final eagerBytes = await file.readAsBytes();
      final bookRef = await epubx.EpubReader.openBook(eagerBytes);

      final title = (bookRef.Title ?? '').trim().isEmpty
          ? 'Sem título'
          : bookRef.Title!.trim();
      final author = (bookRef.Author ?? '').trim().isEmpty
          ? null
          : bookRef.Author!.trim();
      final imagePaths = bookRef.Content?.Images?.keys.toSet();

      // File-backed archive: bytes are fetched on demand from disk.
      final stream = InputFileStream(path);
      final lazyArchive = ZipDecoder().decodeBuffer(stream);
      final archiveIndex = ArchiveIndex.build(lazyArchive);

      final chapterEntries = await _buildChaptersFromSpine(
        bookRef,
        archiveIndex,
      );

      final chapters = chapterEntries
          .map(
            (entry) => EbookChapter(
              title: entry.title,
              source: LazyArchiveChapterSource(
                index: archiveIndex,
                path: entry.path,
              ),
            ),
          )
          .toList(growable: false);

      if (chapters.isEmpty) {
        stream.closeSync();
        return const Err(ParseException('EPUB não contém capítulos legíveis.'));
      }

      final paths =
          imagePaths ??
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
            index: archiveIndex,
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
        ParseException('Falha ao interpretar o EPUB.', cause: e, stackTrace: s),
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

  /// Builds the chapter list from the OPF spine, which is the canonical
  /// reading order in EPUB. Title labels are pulled from the TOC where
  /// available and otherwise derived from the file name. Nothing is
  /// pruned: every spine xhtml — covers, illustration inserts, table of
  /// contents pages, "chapter 2 part 2" continuations, etc. — shows up so
  /// the reader sees exactly what the publisher shipped.
  Future<List<_ChapterEntry>> _buildChaptersFromSpine(
    epubx.EpubBookRef bookRef,
    ArchiveIndex index,
  ) async {
    final pkg = bookRef.Schema?.Package;
    if (pkg == null) return const [];
    final manifest = pkg.Manifest?.Items ?? const <epubx.EpubManifestItem>[];
    final spine = pkg.Spine?.Items ?? const <epubx.EpubSpineItemRef>[];

    final manifestById = <String, epubx.EpubManifestItem>{
      for (final item in manifest)
        if (item.Id != null) item.Id!: item,
    };

    // Resolve TOC entries to canonical archive paths so labels survive
    // hrefs that are relative to the NCX/nav doc rather than the OPF.
    final labelByArchivePath = <String, String>{};
    void absorbToc(List<epubx.EpubChapterRef>? nodes) {
      if (nodes == null) return;
      for (final node in nodes) {
        final candidate = stripFragment(node.ContentFileName);
        final title = (node.Title ?? '').trim();
        final hit = index.find(candidate);
        if (hit != null && title.isNotEmpty) {
          labelByArchivePath.putIfAbsent(hit.name, () => title);
        }
        absorbToc(node.SubChapters);
      }
    }

    absorbToc(await bookRef.getChapters());

    final entries = <_ChapterEntry>[];
    var counter = 0;
    for (final ref in spine) {
      final id = ref.IdRef;
      if (id == null) continue;
      final item = manifestById[id];
      if (item == null) continue;

      final media = (item.MediaType ?? '').toLowerCase();
      if (media.isNotEmpty && !media.contains('html')) continue;

      final href = item.Href;
      if (href == null || href.isEmpty) continue;

      final entry = index.find(href);
      if (entry == null) continue;

      counter += 1;
      final label =
          labelByArchivePath[entry.name] ?? _deriveTitle(entry.name, counter);
      entries.add(_ChapterEntry(title: label, path: entry.name));
    }
    return entries;
  }

  String _deriveTitle(String archivePath, int index) {
    final slash = archivePath.lastIndexOf('/');
    final base = slash >= 0 ? archivePath.substring(slash + 1) : archivePath;
    final dot = base.lastIndexOf('.');
    final stem = (dot > 0 ? base.substring(0, dot) : base)
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim();
    return stem.isEmpty ? 'Capítulo $index' : stem;
  }
}

class _ChapterEntry {
  const _ChapterEntry({required this.title, required this.path});
  final String title;
  final String path;
}

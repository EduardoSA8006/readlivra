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

      final chapterRefs =
          _flattenChapterRefs(await bookRef.getChapters());

      // Capture the metadata we need (title + path) and let the bookRef
      // (along with the in-memory bytes it owns) go out of scope.
      final chapterEntries = chapterRefs
          .where((c) =>
              (c.ContentFileName ?? '').isNotEmpty &&
              (c.Title ?? '').trim().isNotEmpty || true)
          .map((c) => _ChapterEntry(
                title: (c.Title ?? '').trim().isEmpty
                    ? 'Sem título'
                    : c.Title!.trim(),
                path: c.ContentFileName ?? '',
              ))
          .where((e) => e.path.isNotEmpty)
          .toList(growable: false);

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

  List<epubx.EpubChapterRef> _flattenChapterRefs(
      List<epubx.EpubChapterRef> input) {
    final out = <epubx.EpubChapterRef>[];
    for (final ch in input) {
      out.add(ch);
      final subs = ch.SubChapters;
      if (subs != null && subs.isNotEmpty) {
        out.addAll(_flattenChapterRefs(subs));
      }
    }
    return out;
  }
}

class _ChapterEntry {
  const _ChapterEntry({required this.title, required this.path});
  final String title;
  final String path;
}

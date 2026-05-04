import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart' as epubx;

import '../../../core/result/app_exceptions.dart';
import '../../../core/result/result.dart';
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

      final bytes = await file.readAsBytes();
      final epubBook = await epubx.EpubReader.readBook(bytes);

      final flat = _flattenChapters(epubBook.Chapters ?? const []);
      final chapters = flat
          .map(
            (c) => EbookChapter(
              title: (c.Title ?? '').trim().isEmpty
                  ? 'Sem título'
                  : c.Title!.trim(),
              htmlContent: c.HtmlContent ?? '',
            ),
          )
          .where((c) => c.htmlContent.isNotEmpty)
          .toList(growable: false);

      if (chapters.isEmpty) {
        return const Err(
          ParseException('EPUB não contém capítulos legíveis.'),
        );
      }

      final title = (epubBook.Title ?? '').trim().isEmpty
          ? 'Sem título'
          : epubBook.Title!.trim();
      final author = (epubBook.Author ?? '').trim().isEmpty
          ? null
          : epubBook.Author!.trim();

      return Ok(
        Ebook(
          title: title,
          author: author,
          chapters: chapters,
          images: _extractImages(epubBook),
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

  Map<String, Uint8List> _extractImages(epubx.EpubBook book) {
    final out = <String, Uint8List>{};
    final imgs = book.Content?.Images;
    if (imgs == null) return out;
    for (final entry in imgs.entries) {
      final bytes = entry.value.Content;
      if (bytes != null && bytes.isNotEmpty) {
        out[entry.key] = Uint8List.fromList(bytes);
      }
    }
    return out;
  }

  List<epubx.EpubChapter> _flattenChapters(List<epubx.EpubChapter> input) {
    final out = <epubx.EpubChapter>[];
    for (final ch in input) {
      out.add(ch);
      final subs = ch.SubChapters;
      if (subs != null && subs.isNotEmpty) {
        out.addAll(_flattenChapters(subs));
      }
    }
    return out;
  }
}

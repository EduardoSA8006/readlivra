import 'package:flutter/material.dart';

import '../core/models/ebook.dart';
import '../features/library/screens/book_detail_screen.dart';
import '../features/library/screens/book_toc_screen.dart';
import '../features/reader/screens/reader_screen.dart';

/// Centralized cross-feature navigation. Features push routes via
/// [AppRoutes] instead of importing each other's screens directly, so the
/// dependency graph between features stays a tree (only the app shell
/// knows everyone).
class AppRoutes {
  AppRoutes._();

  static Route<void> reader({
    String? bookId,
    String? path,
    int? initialChapter,
    int? initialAnchorBlock,
    double? initialAnchorAlignment,
  }) => MaterialPageRoute(
    builder: (_) => ReaderScreen(
      bookId: bookId,
      path: path,
      initialChapter: initialChapter,
      initialAnchorBlock: initialAnchorBlock,
      initialAnchorAlignment: initialAnchorAlignment,
    ),
  );

  static Route<void> bookDetail({required String bookId}) =>
      MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: bookId));

  static Route<void> bookToc({
    required String bookId,
    required String filePath,
    required String bookTitle,
    required String? author,
    required Ebook ebook,
    required int currentChapter,
  }) => MaterialPageRoute(
    builder: (_) => BookTocScreen(
      bookId: bookId,
      filePath: filePath,
      bookTitle: bookTitle,
      author: author,
      ebook: ebook,
      currentChapter: currentChapter,
    ),
  );
}

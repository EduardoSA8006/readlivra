import 'package:flutter_test/flutter_test.dart';
import 'package:readlivra/features/library/data/annotations_repository_impl.dart';
import 'package:readlivra/core/models/bookmark.dart';
import 'package:readlivra/core/models/highlight.dart';
import 'package:shared_preferences/shared_preferences.dart';

Bookmark _bookmark(String id, {int chapter = 0, int block = 0}) => Bookmark(
      id: id,
      bookId: 'b1',
      chapterIndex: chapter,
      blockIndex: block,
      blockAlignment: 0,
      snippet: 'snippet $id',
      createdAt: DateTime(2026, 5, 4),
    );

Highlight _highlight(
  String id, {
  int chapter = 0,
  int block = 0,
  HighlightColor color = HighlightColor.yellow,
}) =>
    Highlight(
      id: id,
      bookId: 'b1',
      chapterIndex: chapter,
      blockIndex: block,
      snippet: 'snippet $id',
      color: color,
      createdAt: DateTime(2026, 5, 4),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('listBookmarks returns empty when nothing was stored', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPrefsAnnotationsRepository(prefs);
    final list = (await repo.listBookmarks('b1')).valueOrNull!;
    expect(list, isEmpty);
  });

  test('addBookmark persists and is sorted by chapter/block', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPrefsAnnotationsRepository(prefs);

    await repo.addBookmark(_bookmark('a', chapter: 1, block: 5));
    await repo.addBookmark(_bookmark('b', chapter: 0, block: 2));
    await repo.addBookmark(_bookmark('c', chapter: 1, block: 1));

    final list = (await repo.listBookmarks('b1')).valueOrNull!;
    expect(list.map((e) => e.id), ['b', 'c', 'a']);
  });

  test('addBookmark replaces existing bookmark on the same block', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPrefsAnnotationsRepository(prefs);

    await repo.addBookmark(_bookmark('first', chapter: 0, block: 1));
    await repo.addBookmark(_bookmark('second', chapter: 0, block: 1));

    final list = (await repo.listBookmarks('b1')).valueOrNull!;
    expect(list.length, 1);
    expect(list.single.id, 'second');
  });

  test('updateBookmarkNote rewrites the matching entry', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPrefsAnnotationsRepository(prefs);

    await repo.addBookmark(_bookmark('a'));
    await repo.updateBookmarkNote('a', 'lembrete');

    final list = (await repo.listBookmarks('b1')).valueOrNull!;
    expect(list.single.note, 'lembrete');
  });

  test('removeAnnotationsAt clears bookmark + highlight on a block',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPrefsAnnotationsRepository(prefs);

    await repo.addBookmark(_bookmark('a', chapter: 1, block: 7));
    await repo.addHighlight(_highlight('h', chapter: 1, block: 7));
    await repo.addBookmark(_bookmark('b', chapter: 1, block: 8));

    await repo.removeAnnotationsAt(
        bookId: 'b1', chapterIndex: 1, blockIndex: 7);

    final bookmarks = (await repo.listBookmarks('b1')).valueOrNull!;
    final highlights = (await repo.listHighlights('b1')).valueOrNull!;
    expect(bookmarks.map((e) => e.id), ['b']);
    expect(highlights, isEmpty);
  });

  test('clearForBook removes all annotations for a single book', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPrefsAnnotationsRepository(prefs);

    await repo.addBookmark(_bookmark('a'));
    await repo.addHighlight(_highlight('h'));
    await repo.clearForBook('b1');

    expect((await repo.listBookmarks('b1')).valueOrNull, isEmpty);
    expect((await repo.listHighlights('b1')).valueOrNull, isEmpty);
  });
}

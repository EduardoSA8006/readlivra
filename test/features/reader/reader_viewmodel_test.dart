import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readlivra/core/result/app_exceptions.dart';
import 'package:readlivra/core/result/result.dart';
import 'package:readlivra/core/models/ebook.dart';
import 'package:readlivra/core/models/ebook_chapter.dart';
import 'package:readlivra/features/reader/data/reader_repository.dart';
import 'package:readlivra/features/reader/providers.dart';
import 'package:readlivra/features/reader/viewmodels/reader_state.dart';
import 'package:readlivra/features/reader/viewmodels/reader_viewmodel.dart';

class _FakeRepository implements ReaderRepository {
  _FakeRepository(this._result);
  final Result<Ebook> _result;

  @override
  Future<Result<Ebook>> openEpub(String path) async => _result;
}

Ebook _ebookWithChapters(int n) => Ebook(
      title: 'Livro',
      author: 'Autor',
      chapters: List.generate(
        n,
        (i) => EbookChapter(
            title: 'Cap ${i + 1}', htmlContent: '<p>conteúdo $i</p>'),
      ),
    );

void main() {
  ReaderViewModel readerVm(ProviderContainer c) =>
      c.read(readerViewModelProvider.notifier);
  ReaderState readerState(ProviderContainer c) =>
      c.read(readerViewModelProvider);

  ProviderContainer makeContainer(ReaderRepository repo) {
    final c = ProviderContainer(overrides: [
      readerRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('starts at ReaderIdle', () {
    final c = makeContainer(_FakeRepository(Ok(_ebookWithChapters(2))));
    expect(readerState(c), isA<ReaderIdle>());
  });

  test('openEpub success → ReaderReading at chapter 0', () async {
    final c = makeContainer(_FakeRepository(Ok(_ebookWithChapters(3))));
    await readerVm(c).openEpub('/fake.epub');

    final s = readerState(c);
    expect(s, isA<ReaderReading>());
    final r = s as ReaderReading;
    expect(r.chapterIndex, 0);
    expect(r.ebook.chapterCount, 3);
    expect(r.hasPrevious, false);
    expect(r.hasNext, true);
  });

  test('openEpub failure → ReaderError carries the AppException', () async {
    const err = ParseException('boom');
    final c = makeContainer(_FakeRepository(const Err(err)));
    await readerVm(c).openEpub('/fake.epub');

    final s = readerState(c);
    expect(s, isA<ReaderError>());
    expect((s as ReaderError).error, same(err));
  });

  test('nextChapter advances; previousChapter retreats; bounded', () async {
    final c = makeContainer(_FakeRepository(Ok(_ebookWithChapters(2))));
    await readerVm(c).openEpub('/fake.epub');

    readerVm(c).nextChapter();
    expect((readerState(c) as ReaderReading).chapterIndex, 1);

    readerVm(c).nextChapter();
    expect((readerState(c) as ReaderReading).chapterIndex, 1);

    readerVm(c).previousChapter();
    expect((readerState(c) as ReaderReading).chapterIndex, 0);

    readerVm(c).previousChapter();
    expect((readerState(c) as ReaderReading).chapterIndex, 0);
  });

  test('close resets to ReaderIdle', () async {
    final c = makeContainer(_FakeRepository(Ok(_ebookWithChapters(1))));
    await readerVm(c).openEpub('/fake.epub');
    readerVm(c).close();
    expect(readerState(c), isA<ReaderIdle>());
  });
}

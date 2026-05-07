import 'package:flutter_test/flutter_test.dart';
import 'package:readlivra/features/reader/data/chapter_blocks.dart';
import 'package:readlivra/features/stats/data/reading_session_service.dart';
import 'package:readlivra/features/stats/data/reading_summary_compose.dart';
import 'package:readlivra/features/stats/data/date_keys.dart';
import 'package:readlivra/features/stats/data/stats_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SharedPrefsStatsRepository', () {
    test('addReadingTime accumulates per book/day', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsStatsRepository(prefs);
      final today = DateTime.now();

      await repo.addReadingTime(
        bookId: 'b1',
        date: today,
        duration: const Duration(seconds: 30),
      );
      await repo.addReadingTime(
        bookId: 'b1',
        date: today,
        duration: const Duration(seconds: 15),
      );
      await repo.addReadingTime(
        bookId: 'b2',
        date: today,
        duration: const Duration(seconds: 5),
      );

      final all = (await repo.readAll()).valueOrNull!;
      expect(all['b1']![dateKeyOf(today)], 45000);
      expect(all['b2']![dateKeyOf(today)], 5000);
    });

    test('clearForBook removes only the requested book', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsStatsRepository(prefs);
      final now = DateTime.now();

      await repo.addReadingTime(
          bookId: 'b1', date: now, duration: const Duration(seconds: 10));
      await repo.addReadingTime(
          bookId: 'b2', date: now, duration: const Duration(seconds: 20));

      await repo.clearForBook('b1');
      final all = (await repo.readAll()).valueOrNull!;
      expect(all.containsKey('b1'), false);
      expect(all['b2'], isNotNull);
    });

    test('zero/negative duration is ignored', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsStatsRepository(prefs);
      await repo.addReadingTime(
          bookId: 'b1',
          date: DateTime.now(),
          duration: Duration.zero);
      final all = (await repo.readAll()).valueOrNull!;
      expect(all.isEmpty, true);
    });
  });

  group('ReadingSessionService', () {
    test('start → stop persists positive duration', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsStatsRepository(prefs);
      final service = ReadingSessionService(repo);

      await service.start('b1');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await service.stop();

      final all = (await repo.readAll()).valueOrNull!;
      final ms = all['b1']![dateKeyOf(DateTime.now())] ?? 0;
      expect(ms, greaterThanOrEqualTo(1000));
      expect(ms, lessThan(3000));
    });

    test('pause stops counting wall time', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsStatsRepository(prefs);
      final service = ReadingSessionService(repo);

      await service.start('b1');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await service.pause();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      service.resume();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await service.stop();

      final all = (await repo.readAll()).valueOrNull!;
      final ms = all['b1']?[dateKeyOf(DateTime.now())] ?? 0;
      expect(ms, lessThan(700));
    });

    test('starting a different book finalizes the previous session',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsStatsRepository(prefs);
      final service = ReadingSessionService(repo);

      await service.start('b1');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await service.start('b2');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await service.stop();

      final all = (await repo.readAll()).valueOrNull!;
      expect(all['b1'], isNotNull);
      expect(all['b2'], isNotNull);
    });

    test('incremental flush persists data while session is still active',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsStatsRepository(prefs);
      final service = ReadingSessionService(
        repo,
        flushInterval: const Duration(milliseconds: 100),
        minFlushDelta: const Duration(milliseconds: 50),
      );

      await service.start('b1');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      // No stop yet — without incremental flush this would be empty.
      final mid = (await repo.readAll()).valueOrNull!;
      final loggedBeforeStop =
          mid['b1']?[dateKeyOf(DateTime.now())] ?? 0;
      expect(loggedBeforeStop, greaterThan(0));

      await service.stop();
      final after = (await repo.readAll()).valueOrNull!;
      expect(
        after['b1']![dateKeyOf(DateTime.now())]!,
        greaterThanOrEqualTo(loggedBeforeStop),
      );
    });

    test('segment that crosses local midnight is split between days',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsStatsRepository(prefs);

      // Mock clock starts 5 minutes before midnight; advances on every read.
      var current = DateTime(2026, 5, 4, 23, 55);
      DateTime clock() => current;

      final service = ReadingSessionService(
        repo,
        clock: clock,
        flushInterval: const Duration(seconds: 1),
        minFlushDelta: const Duration(seconds: 1),
      );

      await service.start('b1');
      // Move 10 minutes into the future, crossing midnight.
      current = current.add(const Duration(minutes: 10));
      await service.stop();

      final all = (await repo.readAll()).valueOrNull!;
      final may4 = all['b1']!['2026-05-04']!;
      final may5 = all['b1']!['2026-05-05']!;
      // 5 minutes on each side
      expect(may4, 5 * 60 * 1000);
      expect(may5, 5 * 60 * 1000);
    });

    test('a sub-threshold segment is skipped on flush but kept for next tick',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsStatsRepository(prefs);
      final service = ReadingSessionService(
        repo,
        flushInterval: const Duration(milliseconds: 50),
        minFlushDelta: const Duration(milliseconds: 200),
      );

      await service.start('b1');
      // Several flushInterval ticks elapse without ever hitting the
      // threshold individually — the segment should keep accumulating
      // and eventually flush as a single chunk.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await service.stop();

      final all = (await repo.readAll()).valueOrNull!;
      final logged = all['b1']?[dateKeyOf(DateTime.now())] ?? 0;
      expect(logged, greaterThanOrEqualTo(200));
    });
  });

  group('composeReadingSummary timezone handling', () {
    test('streak anchors at local today when records are in the past', () {
      final today = DateTime(2026, 5, 4);
      final data = {
        'b1': {
          dateKeyOf(today): 60000,
          dateKeyOf(today.subtract(const Duration(days: 1))): 60000,
          dateKeyOf(today.subtract(const Duration(days: 2))): 60000,
          dateKeyOf(today.subtract(const Duration(days: 4))): 60000,
        },
      };
      final summary = composeReadingSummary(
        data: data,
        installedAt: DateTime(2026, 1, 1),
        now: today,
      );
      expect(summary.currentStreak, 3);
      expect(summary.activeDays, 4);
    });

    test('streak survives travelling to an earlier timezone', () {
      // User is in Tokyo and reads on May 5 → record key 2026-05-05.
      // Then flies to São Paulo where local "now" is still May 4.
      // The streak should still count May 5 as the anchor day.
      final localNowAfterTravel = DateTime(2026, 5, 4, 23, 0);
      final data = {
        'b1': {
          '2026-05-05': 30 * 60 * 1000,
          '2026-05-04': 30 * 60 * 1000,
          '2026-05-03': 30 * 60 * 1000,
        },
      };
      final summary = composeReadingSummary(
        data: data,
        installedAt: DateTime(2026, 1, 1),
        now: localNowAfterTravel,
      );
      expect(summary.currentStreak, 3);
      expect(summary.today.inMilliseconds, 30 * 60 * 1000);
    });

    test('streak is broken when there is a gap before local today', () {
      final today = DateTime(2026, 5, 4);
      final data = {
        'b1': {
          dateKeyOf(today.subtract(const Duration(days: 3))): 60000,
          dateKeyOf(today.subtract(const Duration(days: 2))): 60000,
        },
      };
      final summary = composeReadingSummary(
        data: data,
        installedAt: DateTime(2026, 1, 1),
        now: today,
      );
      expect(summary.currentStreak, 0);
      expect(summary.activeDays, 2);
    });
  });

  group('splitChapterIntoBlocks', () {
    test('splits body children into one block per top-level element', () {
      const html = '''
<html><body>
  <h1>Capítulo</h1>
  <p>Parágrafo 1.</p>
  <p>Parágrafo 2.</p>
  <img src="x.jpg" />
</body></html>
''';
      final blocks = splitChapterIntoBlocks(html);
      expect(blocks.length, 4);
      expect(blocks.first, contains('<h1>'));
      expect(blocks.last, contains('<img'));
    });

    test('returns the original html as a single block when no body', () {
      const html = '<p>Solto</p>';
      final blocks = splitChapterIntoBlocks(html);
      expect(blocks, isNotEmpty);
      expect(blocks.first, contains('Solto'));
    });

    test('treats raw text nodes as paragraphs', () {
      const html = '<html><body>texto direto</body></html>';
      final blocks = splitChapterIntoBlocks(html);
      expect(blocks, ['<p>texto direto</p>']);
    });
  });
}

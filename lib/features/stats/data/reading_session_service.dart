import 'dart:async';

import 'stats_repository.dart';

typedef Clock = DateTime Function();

/// Tracks active reading time for a single book at a time.
///
/// Time is recorded incrementally so a crash mid-session loses at most
/// [flushInterval]. Each open segment between [start]/[resume] and
/// [pause]/[stop] is broken up by a periodic ticker that flushes the elapsed
/// duration to [StatsRepository] and resets the segment's start instant.
///
/// Segments that span local midnight are split per calendar day so each
/// day's bucket gets credited for the time actually read on it.
///
/// Flushes whose total elapsed time is shorter than [minFlushDelta] are
/// skipped — the segment continues to accumulate against the same start
/// instant until the next tick.
class ReadingSessionService {
  ReadingSessionService(
    this._repository, {
    this.onSessionFlushed,
    this.flushInterval = const Duration(seconds: 30),
    this.minFlushDelta = const Duration(seconds: 1),
    Clock? clock,
  }) : _clock = clock ?? DateTime.now;

  final StatsRepository _repository;
  final void Function()? onSessionFlushed;
  final Duration flushInterval;
  final Duration minFlushDelta;
  final Clock _clock;

  String? _bookId;
  DateTime? _segmentStart;
  bool _paused = false;
  Timer? _ticker;

  String? get currentBookId => _bookId;
  bool get isActive => _bookId != null && !_paused;

  Future<void> start(String bookId) async {
    if (_bookId == bookId) {
      if (_paused) resume();
      return;
    }
    if (_bookId != null) await stop();
    _bookId = bookId;
    _segmentStart = _clock();
    _paused = false;
    _ticker?.cancel();
    _ticker = Timer.periodic(flushInterval, (_) => _flushSegment());
  }

  Future<void> pause() async {
    if (_bookId == null || _paused) return;
    await _flushSegment(keepRunning: false);
    _paused = true;
  }

  void resume() {
    if (_bookId == null || !_paused) return;
    _segmentStart = _clock();
    _paused = false;
  }

  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    if (_bookId == null) {
      _reset();
      return;
    }
    await _flushSegment(keepRunning: false);
    _reset();
  }

  /// Visible for testing — invokes the same flush path the periodic ticker
  /// would.
  Future<void> tick() => _flushSegment();

  Future<void> _flushSegment({bool keepRunning = true}) async {
    final id = _bookId;
    final start = _segmentStart;
    if (id == null || start == null || _paused) {
      if (!keepRunning) _segmentStart = null;
      return;
    }
    final now = _clock();
    final delta = now.difference(start);
    if (delta < minFlushDelta) {
      if (!keepRunning) _segmentStart = null;
      return;
    }

    var cursor = start;
    var didWrite = false;
    while (true) {
      final dayStart = DateTime(cursor.year, cursor.month, cursor.day);
      final nextMidnight = dayStart.add(const Duration(days: 1));
      if (!nextMidnight.isAfter(now)) {
        final slice = nextMidnight.difference(cursor);
        if (slice > Duration.zero) {
          await _repository.addReadingTime(
            bookId: id,
            date: cursor,
            duration: slice,
          );
          didWrite = true;
        }
        cursor = nextMidnight;
      } else {
        final slice = now.difference(cursor);
        if (slice > Duration.zero) {
          await _repository.addReadingTime(
            bookId: id,
            date: cursor,
            duration: slice,
          );
          didWrite = true;
        }
        break;
      }
    }

    if (didWrite) onSessionFlushed?.call();
    _segmentStart = keepRunning ? now : null;
  }

  void _reset() {
    _bookId = null;
    _segmentStart = null;
    _paused = false;
  }
}

import 'dart:async';
import 'dart:isolate';

import 'chapter_blocks.dart';

/// Long-lived isolate that splits chapter HTML into block lists. Replaces
/// per-call `compute()` so each chapter navigation doesn't pay the
/// ~50–200ms cost of spawning a fresh isolate.
class ChapterParserWorker {
  ChapterParserWorker._(this._sendPort, this._isolate);

  final SendPort _sendPort;
  final Isolate _isolate;

  static Future<ChapterParserWorker> spawn() async {
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(
      _entrypoint,
      ready.sendPort,
      debugName: 'chapter-parser',
    );
    final sendPort = await ready.first as SendPort;
    ready.close();
    return ChapterParserWorker._(sendPort, isolate);
  }

  Future<List<String>> split(String html) {
    final reply = ReceivePort();
    _sendPort.send([html, reply.sendPort]);
    return reply.first.then((value) {
      reply.close();
      return List<String>.from(value as List);
    });
  }

  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
  }

  static void _entrypoint(SendPort hello) {
    final inbox = ReceivePort();
    hello.send(inbox.sendPort);
    inbox.listen((message) {
      final job = message as List;
      final html = job[0] as String;
      final reply = job[1] as SendPort;
      try {
        reply.send(splitChapterIntoBlocks(html));
      } catch (_) {
        reply.send(const <String>[]);
      }
    });
  }
}

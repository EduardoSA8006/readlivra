/// Loads a chapter's XHTML content on demand. Implementations may keep
/// the html in memory or fetch it from disk lazily — callers don't care.
abstract class ChapterContentSource {
  Future<String> load();
}

class StaticChapterContentSource implements ChapterContentSource {
  StaticChapterContentSource(this._html);
  final String _html;

  @override
  Future<String> load() async => _html;
}

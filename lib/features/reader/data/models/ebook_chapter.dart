import '../chapter_content_source.dart';

class EbookChapter {
  EbookChapter({
    required this.title,
    String htmlContent = '',
    ChapterContentSource? source,
  })  : _eagerHtml = htmlContent.isEmpty ? null : htmlContent,
        _source = source;

  final String title;
  final String? _eagerHtml;
  final ChapterContentSource? _source;
  String? _cache;

  /// Loads the chapter's XHTML, returning the cached value on subsequent
  /// calls. Eager content (passed via [htmlContent] in the constructor)
  /// is returned immediately; lazy content is fetched from [_source].
  Future<String> loadHtml() async {
    if (_cache != null) return _cache!;
    if (_eagerHtml != null) return _cache = _eagerHtml;
    if (_source != null) return _cache = await _source.load();
    return '';
  }

  /// Synchronous access to whichever HTML is available without waiting on
  /// I/O. Returns `''` if the chapter hasn't been loaded yet and was built
  /// with a lazy source.
  String get htmlContent => _cache ?? _eagerHtml ?? '';
}

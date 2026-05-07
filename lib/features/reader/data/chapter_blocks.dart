import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Extracts the visible plain text from an HTML block, collapsing whitespace
/// and trimming. Useful for previews and bookmark snippets.
String blockSnippet(String html, {int maxChars = 120}) {
  final fragment = html_parser.parseFragment(html);
  final raw = fragment.text ?? '';
  final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.length <= maxChars) return collapsed;
  return '${collapsed.substring(0, maxChars).trimRight()}…';
}

/// Wrapper elements that don't carry semantic value of their own — the
/// splitter descends into them and emits their children as blocks. Lists,
/// tables, blockquotes etc. are intentionally NOT here: those convey
/// structure that needs to render as a single unit.
const _wrapperTags = {
  'div',
  'section',
  'article',
  'main',
  'header',
  'footer',
};

/// Splits a chapter's XHTML into "blocks" — paragraphs, headings, images,
/// tables, etc. Generic wrapper elements (`div`, `section`, …) are
/// transparently descended into so a chapter wrapped in
/// `<div class="content">…</div>` produces one block per real paragraph
/// instead of one giant block that flutter_html struggles to render.
///
/// Block indices double as scroll anchors for progress persistence — they
/// survive font, screen size and image-loading variations far better than
/// a raw pixel offset.
List<String> splitChapterIntoBlocks(String html) {
  if (html.trim().isEmpty) return const [];
  final document = html_parser.parse(html);
  final body = document.body;
  if (body == null) return [html];

  // Strip inline `text-align: …` declarations from every styled element.
  // flutter_html honours inline `text-align: justify` and renders the
  // text at zero height for some EPUBs (Shadow Slave). Leaving alignment
  // entirely to the reader's preference also matches user expectation.
  final alignRule = RegExp(
    r'text-align\s*:\s*[^;]+;?\s*',
    caseSensitive: false,
  );
  for (final el in body.querySelectorAll('[style]')) {
    final raw = el.attributes['style'] ?? '';
    final cleaned = raw.replaceAll(alignRule, '').trim();
    if (cleaned.isEmpty) {
      el.attributes.remove('style');
    } else {
      el.attributes['style'] = cleaned;
    }
  }

  final blocks = <String>[];
  void walk(dom.Node node) {
    if (node is dom.Element) {
      final tag = node.localName?.toLowerCase() ?? '';
      if (_wrapperTags.contains(tag)) {
        for (final child in node.nodes) {
          walk(child);
        }
        return;
      }
      final hasText = node.text.trim().isNotEmpty;
      final hasMedia = tag == 'img' || node.querySelector('img') != null;
      final isBreak = tag == 'hr' || tag == 'br';
      if (!hasText && !hasMedia && !isBreak) return;
      blocks.add(node.outerHtml);
    } else if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isNotEmpty) blocks.add('<p>$text</p>');
    }
  }

  for (final node in body.nodes) {
    walk(node);
  }
  if (blocks.isEmpty) blocks.add(html);
  return blocks;
}

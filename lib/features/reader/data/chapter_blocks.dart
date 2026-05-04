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

/// Splits a chapter's XHTML into top-level "blocks" — paragraphs, headings,
/// images, tables, etc. The reader uses these blocks as anchors for
/// resilient scroll position persistence: a block index survives font, screen
/// size and image-loading variations far better than a raw scroll offset.
List<String> splitChapterIntoBlocks(String html) {
  if (html.trim().isEmpty) return const [];
  final document = html_parser.parse(html);
  final body = document.body;
  if (body == null) return [html];

  final blocks = <String>[];
  for (final node in body.nodes) {
    if (node is dom.Element) {
      blocks.add(node.outerHtml);
    } else if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isNotEmpty) blocks.add('<p>$text</p>');
    }
  }
  if (blocks.isEmpty) blocks.add(html);
  return blocks;
}

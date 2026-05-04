import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class HighlightRange {
  const HighlightRange({
    required this.start,
    required this.end,
    required this.backgroundArgb,
    required this.accentArgb,
  });

  final int start;
  final int end;
  final int backgroundArgb;
  final int accentArgb;
}

/// Plain text concatenation of all text nodes in the same order they
/// appear in the DOM. This is the reference text used for offset math
/// when persisting highlight ranges.
String blockPlainText(String html) {
  final fragment = html_parser.parseFragment(html);
  return fragment.text ?? '';
}

/// Wraps each [HighlightRange] in a `<mark>` element painted with the
/// requested background. Offsets refer to the plain-text concatenation
/// returned by [blockPlainText]. Overlapping ranges are merged in
/// document order — the first to start wins.
String wrapHighlights(String html, List<HighlightRange> ranges) {
  if (ranges.isEmpty) return html;

  final cleaned = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
  final disjoint = <HighlightRange>[];
  for (final r in cleaned) {
    if (r.end <= r.start) continue;
    if (disjoint.isNotEmpty && r.start < disjoint.last.end) continue;
    disjoint.add(r);
  }
  if (disjoint.isEmpty) return html;

  final fragment = html_parser.parseFragment(html);
  var consumed = 0;
  var rangeIdx = 0;

  void processText(dom.Text node) {
    if (rangeIdx >= disjoint.length) {
      consumed += node.text.length;
      return;
    }
    final text = node.text;
    final nodeStart = consumed;
    final nodeEnd = consumed + text.length;
    final splits = <(int, int, HighlightRange)>[];

    while (rangeIdx < disjoint.length) {
      final r = disjoint[rangeIdx];
      if (r.start >= nodeEnd) break;

      final localStart = (r.start - nodeStart).clamp(0, text.length);
      final localEnd = (r.end - nodeStart).clamp(0, text.length);
      if (localEnd > localStart) {
        splits.add((localStart, localEnd, r));
      }
      if (r.end <= nodeEnd) {
        rangeIdx++;
      } else {
        break;
      }
    }

    if (splits.isNotEmpty) {
      final parent = node.parent;
      if (parent != null) {
        final newNodes = <dom.Node>[];
        var cursor = 0;
        for (final s in splits) {
          final start = s.$1;
          final end = s.$2;
          final r = s.$3;
          if (start > cursor) {
            newNodes.add(dom.Text(text.substring(cursor, start)));
          }
          final mark = dom.Element.tag('mark');
          mark.attributes['style'] =
              'background-color: ${_hex(r.backgroundArgb, alpha: 0.5)}; '
              'border-bottom: 1.5px solid ${_hex(r.accentArgb)};';
          mark.append(dom.Text(text.substring(start, end)));
          newNodes.add(mark);
          cursor = end;
        }
        if (cursor < text.length) {
          newNodes.add(dom.Text(text.substring(cursor)));
        }
        final idx = parent.nodes.indexOf(node);
        parent.nodes.removeAt(idx);
        parent.nodes.insertAll(idx, newNodes);
      }
    }

    consumed += text.length;
  }

  void walk(dom.Node node) {
    if (rangeIdx >= disjoint.length) return;
    if (node is dom.Text) {
      processText(node);
    } else if (node is dom.Element || node is dom.DocumentFragment) {
      final children = [...node.nodes];
      for (final c in children) {
        walk(c);
      }
    }
  }

  walk(fragment);
  return fragment.outerHtml;
}

String _hex(int argb, {double? alpha}) {
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  if (alpha != null) {
    return 'rgba($r, $g, $b, ${alpha.toStringAsFixed(2)})';
  }
  return '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}';
}

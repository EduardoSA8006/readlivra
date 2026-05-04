import 'package:flutter_test/flutter_test.dart';
import 'package:readlivra/features/reader/data/highlight_renderer.dart';

HighlightRange _r(int start, int end) =>
    HighlightRange(start: start, end: end, backgroundArgb: 0xFFFFE58A, accentArgb: 0xFFE0723A);

void main() {
  group('blockPlainText', () {
    test('concatenates text nodes preserving order', () {
      const html = '<p>Era uma <em>vez</em> um leitor.</p>';
      expect(blockPlainText(html), 'Era uma vez um leitor.');
    });

    test('returns empty string for empty fragment', () {
      expect(blockPlainText(''), '');
    });
  });

  group('wrapHighlights', () {
    test('returns input unchanged when there are no ranges', () {
      const html = '<p>Hello world</p>';
      expect(wrapHighlights(html, const []), html);
    });

    test('wraps a range that lies entirely inside one text node', () {
      const html = '<p>Hello world</p>';
      final result = wrapHighlights(html, [_r(6, 11)]);
      expect(result, contains('Hello '));
      expect(result, contains('<mark'));
      expect(result, contains('>world</mark>'));
    });

    test('preserves nested inline tags around the highlighted span', () {
      const html = '<p>Era uma <em>vez</em> um leitor.</p>';
      // "vez um" — bytes 8..14 in plain text "Era uma vez um leitor."
      final plain = blockPlainText(html);
      final start = plain.indexOf('vez um');
      final end = start + 'vez um'.length;
      final result = wrapHighlights(html, [_r(start, end)]);
      expect(result, contains('<em>'));
      expect(result, contains('<mark'));
      // The original <em> wrapping must still be present somewhere
      expect(result, contains('vez'));
      expect(result, contains('um'));
    });

    test('handles multiple disjoint ranges', () {
      const html = '<p>abc def ghi</p>';
      final result = wrapHighlights(html, [_r(0, 3), _r(8, 11)]);
      // Two <mark> tags
      final markCount = '<mark'.allMatches(result).length;
      expect(markCount, 2);
    });

    test('drops zero-length and overlapping ranges deterministically', () {
      const html = '<p>abcdef</p>';
      // Overlapping pair: first wins
      final result =
          wrapHighlights(html, [_r(0, 4), _r(2, 6), _r(5, 5)]);
      final markCount = '<mark'.allMatches(result).length;
      expect(markCount, 1);
    });
  });
}

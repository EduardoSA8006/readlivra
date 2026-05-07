import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'models/reading_preferences.dart';
import 'reader_palette.dart';

/// Result of trying to render a chapter block without flutter_html.
class SimpleBlock {
  const SimpleBlock(this.widget);
  final Widget widget;
}

/// Tags allowed inside a "simple" block. Anything outside this set forces
/// the caller to fall back to the full flutter_html renderer.
const _allowedRoots = {'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'hr', 'br'};
const _allowedInline = {
  'em',
  'i',
  'strong',
  'b',
  'u',
  'span',
  'br',
  'sup',
  'sub',
  'small',
};

/// Tries to render a chapter block as a flat `Text.rich` (or a divider for
/// `<hr>`). Returns null when the block contains anything other than
/// plain inline markup — in that case the caller should fall back to
/// flutter_html, which handles the heavyweight cases (images, tables,
/// lists, etc.).
SimpleBlock? tryBuildSimpleBlock({
  required String html,
  required ReadingPreferences prefs,
  required ReaderPalette palette,
  required String? fontFamily,
  required TextAlign bodyAlign,
  required TextAlign headingAlign,
}) {
  final fragment = html_parser.parseFragment(html);
  final root = fragment.children.isEmpty ? null : fragment.children.first;
  if (root == null) return null;

  final tag = root.localName?.toLowerCase() ?? '';
  if (!_allowedRoots.contains(tag)) return null;

  if (tag == 'hr') {
    return SimpleBlock(
      Padding(
        padding: EdgeInsets.symmetric(vertical: prefs.paragraphSpacing / 2),
        child: Divider(
          color: palette.textSecondary.withValues(alpha: 0.4),
          height: 1,
          thickness: 1,
        ),
      ),
    );
  }

  if (tag == 'br') {
    return SimpleBlock(SizedBox(height: prefs.fontSize * prefs.lineHeight));
  }

  // Heading sizes proportional to body font, matching common ebook taste.
  final isHeading = tag.startsWith('h');
  final scale = switch (tag) {
    'h1' => 1.7,
    'h2' => 1.45,
    'h3' => 1.25,
    'h4' => 1.15,
    'h5' => 1.05,
    'h6' => 1.0,
    _ => 1.0,
  };

  final baseStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: prefs.fontSize * scale,
    color: palette.textPrimary,
    height: prefs.lineHeight,
    letterSpacing: prefs.letterSpacing,
    fontWeight: isHeading ? FontWeight.w700 : FontWeight.normal,
  );

  final spans = <InlineSpan>[];
  for (final node in root.nodes) {
    final span = _toSpan(node, baseStyle);
    if (span == null) return null;
    spans.add(span);
  }

  final align = isHeading ? headingAlign : bodyAlign;

  return SimpleBlock(
    Padding(
      padding: isHeading
          ? EdgeInsets.only(
              top: prefs.paragraphSpacing,
              bottom: prefs.paragraphSpacing / 2,
            )
          : EdgeInsets.only(bottom: prefs.paragraphSpacing),
      child: Text.rich(
        TextSpan(style: baseStyle, children: spans),
        textAlign: align,
      ),
    ),
  );
}

InlineSpan? _toSpan(dom.Node node, TextStyle base) {
  if (node is dom.Text) {
    final text = node.text;
    if (text.isEmpty) return const TextSpan(text: '');
    return TextSpan(text: _decodeEntities(text));
  }
  if (node is dom.Element) {
    final tag = node.localName?.toLowerCase() ?? '';
    if (!_allowedInline.contains(tag)) return null;
    if (tag == 'br') return const TextSpan(text: '\n');

    TextStyle? overlay;
    switch (tag) {
      case 'em':
      case 'i':
        overlay = const TextStyle(fontStyle: FontStyle.italic);
      case 'strong':
      case 'b':
        overlay = const TextStyle(fontWeight: FontWeight.w700);
      case 'u':
        overlay = const TextStyle(decoration: TextDecoration.underline);
      case 'small':
        overlay = TextStyle(fontSize: base.fontSize! * 0.85);
      case 'sup':
        overlay = TextStyle(
          fontSize: base.fontSize! * 0.75,
          textBaseline: TextBaseline.alphabetic,
        );
      case 'sub':
        overlay = TextStyle(
          fontSize: base.fontSize! * 0.75,
          textBaseline: TextBaseline.alphabetic,
        );
      case 'span':
        overlay = null;
    }

    final children = <InlineSpan>[];
    for (final child in node.nodes) {
      final span = _toSpan(child, overlay == null ? base : base.merge(overlay));
      if (span == null) return null;
      children.add(span);
    }
    return TextSpan(style: overlay, children: children);
  }
  return const TextSpan(text: '');
}

/// `package:html` already decodes entities into their unicode form when
/// constructing Text nodes, so this is just a no-op alias kept in case we
/// ever feed in raw strings.
String _decodeEntities(String s) => s;

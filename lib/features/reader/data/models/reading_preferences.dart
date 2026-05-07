enum ReadingFont {
  systemSerif('Padrão (serif)', 'systemSerif'),
  systemSans('Padrão (sans)', 'systemSans'),
  merriweather('Merriweather', 'merriweather'),
  lora('Lora', 'lora'),
  ptSerif('PT Serif', 'ptSerif'),
  inter('Inter', 'inter'),
  openSans('Open Sans', 'openSans');

  const ReadingFont(this.label, this.id);
  final String label;
  final String id;

  static ReadingFont fromId(String? id) {
    for (final f in ReadingFont.values) {
      if (f.id == id) return f;
    }
    return ReadingFont.systemSerif;
  }
}

enum ReadingTheme {
  light('Claro', 'light'),
  sepia('Sépia', 'sepia'),
  dark('Escuro', 'dark');

  const ReadingTheme(this.label, this.id);
  final String label;
  final String id;

  static ReadingTheme fromId(String? id) {
    for (final t in ReadingTheme.values) {
      if (t.id == id) return t;
    }
    return ReadingTheme.light;
  }
}

enum ReadingTextAlign {
  left('Esquerda', 'left'),
  center('Centro', 'center'),
  right('Direita', 'right'),
  justify('Justificado', 'justify');

  const ReadingTextAlign(this.label, this.id);
  final String label;
  final String id;

  static ReadingTextAlign fromId(String? id) {
    for (final a in ReadingTextAlign.values) {
      if (a.id == id) return a;
    }
    return ReadingTextAlign.left;
  }
}

class ReadingPreferences {
  const ReadingPreferences({
    required this.theme,
    required this.font,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.paragraphSpacing,
    required this.textAlign,
    required this.centerHeadings,
  });

  final ReadingTheme theme;
  final ReadingFont font;

  /// Body font size in logical pixels.
  final double fontSize;

  /// Line height as a multiplier (1.0 = compact, 2.0 = airy).
  final double lineHeight;

  /// Tracking applied to every glyph, in logical pixels (negative tightens).
  final double letterSpacing;

  /// Bottom margin applied to each `<p>` block, in logical pixels.
  final double paragraphSpacing;

  /// Horizontal alignment applied to body paragraphs.
  final ReadingTextAlign textAlign;

  /// When true, headings (h1–h6) stay centered regardless of [textAlign].
  final bool centerHeadings;

  static const defaults = ReadingPreferences(
    theme: ReadingTheme.light,
    font: ReadingFont.systemSerif,
    fontSize: 17,
    lineHeight: 1.55,
    letterSpacing: 0,
    paragraphSpacing: 14,
    textAlign: ReadingTextAlign.left,
    centerHeadings: true,
  );

  // Sane bounds the UI uses to clamp slider values.
  static const fontSizeRange = (min: 12.0, max: 28.0);
  static const lineHeightRange = (min: 1.1, max: 2.2);
  static const letterSpacingRange = (min: -0.5, max: 3.0);
  static const paragraphSpacingRange = (min: 0.0, max: 36.0);

  ReadingPreferences copyWith({
    ReadingTheme? theme,
    ReadingFont? font,
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    double? paragraphSpacing,
    ReadingTextAlign? textAlign,
    bool? centerHeadings,
  }) => ReadingPreferences(
    theme: theme ?? this.theme,
    font: font ?? this.font,
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
    textAlign: textAlign ?? this.textAlign,
    centerHeadings: centerHeadings ?? this.centerHeadings,
  );

  Map<String, dynamic> toJson() => {
    'theme': theme.id,
    'font': font.id,
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'letterSpacing': letterSpacing,
    'paragraphSpacing': paragraphSpacing,
    'textAlign': textAlign.id,
    'centerHeadings': centerHeadings,
  };

  factory ReadingPreferences.fromJson(Map<String, dynamic> json) {
    return ReadingPreferences(
      theme: ReadingTheme.fromId(json['theme'] as String?),
      font: ReadingFont.fromId(json['font'] as String?),
      fontSize: ((json['fontSize'] as num?)?.toDouble() ?? defaults.fontSize)
          .clamp(fontSizeRange.min, fontSizeRange.max),
      lineHeight:
          ((json['lineHeight'] as num?)?.toDouble() ?? defaults.lineHeight)
              .clamp(lineHeightRange.min, lineHeightRange.max),
      letterSpacing:
          ((json['letterSpacing'] as num?)?.toDouble() ??
                  defaults.letterSpacing)
              .clamp(letterSpacingRange.min, letterSpacingRange.max),
      paragraphSpacing:
          ((json['paragraphSpacing'] as num?)?.toDouble() ??
                  defaults.paragraphSpacing)
              .clamp(paragraphSpacingRange.min, paragraphSpacingRange.max),
      textAlign: ReadingTextAlign.fromId(json['textAlign'] as String?),
      centerHeadings:
          (json['centerHeadings'] as bool?) ?? defaults.centerHeadings,
    );
  }
}

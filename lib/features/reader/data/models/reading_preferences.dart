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

class ReadingPreferences {
  const ReadingPreferences({
    required this.theme,
    required this.font,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.paragraphSpacing,
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

  static const defaults = ReadingPreferences(
    theme: ReadingTheme.light,
    font: ReadingFont.systemSerif,
    fontSize: 17,
    lineHeight: 1.55,
    letterSpacing: 0,
    paragraphSpacing: 14,
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
  }) =>
      ReadingPreferences(
        theme: theme ?? this.theme,
        font: font ?? this.font,
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        letterSpacing: letterSpacing ?? this.letterSpacing,
        paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme.id,
        'font': font.id,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'letterSpacing': letterSpacing,
        'paragraphSpacing': paragraphSpacing,
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
      letterSpacing: ((json['letterSpacing'] as num?)?.toDouble() ??
              defaults.letterSpacing)
          .clamp(letterSpacingRange.min, letterSpacingRange.max),
      paragraphSpacing: ((json['paragraphSpacing'] as num?)?.toDouble() ??
              defaults.paragraphSpacing)
          .clamp(paragraphSpacingRange.min, paragraphSpacingRange.max),
    );
  }
}

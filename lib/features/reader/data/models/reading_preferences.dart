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

class ReadingPreferences {
  const ReadingPreferences({
    required this.font,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.paragraphSpacing,
  });

  /// Font family used to render EPUB content.
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
    ReadingFont? font,
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    double? paragraphSpacing,
  }) =>
      ReadingPreferences(
        font: font ?? this.font,
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        letterSpacing: letterSpacing ?? this.letterSpacing,
        paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      );

  Map<String, dynamic> toJson() => {
        'font': font.id,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'letterSpacing': letterSpacing,
        'paragraphSpacing': paragraphSpacing,
      };

  factory ReadingPreferences.fromJson(Map<String, dynamic> json) {
    return ReadingPreferences(
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

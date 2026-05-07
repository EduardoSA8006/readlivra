class BookProgress {
  const BookProgress({
    required this.chapterIndex,
    this.blockIndex = 0,
    this.blockAlignment = 0.0,
    this.updatedAt,
  });

  final int chapterIndex;

  /// Index of the top-level HTML block within the chapter the user is
  /// currently looking at. Survives font, screen and image-loading changes.
  final int blockIndex;

  /// Where inside [blockIndex] the leading edge of the viewport is, as a
  /// 0..1 fraction. 0 means the block's top is at the viewport top.
  final double blockAlignment;

  final DateTime? updatedAt;

  static const empty = BookProgress(chapterIndex: 0);

  bool get hasAnchor => blockIndex > 0 || blockAlignment > 0;

  BookProgress copyWith({
    int? chapterIndex,
    int? blockIndex,
    double? blockAlignment,
    DateTime? updatedAt,
  }) =>
      BookProgress(
        chapterIndex: chapterIndex ?? this.chapterIndex,
        blockIndex: blockIndex ?? this.blockIndex,
        blockAlignment: blockAlignment ?? this.blockAlignment,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'chapterIndex': chapterIndex,
        'blockIndex': blockIndex,
        'blockAlignment': blockAlignment,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory BookProgress.fromJson(Map<String, dynamic> json) {
    final chapter = (json['chapterIndex'] as num?)?.toInt() ?? 0;

    // v3 schema (current)
    if (json.containsKey('blockIndex')) {
      return BookProgress(
        chapterIndex: chapter,
        blockIndex: (json['blockIndex'] as num?)?.toInt() ?? 0,
        blockAlignment:
            ((json['blockAlignment'] as num?)?.toDouble() ?? 0.0)
                .clamp(0.0, 1.0),
        updatedAt: json['updatedAt'] is String
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );
    }

    // v2 fallback: scrollFraction → approximate as alignment of block 0.
    final legacyFraction =
        (json['scrollFraction'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0;
    return BookProgress(
      chapterIndex: chapter,
      blockIndex: 0,
      blockAlignment: legacyFraction,
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

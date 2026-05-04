enum HighlightColor {
  yellow('Amarelo', 0xFFFFE58A, 0xFFE0723A),
  mint('Menta', 0xFFB7E4C7, 0xFF2F8F5A),
  sky('Céu', 0xFFB7DCEE, 0xFF2C6E8F),
  peach('Pêssego', 0xFFF6C6A8, 0xFFB35454);

  const HighlightColor(this.label, this.background, this.accent);
  final String label;
  final int background;
  final int accent;

  static HighlightColor fromId(String? id) {
    for (final v in HighlightColor.values) {
      if (v.name == id) return v;
    }
    return HighlightColor.yellow;
  }
}

class Highlight {
  const Highlight({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.blockIndex,
    required this.snippet,
    required this.color,
    required this.createdAt,
    this.startOffset,
    this.endOffset,
  });

  final String id;
  final String bookId;
  final int chapterIndex;
  final int blockIndex;
  final String snippet;
  final HighlightColor color;
  final DateTime createdAt;

  /// Plain-text offset (inclusive) inside the block where the highlight
  /// starts. `null` means "the whole block is highlighted" (legacy +
  /// fallback for situations where the user destacou um bloco inteiro).
  final int? startOffset;

  /// Plain-text offset (exclusive) inside the block.
  final int? endOffset;

  bool get isWholeBlock => startOffset == null || endOffset == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'chapterIndex': chapterIndex,
        'blockIndex': blockIndex,
        'snippet': snippet,
        'color': color.name,
        'createdAt': createdAt.toIso8601String(),
        if (startOffset != null) 'startOffset': startOffset,
        if (endOffset != null) 'endOffset': endOffset,
      };

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
        id: json['id'] as String,
        bookId: json['bookId'] as String,
        chapterIndex: (json['chapterIndex'] as num).toInt(),
        blockIndex: (json['blockIndex'] as num).toInt(),
        snippet: json['snippet'] as String,
        color: HighlightColor.fromId(json['color'] as String?),
        createdAt: DateTime.parse(json['createdAt'] as String),
        startOffset: (json['startOffset'] as num?)?.toInt(),
        endOffset: (json['endOffset'] as num?)?.toInt(),
      );
}

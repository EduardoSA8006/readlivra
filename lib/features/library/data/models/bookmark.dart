class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.blockIndex,
    required this.blockAlignment,
    required this.snippet,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String bookId;
  final int chapterIndex;
  final int blockIndex;
  final double blockAlignment;
  final String snippet;
  final String? note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'chapterIndex': chapterIndex,
        'blockIndex': blockIndex,
        'blockAlignment': blockAlignment,
        'snippet': snippet,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: json['id'] as String,
        bookId: json['bookId'] as String,
        chapterIndex: (json['chapterIndex'] as num).toInt(),
        blockIndex: (json['blockIndex'] as num).toInt(),
        blockAlignment: (json['blockAlignment'] as num).toDouble(),
        snippet: json['snippet'] as String,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Bookmark copyWith({String? note}) => Bookmark(
        id: id,
        bookId: bookId,
        chapterIndex: chapterIndex,
        blockIndex: blockIndex,
        blockAlignment: blockAlignment,
        snippet: snippet,
        createdAt: createdAt,
        note: note ?? this.note,
      );
}

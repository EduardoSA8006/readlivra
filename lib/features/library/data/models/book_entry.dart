class BookEntry {
  const BookEntry({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.dateAdded,
    this.coverPath,
    this.chapterCount,
  });

  final String id;
  final String title;
  final String? author;
  final String filePath;
  final String? coverPath;
  final DateTime dateAdded;
  final int? chapterCount;

  BookEntry copyWith({
    String? title,
    String? author,
    String? coverPath,
    int? chapterCount,
  }) =>
      BookEntry(
        id: id,
        title: title ?? this.title,
        author: author ?? this.author,
        filePath: filePath,
        dateAdded: dateAdded,
        coverPath: coverPath ?? this.coverPath,
        chapterCount: chapterCount ?? this.chapterCount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'filePath': filePath,
        'coverPath': coverPath,
        'dateAdded': dateAdded.toIso8601String(),
        'chapterCount': chapterCount,
      };

  factory BookEntry.fromJson(Map<String, dynamic> json) => BookEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        author: json['author'] as String?,
        filePath: json['filePath'] as String,
        coverPath: json['coverPath'] as String?,
        dateAdded: DateTime.parse(json['dateAdded'] as String),
        chapterCount: json['chapterCount'] as int?,
      );
}

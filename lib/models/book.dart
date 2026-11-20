import 'dart:convert';

enum BookFormat { epub, pdf, txt, unknown }

extension BookFormatX on BookFormat {
  String get label => name.toUpperCase();
  static BookFormat fromExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'epub':
        return BookFormat.epub;
      case 'pdf':
        return BookFormat.pdf;
      case 'txt':
        return BookFormat.txt;
      default:
        return BookFormat.unknown;
    }
  }
}

class Book {
  final String id;
  final String title;
  final String author;
  final String filePath; // local copy inside app documents
  final BookFormat format;
  String shelfId;
  double progress; // 0.0 - 1.0
  int lastPage;
  int totalPages;
  int lastOpenedMillis;
  final int addedAtMillis;
  final List<int> bookmarks; // page indexes
  final List<Highlight> highlights;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.format,
    required this.shelfId,
    this.progress = 0,
    this.lastPage = 0,
    this.totalPages = 1,
    this.lastOpenedMillis = 0,
    required this.addedAtMillis,
    List<int>? bookmarks,
    List<Highlight>? highlights,
  })  : bookmarks = bookmarks ?? [],
        highlights = highlights ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'filePath': filePath,
        'format': format.name,
        'shelfId': shelfId,
        'progress': progress,
        'lastPage': lastPage,
        'totalPages': totalPages,
        'lastOpenedMillis': lastOpenedMillis,
        'addedAtMillis': addedAtMillis,
        'bookmarks': bookmarks,
        'highlights': highlights.map((h) => h.toJson()).toList(),
      };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        title: j['title'] as String,
        author: (j['author'] as String?) ?? 'Unknown author',
        filePath: j['filePath'] as String,
        format: BookFormat.values.firstWhere(
          (f) => f.name == j['format'],
          orElse: () => BookFormat.unknown,
        ),
        shelfId: j['shelfId'] as String,
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        lastPage: (j['lastPage'] as num?)?.toInt() ?? 0,
        totalPages: (j['totalPages'] as num?)?.toInt() ?? 1,
        lastOpenedMillis: (j['lastOpenedMillis'] as num?)?.toInt() ?? 0,
        addedAtMillis: (j['addedAtMillis'] as num?)?.toInt() ?? 0,
        bookmarks: ((j['bookmarks'] as List?) ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
        highlights: ((j['highlights'] as List?) ?? [])
            .map((e) => Highlight.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String toJsonString() => jsonEncode(toJson());
  static Book fromJsonString(String s) =>
      Book.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

class Highlight {
  final int page;
  final String snippet;
  final int createdAtMillis;
  Highlight({required this.page, required this.snippet, required this.createdAtMillis});
  Map<String, dynamic> toJson() => {
        'page': page,
        'snippet': snippet,
        'createdAtMillis': createdAtMillis,
      };
  factory Highlight.fromJson(Map<String, dynamic> j) => Highlight(
        page: (j['page'] as num).toInt(),
        snippet: j['snippet'] as String,
        createdAtMillis: (j['createdAtMillis'] as num).toInt(),
      );
}

class Shelf {
  final String id;
  final String name;
  final bool isDefault;
  Shelf({required this.id, required this.name, this.isDefault = false});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'isDefault': isDefault};
  factory Shelf.fromJson(Map<String, dynamic> j) => Shelf(
        id: j['id'] as String,
        name: j['name'] as String,
        isDefault: (j['isDefault'] as bool?) ?? false,
      );
}

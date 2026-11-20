import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';

class LibraryService extends ChangeNotifier {
  static const _booksKey = 'books_v1';
  static const _shelvesKey = 'shelves_v1';
  static const _seededKey = 'seeded_v1';

  List<Book> books = [];
  List<Shelf> shelves = [];
  bool loaded = false;

  List<Shelf> get defaultShelves => shelves.where((s) => s.isDefault).toList();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final shelfJson = prefs.getString(_shelvesKey);
    if (shelfJson != null) {
      shelves = (jsonDecode(shelfJson) as List)
          .map((e) => Shelf.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      shelves = [
        Shelf(id: 'reading', name: 'Currently Reading', isDefault: true),
        Shelf(id: 'want', name: 'Want to Read', isDefault: true),
        Shelf(id: 'finished', name: 'Finished', isDefault: true),
        Shelf(id: 'favourites', name: 'Favourites', isDefault: true),
      ];
    }
    final bookJson = prefs.getString(_booksKey);
    if (bookJson != null) {
      books = (jsonDecode(bookJson) as List)
          .map((e) => Book.fromJson(e as Map<String, dynamic>))
          .toList();
      // Drop entries whose file was deleted outside the app.
      books = books.where((b) => File(b.filePath).existsSync()).toList();
    }
    loaded = true;
    if (prefs.getBool(_seededKey) != true) {
      await _seedSampleBooks();
      await prefs.setBool(_seededKey, true);
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _booksKey, jsonEncode(books.map((b) => b.toJson()).toList()));
    await prefs.setString(
        _shelvesKey, jsonEncode(shelves.map((s) => s.toJson()).toList()));
  }

  Future<Directory> get _booksDir async {
    final dir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${dir.path}/books');
    if (!await booksDir.exists()) await booksDir.create(recursive: true);
    return booksDir;
  }

  Future<void> _seedSampleBooks() async {
    final dir = await _booksDir;
    final samples = [
      ('The Library at Dusk', 'Muse (sample story)', 'the-library-at-dusk.txt'),
      ('Pride and Prejudice (Excerpt)', 'Jane Austen', 'pride-and-prejudice.txt'),
    ];
    for (final (title, author, asset) in samples) {
      try {
        final data = await rootBundle.load('assets/sample_books/$asset');
        final file = File('${dir.path}/$asset');
        await file.writeAsBytes(data.buffer.asUint8List());
        books.add(Book(
          id: 'sample-$asset',
          title: title,
          author: author,
          filePath: file.path,
          format: BookFormat.txt,
          shelfId: 'want',
          addedAtMillis: DateTime.now().millisecondsSinceEpoch,
        ));
      } catch (_) {
        // A missing sample must not break first launch.
      }
    }
    await _save();
  }

  Future<String?> importBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf', 'txt'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return null;
    final picked = File(result.files.single.path!);
    final format = BookFormatX.fromExtension(picked.path);
    if (format == BookFormat.unknown) return 'Unsupported file type.';
    final dir = await _booksDir;
    final baseName = picked.path.split('/').last;
    final dest = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$baseName');
    await picked.copy(dest.path);
    final title = baseName.replaceAll(RegExp(r'\.(epub|pdf|txt)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    books.add(Book(
      id: 'book-${DateTime.now().millisecondsSinceEpoch}',
      title: title.isEmpty ? baseName : title,
      author: 'Unknown author',
      filePath: dest.path,
      format: format,
      shelfId: 'want',
      addedAtMillis: DateTime.now().millisecondsSinceEpoch,
    ));
    await _save();
    notifyListeners();
    return null;
  }

  Future<void> addShelf(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    shelves.add(Shelf(id: 'shelf-${DateTime.now().millisecondsSinceEpoch}', name: clean));
    await _save();
    notifyListeners();
  }

  Future<void> moveBook(Book book, String shelfId) async {
    book.shelfId = shelfId;
    await _save();
    notifyListeners();
  }

  Future<void> deleteBook(Book book) async {
    books.removeWhere((b) => b.id == book.id);
    try {
      final f = File(book.filePath);
      if (await f.exists() && !book.id.startsWith('sample-')) await f.delete();
    } catch (_) {}
    await _save();
    notifyListeners();
  }

  Future<void> updateProgress(Book book) async {
    book.lastOpenedMillis = DateTime.now().millisecondsSinceEpoch;
    await _save();
    notifyListeners();
  }

  Future<void> toggleBookmark(Book book, int page) async {
    if (book.bookmarks.contains(page)) {
      book.bookmarks.remove(page);
    } else {
      book.bookmarks.add(page);
    }
    book.bookmarks.sort();
    await _save();
    notifyListeners();
  }

  Future<void> addHighlight(Book book, int page, String snippet) async {
    book.highlights.add(Highlight(
      page: page,
      snippet: snippet,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    ));
    await _save();
    notifyListeners();
  }

  List<Book> booksOnShelf(String shelfId) =>
      books.where((b) => b.shelfId == shelfId).toList();

  List<Book> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return books;
    return books
        .where((b) =>
            b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q))
        .toList();
  }
}

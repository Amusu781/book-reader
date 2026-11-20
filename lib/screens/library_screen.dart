import 'package:flutter/material.dart';
import '../config.dart';
import '../models/book.dart';
import '../services/library_service.dart';
import '../widgets/bookshelf.dart';
import '../widgets/library_background.dart';
import 'pdf_reader_screen.dart';
import 'reader_screen.dart';

enum SortMode { manual, title, author, recent, progress }

enum BookFilter { all, continueReading, currentlyReading, finished, notStarted }

extension on BookFilter {
  String get label {
    switch (this) {
      case BookFilter.all:
        return 'All books';
      case BookFilter.continueReading:
        return 'Continue reading';
      case BookFilter.currentlyReading:
        return 'Currently reading';
      case BookFilter.finished:
        return 'Finished';
      case BookFilter.notStarted:
        return 'Not started';
    }
  }

  /// Progress 0 = not started, between 0 and 1 = reading, 1 = finished.
  bool matches(Book book) {
    switch (this) {
      case BookFilter.all:
        return true;
      case BookFilter.continueReading:
      case BookFilter.currentlyReading:
        return book.progress > 0 && book.progress < 1;
      case BookFilter.finished:
        return book.progress >= 1;
      case BookFilter.notStarted:
        return book.progress <= 0;
    }
  }
}

class LibraryScreen extends StatefulWidget {
  final LibraryService library;
  const LibraryScreen({super.key, required this.library});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';
  SortMode _sort = SortMode.manual;
  BookFilter _filter = BookFilter.all;

  List<Book> _visibleBooks(List<Book> books) {
    final filtered = books.where(_filter.matches).toList();
    switch (_sort) {
      case SortMode.manual:
        // Shelf order (Book.order); "Continue reading" is recency-first.
        if (_filter == BookFilter.continueReading) {
          filtered.sort(
            (a, b) => b.lastOpenedMillis.compareTo(a.lastOpenedMillis),
          );
        }
      case SortMode.title:
        filtered.sort((a, b) => a.title.compareTo(b.title));
      case SortMode.author:
        filtered.sort((a, b) => a.author.compareTo(b.author));
      case SortMode.recent:
        filtered.sort(
          (a, b) => b.lastOpenedMillis.compareTo(a.lastOpenedMillis),
        );
      case SortMode.progress:
        filtered.sort((a, b) => b.progress.compareTo(a.progress));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.library;
    final filtering = _filter != BookFilter.all;
    final searching = _query.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF2E2015),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E4A3D),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppConfig.name, style: const TextStyle(fontFamily: 'serif')),
            Text(AppConfig.tagline, style: const TextStyle(fontSize: 11)),
          ],
        ),
        actions: [
          PopupMenuButton<BookFilter>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by reading status',
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => BookFilter.values
                .map(
                  (f) => CheckedPopupMenuItem<BookFilter>(
                    value: f,
                    checked: _filter == f,
                    child: Text(f.label),
                  ),
                )
                .toList(),
          ),
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort books',
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: SortMode.manual,
                checked: _sort == SortMode.manual,
                child: const Text('Shelf order'),
              ),
              CheckedPopupMenuItem(
                value: SortMode.recent,
                checked: _sort == SortMode.recent,
                child: const Text('Recently read'),
              ),
              CheckedPopupMenuItem(
                value: SortMode.title,
                checked: _sort == SortMode.title,
                child: const Text('Title A–Z'),
              ),
              CheckedPopupMenuItem(
                value: SortMode.author,
                checked: _sort == SortMode.author,
                child: const Text('Author A–Z'),
              ),
              CheckedPopupMenuItem(
                value: SortMode.progress,
                checked: _sort == SortMode.progress,
                child: const Text('Progress'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New shelf',
            onPressed: _addShelfDialog,
          ),
        ],
      ),
      body: LibraryBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search title or author…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: searching
                  ? _buildSearchResults(library)
                  : _buildShelves(library, filtering),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.file_upload),
        label: const Text('Import book'),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final err = await library.importBook();
          if (err != null && mounted) {
            messenger.showSnackBar(SnackBar(content: Text(err)));
          }
        },
      ),
    );
  }

  /// All shelves stacked vertically; scroll down for more shelves, each
  /// shelf row scrolls sideways for more books.
  Widget _buildShelves(LibraryService library, bool filtering) {
    final sections = <Widget>[];
    for (final shelf in library.shelves) {
      final books = _visibleBooks(library.booksOnShelf(shelf.id));
      // Hide shelves with no matching books while a filter is active;
      // otherwise show every shelf, even an empty one.
      if (books.isEmpty && filtering) continue;
      sections.add(
        ShelfRow(
          shelf: shelf,
          books: books,
          onOpen: _openBook,
          onLongPressMenu: _showBookMenu,
          onReorder: _onReorder,
        ),
      );
    }
    if (sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No books match "${_filter.label}".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 88),
      children: [
        ...sections,
        _buildAddShelfTile(),
        if (library.books.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No books yet.\nTap "Import book" below to add an EPUB, PDF or TXT.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResults(LibraryService library) {
    final books = _visibleBooks(library.search(_query));
    if (books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No books match "$_query".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 88),
      children: [
        ShelfRow(
          shelf: Shelf(id: '__search__', name: 'Search results'),
          books: books,
          // Search results are not a real shelf: no reordering here,
          // so a long-press still opens the book menu.
          enableDrop: false,
          onOpen: _openBook,
          onLongPressMenu: _showBookMenu,
          onReorder: _onReorder,
        ),
      ],
    );
  }

  Widget _buildAddShelfTile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: InkWell(
        onTap: _addShelfDialog,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Colors.white.withValues(alpha: 0.85)),
              const SizedBox(width: 8),
              Text(
                'Add shelf',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onReorder(
    Book dragged,
    String targetShelfId,
    int targetIndex,
  ) async {
    // A search-results row is not a real shelf; dropping there does
    // nothing (the book keeps its own shelf).
    if (targetShelfId == '__search__') return;
    await widget.library.moveBookToPosition(dragged, targetShelfId, targetIndex);
    // A manual order now governs the shelf.
    setState(() => _sort = SortMode.manual);
  }

  Future<void> _addShelfDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New shelf'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Nigerian novels'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null) await widget.library.addShelf(name);
  }

  Future<void> _openBook(Book book) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => book.format == BookFormat.pdf
            ? PdfReaderScreen(book: book, library: widget.library)
            : ReaderScreen(book: book, library: widget.library),
      ),
    );
    setState(() {});
  }

  Future<void> _showBookMenu(Book book) async {
    final shelfId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Move to shelf…')),
            ...widget.library.shelves.map((s) => ListTile(
                  title: Text(s.name),
                  trailing: s.id == book.shelfId ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, s.id),
                )),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Remove book', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, '__delete__'),
            ),
          ],
        ),
      ),
    );
    if (shelfId == null) return;
    if (shelfId == '__delete__') {
      await widget.library.deleteBook(book);
    } else {
      await widget.library.moveBook(book, shelfId);
    }
  }
}

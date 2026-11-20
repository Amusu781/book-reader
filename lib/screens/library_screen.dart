import 'package:flutter/material.dart';
import '../config.dart';
import '../models/book.dart';
import '../services/library_service.dart';
import '../widgets/book_cover.dart';
import 'pdf_reader_screen.dart';
import 'reader_screen.dart';

enum SortMode { title, author, recent, progress }

class LibraryScreen extends StatefulWidget {
  final LibraryService library;
  const LibraryScreen({super.key, required this.library});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _shelfId = 'reading';
  String _query = '';
  SortMode _sort = SortMode.recent;

  @override
  Widget build(BuildContext context) {
    final library = widget.library;
    final all = _query.isEmpty
        ? library.booksOnShelf(_shelfId)
        : library.search(_query);
    final books = List<Book>.from(all);
    switch (_sort) {
      case SortMode.title:
        books.sort((a, b) => a.title.compareTo(b.title));
      case SortMode.author:
        books.sort((a, b) => a.author.compareTo(b.author));
      case SortMode.recent:
        books.sort((a, b) => b.lastOpenedMillis.compareTo(a.lastOpenedMillis));
      case SortMode.progress:
        books.sort((a, b) => b.progress.compareTo(a.progress));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1E3),
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
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.sort),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: SortMode.recent, child: Text('Recently read')),
              PopupMenuItem(value: SortMode.title, child: Text('Title A–Z')),
              PopupMenuItem(value: SortMode.author, child: Text('Author A–Z')),
              PopupMenuItem(value: SortMode.progress, child: Text('Progress')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New shelf',
            onPressed: _addShelfDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search title or author…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: library.shelves.map((shelf) {
                final selected = shelf.id == _shelfId && _query.isEmpty;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(shelf.name),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _shelfId = shelf.id;
                      _query = '';
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: books.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _query.isEmpty
                            ? 'No books on this shelf yet.\nTap + below to import an EPUB, PDF or TXT.'
                            : 'No books match "$_query".',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.brown, fontSize: 15),
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: books.length,
                    itemBuilder: (_, i) => _BookTile(
                      book: books[i],
                      library: library,
                      onOpen: () => _openBook(books[i]),
                    ),
                  ),
          ),
        ],
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
}

class _BookTile extends StatelessWidget {
  final Book book;
  final LibraryService library;
  final VoidCallback onOpen;
  const _BookTile({required this.book, required this.library, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      onLongPress: () => _showBookMenu(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: BookCover(book: book)),
          const SizedBox(height: 4),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.brown),
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(
            value: book.progress.clamp(0, 1),
            backgroundColor: Colors.brown.shade100,
            color: const Color(0xFF2E4A3D),
            minHeight: 4,
          ),
          Text(
            '${(book.progress * 100).round()}% read',
            style: const TextStyle(fontSize: 10, color: Colors.brown),
          ),
        ],
      ),
    );
  }

  Future<void> _showBookMenu(BuildContext context) async {
    final shelfId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Move to shelf…')),
            ...library.shelves.map((s) => ListTile(
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
      await library.deleteBook(book);
    } else {
      await library.moveBook(book, shelfId);
    }
  }
}

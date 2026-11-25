import 'package:flutter/material.dart';
import '../config.dart';
import '../models/book.dart';
import '../services/app_prefs.dart';
import '../services/focus_mode.dart';
import '../services/library_service.dart';
import '../widgets/book_open_route.dart';
import '../widgets/bookshelf.dart';
import '../widgets/library_background.dart';
import 'pdf_reader_screen.dart';
import 'reader_screen.dart';

enum SortMode { manual, series, title, author, recent, progress }

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

/// The library home: a library ROOM with a bookcase for every shelf.
/// Scroll down to walk along the bookcases; the room stays put.
class LibraryScreen extends StatefulWidget {
  final LibraryService library;
  final AppPrefs? prefs;
  const LibraryScreen({super.key, required this.library, this.prefs});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with WidgetsBindingObserver {
  String _query = '';
  SortMode _sort = SortMode.manual;
  BookFilter _filter = BookFilter.all;
  late final AppPrefs _prefs;
  final _scroll = ScrollController();
  final _focus = FocusMode();

  @override
  void initState() {
    super.initState();
    _prefs = widget.prefs ?? (AppPrefs()..load());
    _prefs.addListener(_onPrefs);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOnboard());
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefs);
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  void _onPrefs() {
    if (mounted) setState(() {});
    _maybeOnboard();
  }

  bool _onboarding = false;

  /// First launch: offer Focus Mode straight away.
  Future<void> _maybeOnboard() async {
    if (!mounted || _onboarding) return;
    if (!_prefs.loaded || _prefs.focusOnboardingDone) return;
    _onboarding = true;
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.do_not_disturb_on_outlined),
        title: const Text('Read without interruptions?'),
        content: const Text(
          'Focus Mode makes the book full-screen and silences '
          'notifications while you read, then turns them back on when you '
          'close the book.\n\n'
          'To silence notifications, Android will ask you to allow Do Not '
          'Disturb access for ${AppConfig.name}. You can turn Focus Mode '
          'off any time in Library settings (top-right gear).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow Focus Mode'),
          ),
        ],
      ),
    );
    await _prefs.completeFocusOnboarding(focusOn: allow == true);
    if (allow == true && !await _focus.isDndGranted()) {
      _awaitingDnd = true;
      await _focus.requestDndAccess();
    }
    _onboarding = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system DND page: confirm what happened.
    if (state == AppLifecycleState.resumed && _awaitingDnd) {
      _awaitingDnd = false;
      _focus.isDndGranted().then((granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted
                  ? 'Focus Mode is on — notifications will be silenced while you read.'
                  : 'Focus Mode is on in full-screen. Notifications will not be '
                        'silenced until Do Not Disturb access is allowed.',
            ),
          ),
        );
      });
    }
  }

  bool _awaitingDnd = false;

  List<Book> _visibleBooks(List<Book> books) {
    final filtered = books.where(_filter.matches).toList();
    switch (_sort) {
      case SortMode.manual:
        if (_filter == BookFilter.continueReading) {
          filtered.sort(
            (a, b) => b.lastOpenedMillis.compareTo(a.lastOpenedMillis),
          );
        }
      case SortMode.series:
        filtered.sort(LibraryService.compareSeriesOrder);
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

  Color get _barColor {
    switch (_prefs.style) {
      case LibraryStyle.modern:
        return const Color(0xFF3F5A4E);
      case LibraryStyle.classic:
        return const Color(0xFF2E4A3D);
      case LibraryStyle.ancient:
        return const Color(0xFF2B241B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.library;
    final filtering = _filter != BookFilter.all;
    final searching = _query.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF1E150E),
      appBar: AppBar(
        backgroundColor: _barColor,
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
              for (final (mode, label) in const [
                (SortMode.manual, 'Shelf order'),
                (SortMode.series, 'Series order'),
                (SortMode.recent, 'Recently read'),
                (SortMode.title, 'Title A–Z'),
                (SortMode.author, 'Author A–Z'),
                (SortMode.progress, 'Progress'),
              ])
                CheckedPopupMenuItem(
                  value: mode,
                  checked: _sort == mode,
                  child: Text(label),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add a bookcase',
            onPressed: _addShelfDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Library settings',
            onPressed: _showLibrarySettings,
          ),
        ],
      ),
      body: LibraryBackground(
        style: _prefs.style,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search title, author, series or genre…',
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
            if (_prefs.grouping != LibraryGrouping.shelves && !searching)
              _groupingBanner(),
            Expanded(
              child: searching
                  ? _buildSearchResults(library)
                  : _buildBookcases(library, filtering),
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

  Widget _groupingBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Icon(
            Icons.auto_stories,
            size: 16,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _prefs.grouping == LibraryGrouping.series
                  ? 'Arranged by series — long-press a book to set its series'
                  : 'Arranged by genre — long-press a book to set its genre',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _prefs.setGrouping(LibraryGrouping.shelves),
            child: const Text('My shelves'),
          ),
        ],
      ),
    );
  }

  /// One bookcase per shelf (or per series / genre), stacked down the
  /// room; scroll down to walk past more bookcases.
  Widget _buildBookcases(LibraryService library, bool filtering) {
    final sections = <Widget>[];
    final style = _prefs.style;
    if (_prefs.grouping == LibraryGrouping.shelves) {
      for (final shelf in library.shelves) {
        final books = _visibleBooks(library.booksOnShelf(shelf.id));
        if (books.isEmpty && filtering) continue;
        sections.add(
          ShelfRow(
            key: ValueKey('case-${shelf.id}'),
            shelf: shelf,
            books: books,
            style: style,
            onOpen: _openBook,
            onLongPressMenu: _showBookMenu,
            onReorder: _onReorder,
          ),
        );
      }
    } else {
      final groups = _prefs.grouping == LibraryGrouping.series
          ? library.groupBySeries()
          : library.groupByGenre();
      for (final (name, groupBooks) in groups) {
        // Series/genre bookcases keep their reading order, so only the
        // reading-status filter applies here.
        final books = groupBooks.where(_filter.matches).toList();
        if (books.isEmpty) continue;
        final seriesCase =
            _prefs.grouping == LibraryGrouping.series &&
            groupBooks.first.series.isNotEmpty;
        sections.add(
          ShelfRow(
            key: ValueKey('group-$name'),
            shelf: Shelf(id: '__group__$name', name: name),
            books: books,
            style: style,
            enableDrop: false,
            subtitle: seriesCase
                ? '${books.length} part${books.length == 1 ? '' : 's'}'
                : null,
            onOpen: _openBook,
            onLongPressMenu: _showBookMenu,
            onReorder: _onReorder,
          ),
        );
      }
    }
    if (sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            library.books.isEmpty
                ? 'No books yet.\nTap "Import book" below to add an EPUB, PDF or TXT.'
                : 'No books match "${_filter.label}".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
      );
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.only(top: 10, bottom: 96),
      children: [
        ...sections,
        if (_prefs.grouping == LibraryGrouping.shelves) _buildAddBookcaseTile(),
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
      padding: const EdgeInsets.only(top: 10, bottom: 96),
      children: [
        ShelfRow(
          shelf: Shelf(id: '__search__', name: 'Search results'),
          books: books,
          style: _prefs.style,
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

  Widget _buildAddBookcaseTile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: InkWell(
        onTap: _addShelfDialog,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              Text(
                'Add a bookcase',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                  fontFamily: 'serif',
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
    // Search results and series/genre cases are not real shelves.
    if (targetShelfId == '__search__' ||
        targetShelfId.startsWith('__group__')) {
      return;
    }
    await widget.library.moveBookToPosition(
      dragged,
      targetShelfId,
      targetIndex,
    );
    setState(() => _sort = SortMode.manual);
  }

  Future<void> _addShelfDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New bookcase'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Nigerian novels',
            labelText: 'Name on the brass plate',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Build it'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    if (_prefs.grouping != LibraryGrouping.shelves) {
      await _prefs.setGrouping(LibraryGrouping.shelves);
    }
    await widget.library.addShelf(name);
    // Walk to the new bookcase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _showLibrarySettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => LibrarySettingsSheet(
        prefs: _prefs,
        onFocusTurnedOn: () async {
          if (!await _focus.isDndGranted()) {
            _awaitingDnd = true;
            await _focus.requestDndAccess();
          }
        },
      ),
    );
  }

  Future<void> _openBook(Book book) async {
    final usePdfView = book.format == BookFormat.pdf && book.pdfOriginalLayout;
    await Navigator.of(context).push(
      BookOpenRoute(
        book: book,
        style: _prefs.style,
        builder: (_) => usePdfView
            ? PdfReaderScreen(
                book: book,
                library: widget.library,
                prefs: _prefs,
              )
            : ReaderScreen(book: book, library: widget.library, prefs: _prefs),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showBookMenu(Book book) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit details'),
                subtitle: const Text('Title, author, series, part, genre'),
                onTap: () => Navigator.pop(ctx, '__edit__'),
              ),
              const Divider(height: 1),
              const ListTile(title: Text('Move to shelf…')),
              ...widget.library.shelves.map(
                (s) => ListTile(
                  title: Text(s.name),
                  trailing: s.id == book.shelfId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(ctx, s.id),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove book',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(ctx, '__delete__'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;
    if (choice == '__delete__') {
      await widget.library.deleteBook(book);
    } else if (choice == '__edit__') {
      await _editDetails(book);
    } else {
      await widget.library.moveBook(book, choice);
    }
  }

  Future<void> _editDetails(Book book) async {
    final result = await showDialog<BookDetails>(
      context: context,
      builder: (_) => EditBookDialog(
        book: book,
        knownSeries: widget.library.allSeries,
        knownGenres: widget.library.allGenres,
      ),
    );
    if (result == null) return;
    await widget.library.updateBookDetails(
      book,
      title: result.title,
      author: result.author,
      series: result.series,
      seriesIndex: result.seriesIndex,
      genre: result.genre,
    );
  }
}

/// The top-right library settings: library style (changes the room,
/// the bookcases and every book spine), how bookcases are arranged,
/// and Focus Mode on/off. Everything is saved.
class LibrarySettingsSheet extends StatefulWidget {
  final AppPrefs prefs;
  final Future<void> Function() onFocusTurnedOn;
  const LibrarySettingsSheet({
    super.key,
    required this.prefs,
    required this.onFocusTurnedOn,
  });

  @override
  State<LibrarySettingsSheet> createState() => _LibrarySettingsSheetState();
}

class _LibrarySettingsSheetState extends State<LibrarySettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final prefs = widget.prefs;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Library settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            const Text(
              'Library style',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in LibraryStyle.values)
                  ChoiceChip(
                    label: Text(s.label),
                    selected: prefs.style == s,
                    onSelected: (_) async {
                      await prefs.setStyle(s);
                      setState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(prefs.style.description),
            const SizedBox(height: 18),
            const Text(
              'Arrange bookcases',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final g in LibraryGrouping.values)
                  ChoiceChip(
                    label: Text(g.label),
                    selected: prefs.grouping == g,
                    onSelected: (_) async {
                      await prefs.setGrouping(g);
                      setState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Focus Mode'),
              subtitle: const Text(
                'Open every book full-screen with notifications silenced '
                '(Do Not Disturb). Turned back off when you close the book.',
              ),
              value: prefs.focusModeDefault,
              onChanged: (on) async {
                await prefs.setFocusModeDefault(on);
                setState(() {});
                if (on) await widget.onFocusTurnedOn();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class BookDetails {
  final String title;
  final String author;
  final String series;
  final double? seriesIndex;
  final String genre;
  const BookDetails(
    this.title,
    this.author,
    this.series,
    this.seriesIndex,
    this.genre,
  );
}

/// Edit a book's title, author, series (+ part number) and genre, so
/// the library can be arranged by series and by genre.
class EditBookDialog extends StatefulWidget {
  final Book book;
  final List<String> knownSeries;
  final List<String> knownGenres;
  const EditBookDialog({
    super.key,
    required this.book,
    required this.knownSeries,
    required this.knownGenres,
  });

  @override
  State<EditBookDialog> createState() => _EditBookDialogState();
}

class _EditBookDialogState extends State<EditBookDialog> {
  late final _title = TextEditingController(text: widget.book.title);
  late final _author = TextEditingController(
    text: widget.book.author == 'Unknown author' ? '' : widget.book.author,
  );
  late final _series = TextEditingController(text: widget.book.series);
  late final _part = TextEditingController(
    text: widget.book.seriesIndex == null
        ? ''
        : (widget.book.seriesIndex! % 1 == 0
              ? widget.book.seriesIndex!.toInt().toString()
              : widget.book.seriesIndex.toString()),
  );
  late final _genre = TextEditingController(text: widget.book.genre);

  static const _commonGenres = [
    'Fiction',
    'Fantasy',
    'Science fiction',
    'Mystery',
    'Romance',
    'History',
    'Biography',
    'Self-help',
    'Religion',
    'Textbook',
    'Poetry',
  ];

  Widget _suggestions(List<String> options, TextEditingController c) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: -6,
        children: [
          for (final o in options.take(8))
            ActionChip(
              label: Text(o, style: const TextStyle(fontSize: 12)),
              onPressed: () => setState(() => c.text = o),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final genres = {...widget.knownGenres, ..._commonGenres}.toList();
    return AlertDialog(
      title: const Text('Book details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _author,
              decoration: const InputDecoration(labelText: 'Author'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _series,
                    decoration: const InputDecoration(
                      labelText: 'Series',
                      hintText: 'e.g. Harry Potter',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _part,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Part'),
                  ),
                ),
              ],
            ),
            _suggestions(widget.knownSeries, _series),
            const SizedBox(height: 8),
            TextField(
              controller: _genre,
              decoration: const InputDecoration(labelText: 'Genre'),
            ),
            _suggestions(genres, _genre),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            BookDetails(
              _title.text,
              _author.text,
              _series.text,
              double.tryParse(_part.text.trim()),
              _genre.text,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

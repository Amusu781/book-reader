import 'dart:async';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/app_prefs.dart';
import '../services/book_parser.dart';
import '../services/focus_mode.dart';
import '../services/library_service.dart';
import '../services/reader_theme.dart';
import '../widgets/leaf_turn_view.dart';
import '../widgets/page_texture.dart';
import '../widgets/reader_settings_sheet.dart';
import 'pdf_reader_screen.dart';

/// The restyleable reader for EPUB, TXT and (since v3) PDF books.
/// PDFs are converted to reflowable text on first open (cached), so
/// page style, textures, font size, line spacing, night mode and the
/// leaf turn all apply to them too. "Original layout" switches a PDF
/// to its untouched pages (PdfReaderScreen).
class ReaderScreen extends StatefulWidget {
  final Book book;
  final LibraryService library;
  final AppPrefs? prefs;
  const ReaderScreen({
    super.key,
    required this.book,
    required this.library,
    this.prefs,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  ReaderSettings _settings = ReaderSettings();
  final _focus = FocusMode();
  final _leafKey = GlobalKey<LeafTurnViewState>();
  ParsedBook? _parsed;
  List<TextPage> _pages = [];
  List<Chapter> _chapters = [];
  bool _loading = true;
  bool _focusOn = false;
  bool _controlsVisible = true;
  int _page = 0;
  Size? _lastPageSize;
  bool _paginateScheduled = false;
  Timer? _repaginateDebounce;
  // Char offset to land on after the first pagination (resume point).
  int? _resumeChar;
  String? _loadError;

  // Text area insets inside the page (the bottom bar overlays the page).
  static const _hPad = 24.0;
  static const _topPad = 16.0;
  static const _bottomPad = 80.0;

  bool get _isPdf => widget.book.format == BookFormat.pdf;

  @override
  void initState() {
    super.initState();
    _page = 0;
    _load();
  }

  Future<void> _load() async {
    final settings = await ReaderSettings.load();
    ParsedBook parsed;
    try {
      parsed = await BookParser.parse(widget.book);
    } catch (e) {
      if (!mounted) return;
      if (_isPdf) {
        _openOriginalLayout(
          note:
              'This PDF could not be converted to text, so it is shown '
              'in its original layout.',
        );
        return;
      }
      setState(() {
        _settings = settings;
        _loading = false;
        _loadError = 'Could not open this book: $e';
      });
      return;
    }
    if (!mounted) return;
    if (parsed.pdfHasNoText) {
      // Scanned PDF (page images): nothing to restyle.
      _openOriginalLayout(
        note:
            'This PDF is made of scanned page images, so it has no text '
            'to restyle. Showing its original layout.',
      );
      return;
    }
    final book = widget.book;
    if (book.lastCharOffset >= 0) {
      _resumeChar = book.lastCharOffset;
    } else if (_isPdf && parsed.pdf != null && book.lastPage > 0) {
      // Read before in original layout: resume at that PDF page.
      _resumeChar = parsed.pdf!.charForPage(book.lastPage);
    }
    setState(() {
      _settings = settings;
      _parsed = parsed;
      _chapters = parsed.chapters;
      _loading = false;
    });
    if (widget.prefs?.focusModeDefault == true) {
      await _focus.enter();
      if (mounted) setState(() => _focusOn = true);
    }
    await widget.library.updateProgress(book);
  }

  /// Switch a PDF to its original page images (pdfx view).
  Future<void> _openOriginalLayout({String? note}) async {
    final book = widget.book;
    if (_pages.isNotEmpty && _parsed?.pdf != null && _page < _pages.length) {
      book.lastPage = _parsed!.pdf!.pageForChar(_pages[_page].start);
    }
    if (note == null) book.pdfOriginalLayout = true;
    await widget.library.updateProgress(book);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PdfReaderScreen(
          book: book,
          library: widget.library,
          prefs: widget.prefs,
          note: note,
          canRestyle: note == null,
        ),
      ),
    );
  }

  /// The exact box the page text must fit inside, derived from the
  /// screen size (not the layout) so hiding the controls never
  /// repaginates the book.
  Size _textBoxSize(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width - _hPad * 2;
    final height =
        mq.size.height - mq.padding.top - kToolbarHeight - _topPad - _bottomPad;
    return Size(width, height);
  }

  TextStyle get _pageTextStyle => TextStyle(
    fontFamily: _settings.theme.fontFamily,
    fontSize: _settings.fontSize,
    height: _settings.lineHeight,
    color: _settings.textColor,
  );

  void _schedulePaginate() {
    if (_paginateScheduled) return;
    _paginateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paginateScheduled = false;
      _paginate();
    });
  }

  void _paginate() {
    final parsed = _parsed;
    final size = _lastPageSize;
    if (parsed == null || size == null || !mounted) return;
    // Keep the reader on the same passage across a repagination; on the
    // first pagination, land on the saved resume point.
    final anchor =
        _resumeChar ??
        (_pages.isNotEmpty && _page < _pages.length ? _pages[_page].start : 0);
    _resumeChar = null;
    final pages = BookParser.paginateMeasured(
      parsed.text,
      _pageTextStyle,
      size,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final page = BookParser.pageForChar(pages, anchor);
    setState(() {
      _pages = pages;
      _page = page;
      widget.book.totalPages = pages.length;
    });
    _leafKey.currentState?.jumpTo(page);
  }

  /// Repaginate shortly after a font/line-height change settles.
  void _repaginateDebounced() {
    _repaginateDebounce?.cancel();
    _repaginateDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) _schedulePaginate();
    });
  }

  Future<void> _onPageChanged(int index) async {
    _page = index;
    final book = widget.book;
    book.lastCharOffset = _pages[index].start;
    // For PDFs lastPage always means the ORIGINAL PDF page, so the
    // "Original layout" view resumes in the same place.
    book.lastPage = _parsed?.pdf != null
        ? _parsed!.pdf!.pageForChar(_pages[index].start)
        : index;
    book.progress = _pages.length <= 1 ? 1 : index / (_pages.length - 1);
    await widget.library.updateProgress(widget.book);
    if (mounted) setState(() {});
  }

  Future<void> _toggleFocus() async {
    if (_focusOn) {
      await _focus.exit();
      setState(() => _focusOn = false);
    } else {
      final messenger = ScaffoldMessenger.of(context);
      final granted = await _focus.isDndGranted();
      if (!granted && mounted) {
        final go = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Focus Mode needs Do Not Disturb access'),
            content: const Text(
              'To silence notifications while you read, Android needs you to allow '
              'Do Not Disturb access for this app. You can skip this and still '
              'read in full-screen — Focus Mode just will not silence notifications.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Skip for now'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open settings'),
              ),
            ],
          ),
        );
        if (go == true) await _focus.requestDndAccess();
      }
      if (!mounted) return;
      await _focus.enter();
      if (!mounted) return;
      setState(() {
        _focusOn = true;
        _controlsVisible = false;
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Focus Mode on — notifications silenced. Tap the screen to show controls.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _repaginateDebounce?.cancel();
    _focus.exit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    // The AppBar stays in the layout even when hidden (Offstage), so
    // the page size — and therefore the pagination — never shifts when
    // the controls are toggled.
    return Scaffold(
      backgroundColor: settings.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Offstage(
          offstage: !_controlsVisible,
          child: AppBar(
            backgroundColor: settings.background,
            foregroundColor: settings.textColor,
            elevation: 0,
            title: Text(
              widget.book.title,
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              if (_isPdf)
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: 'Original PDF layout',
                  onPressed: () => _openOriginalLayout(),
                ),
              IconButton(
                icon: Icon(
                  _focusOn ? Icons.do_not_disturb_on : Icons.do_not_disturb_off,
                ),
                tooltip: 'Focus Mode',
                onPressed: _toggleFocus,
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _showSettings,
              ),
              IconButton(icon: const Icon(Icons.list), onPressed: _showToc),
            ],
          ),
        ),
      ),
      body: Stack(
        // Expand so a short (e.g. last) page still fills the whole sheet.
        fit: StackFit.expand,
        children: [
          if (_loadError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: settings.textColor),
                ),
              ),
            )
          else if (_loading || _parsed == null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (_isPdf) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Preparing this PDF so you can restyle it…',
                      style: TextStyle(color: settings.textColor),
                    ),
                  ],
                ],
              ),
            )
          else
            _buildReader(context),
          // Brightness dim overlay (does not block taps: IgnorePointer).
          if (settings.brightnessDim > 0)
            IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: settings.brightnessDim),
              ),
            ),
          if (_controlsVisible && !_loading && _parsed != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: settings.background,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.bookmark_border),
                          color: settings.textColor,
                          tooltip: 'Bookmark this page',
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await widget.library.toggleBookmark(
                              widget.book,
                              _page,
                            );
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Bookmark ${_page + 1} saved'),
                              ),
                            );
                            setState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.highlight),
                          color: settings.textColor,
                          tooltip: 'Highlight this page',
                          onPressed: () async {
                            final snippet = _pages[_page].text.length > 120
                                ? '${_pages[_page].text.substring(0, 120)}…'
                                : _pages[_page].text;
                            final messenger = ScaffoldMessenger.of(context);
                            await widget.library.addHighlight(
                              widget.book,
                              _page,
                              snippet,
                            );
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Highlight saved')),
                            );
                            setState(() {});
                          },
                        ),
                        const Spacer(),
                        Text(
                          'Page ${_page + 1} of ${_pages.length}',
                          style: TextStyle(color: settings.textColor),
                        ),
                        const Spacer(),
                        Text(
                          '${(widget.book.progress * 100).round()}%',
                          style: TextStyle(color: settings.textColor),
                        ),
                      ],
                    ),
                    if (widget.book.bookmarks.isNotEmpty)
                      Text(
                        'Bookmarks: ${widget.book.bookmarks.map((p) => p + 1).join(', ')}',
                        style: TextStyle(
                          color: settings.textColor,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReader(BuildContext context) {
    final size = _textBoxSize(context);
    if (_lastPageSize != size) {
      _lastPageSize = size;
      _schedulePaginate();
    }
    if (_pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return LeafTurnView(
      key: _leafKey,
      pageCount: _pages.length,
      initialPage: _page.clamp(0, _pages.length - 1),
      onPageChanged: _onPageChanged,
      onTapMiddle: () => setState(() => _controlsVisible = !_controlsVisible),
      backColor: _settings.background,
      pageBuilder: (_, i) => _buildPage(i),
    );
  }

  Widget _buildPage(int index) {
    final settings = _settings;
    if (index < 0 || index >= _pages.length) {
      return Container(color: settings.background);
    }
    return PageTexture(
      theme: settings.theme,
      pageIndex: index,
      nightMode: settings.nightMode,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_hPad, _topPad, _hPad, _bottomPad),
        child: Text(
          _pages[index].text,
          style: _pageTextStyle,
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }

  Future<void> _showSettings() async {
    await showReaderSettingsSheet(
      context: context,
      settings: _settings,
      onChanged: () {
        if (mounted) setState(() {});
      },
      onLayoutChanged: _repaginateDebounced,
    );
  }

  Future<void> _showToc() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => ListView(
        children: [
          const ListTile(
            title: Text(
              'Contents',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ..._chapters.map((ch) {
            final page = BookParser.pageForChar(_pages, ch.startChar);
            return ListTile(
              title: Text(ch.title),
              subtitle: Text('Page ${page + 1}'),
              onTap: () {
                Navigator.pop(context);
                _leafKey.currentState?.turnTo(page.clamp(0, _pages.length - 1));
              },
            );
          }),
          if (widget.book.highlights.isNotEmpty) ...[
            const ListTile(
              title: Text(
                'Highlights',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...widget.book.highlights.map(
              (h) => ListTile(
                title: Text(
                  h.snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('Page ${h.page + 1}'),
                onTap: () {
                  Navigator.pop(context);
                  _leafKey.currentState?.turnTo(
                    h.page.clamp(0, _pages.length - 1),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

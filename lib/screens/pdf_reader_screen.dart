import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../models/book.dart';
import '../services/app_prefs.dart';
import '../services/focus_mode.dart';
import '../services/library_service.dart';
import '../services/pdf_text.dart';
import '../services/reader_theme.dart';
import '../widgets/reader_settings_sheet.dart';
import 'reader_screen.dart';

/// "Original layout" for PDFs: the untouched PDF pages via pdfx.
///
/// Since v3, PDFs normally open in the restyleable text reader
/// (ReaderScreen) where page style, font, spacing and night mode all
/// apply. This screen is the fallback: chosen with the "Original
/// layout" button, or used automatically for scanned PDFs that have no
/// text ([canRestyle] false). Brightness and night dim still apply
/// over the rendered pages. The "Restyle" button goes back to the
/// text reader at the same place.
class PdfReaderScreen extends StatefulWidget {
  final Book book;
  final LibraryService library;
  final AppPrefs? prefs;
  final String? note;
  final bool canRestyle;
  const PdfReaderScreen({
    super.key,
    required this.book,
    required this.library,
    this.prefs,
    this.note,
    this.canRestyle = true,
  });

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  ReaderSettings _settings = ReaderSettings();
  late PdfController _controller;
  int _page = 0;
  int _total = 1;
  final _focus = FocusMode();
  PdfReflow? _reflow; // cached text map, for progress hand-over

  @override
  void initState() {
    super.initState();
    _page = widget.book.lastPage;
    // pdfx pages are 1-based; the app stores lastPage 0-based.
    _controller = PdfController(
      document: PdfDocument.openFile(widget.book.filePath),
      initialPage: _page + 1,
    );
    _loadSettings();
    _loadReflowMap();
    if (widget.prefs?.focusModeDefault == true) _focus.enter();
    if (widget.note != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.note!),
            duration: const Duration(seconds: 5),
          ),
        );
      });
    }
  }

  /// Only reads the cache (never converts here), so switching layouts
  /// can keep your place.
  Future<void> _loadReflowMap() async {
    if (!widget.canRestyle) return;
    try {
      if (await PdfTextService.cacheFileFor(widget.book.filePath).exists()) {
        final r = await PdfTextService.load(widget.book.filePath);
        if (mounted) _reflow = r;
      }
    } catch (_) {}
  }

  Future<void> _restyle() async {
    final book = widget.book;
    book.pdfOriginalLayout = false;
    if (_reflow != null) {
      book.lastCharOffset = _reflow!.charForPage(_page);
    } else {
      book.lastCharOffset = -1; // ReaderScreen maps lastPage instead
    }
    await widget.library.updateProgress(book);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          book: book,
          library: widget.library,
          prefs: widget.prefs,
        ),
      ),
    );
  }

  Future<void> _loadSettings() async {
    final settings = await ReaderSettings.load();
    if (mounted) setState(() => _settings = settings);
  }

  @override
  void dispose() {
    _focus.exit();
    _controller.dispose();
    super.dispose();
  }

  /// Total dim over the rendered PDF page: the brightness slider plus
  /// an extra layer for night mode.
  double get _dim =>
      (_settings.brightnessDim + (_settings.nightMode ? 0.35 : 0)).clamp(
        0,
        0.8,
      );

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      backgroundColor: settings.nightMode
          ? const Color(0xFF121212)
          : Colors.white,
      appBar: AppBar(
        backgroundColor: settings.nightMode
            ? const Color(0xFF121212)
            : Colors.white,
        foregroundColor: settings.nightMode
            ? const Color(0xFFE8E0D0)
            : Colors.black87,
        elevation: 0,
        title: Text(widget.book.title, style: const TextStyle(fontSize: 16)),
        actions: [
          if (widget.canRestyle)
            IconButton(
              icon: const Icon(Icons.text_fields),
              tooltip: 'Restyle text (page style, font, night mode)',
              onPressed: _restyle,
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Reading settings',
            onPressed: () async {
              await showReaderSettingsSheet(
                context: context,
                settings: settings,
                onChanged: () {
                  if (mounted) setState(() {});
                },
                onLayoutChanged: () {},
              );
            },
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('Page ${_page + 1} / $_total'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          PdfView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            pageSnapping: true,
            backgroundDecoration: BoxDecoration(
              color: settings.nightMode
                  ? const Color(0xFF121212)
                  : Colors.white,
            ),
            onPageChanged: (pageNumber) async {
              // pdfx reports 1-based page numbers; store 0-based.
              final page = pageNumber - 1;
              _page = page;
              widget.book.lastPage = page;
              widget.book.totalPages = _total;
              widget.book.progress = _total <= 1 ? 1 : page / (_total - 1);
              // Keep the restyled reader in step: exact char offset when
              // the text map is cached, otherwise let it map lastPage.
              widget.book.lastCharOffset = _reflow != null
                  ? _reflow!.charForPage(page)
                  : -1;
              await widget.library.updateProgress(widget.book);
              if (mounted) setState(() {});
            },
            onDocumentLoaded: (doc) {
              setState(() => _total = doc.pagesCount);
              widget.book.totalPages = doc.pagesCount;
            },
            onDocumentError: (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not open this PDF: $e')),
              );
            },
          ),
          if (_dim > 0)
            IgnorePointer(
              child: Container(color: Colors.black.withValues(alpha: _dim)),
            ),
        ],
      ),
    );
  }
}

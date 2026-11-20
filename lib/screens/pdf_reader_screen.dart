import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../models/book.dart';
import '../services/library_service.dart';
import '../services/reader_theme.dart';
import '../widgets/reader_settings_sheet.dart';

/// PDF reading via pdfx. The same settings sheet as the text reader
/// works here: brightness dim and night dim apply over the rendered
/// pages, and paging is horizontal, page-by-page. Font size, line
/// spacing and page themes cannot recolour rendered PDF pages — the
/// PDF keeps its own look — but the settings are shared, so a font
/// size picked here still applies to EPUB/TXT books.
class PdfReaderScreen extends StatefulWidget {
  final Book book;
  final LibraryService library;
  const PdfReaderScreen({super.key, required this.book, required this.library});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  ReaderSettings _settings = ReaderSettings();
  late PdfController _controller;
  int _page = 0;
  int _total = 1;

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
  }

  Future<void> _loadSettings() async {
    final settings = await ReaderSettings.load();
    if (mounted) setState(() => _settings = settings);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Total dim over the rendered PDF page: the brightness slider plus
  /// an extra layer for night mode.
  double get _dim =>
      (_settings.brightnessDim + (_settings.nightMode ? 0.35 : 0))
          .clamp(0, 0.8);

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      backgroundColor:
          settings.nightMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor:
            settings.nightMode ? const Color(0xFF121212) : Colors.white,
        foregroundColor:
            settings.nightMode ? const Color(0xFFE8E0D0) : Colors.black87,
        elevation: 0,
        title: Text(widget.book.title, style: const TextStyle(fontSize: 16)),
        actions: [
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

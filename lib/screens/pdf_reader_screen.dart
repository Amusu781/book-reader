import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../models/book.dart';
import '../services/library_service.dart';

/// PDF reading via pdfx. Progress is page-based; highlights/bookmarks
/// for PDF are not in this MVP (they work for EPUB/TXT in ReaderScreen).
class PdfReaderScreen extends StatefulWidget {
  final Book book;
  final LibraryService library;
  const PdfReaderScreen({super.key, required this.book, required this.library});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  late PdfController _controller;
  int _page = 0;
  int _total = 1;

  @override
  void initState() {
    super.initState();
    _page = widget.book.lastPage;
    _controller = PdfController(document: PdfDocument.openFile(widget.book.filePath));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title, style: const TextStyle(fontSize: 16)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('Page ${_page + 1} / $_total'),
            ),
          ),
        ],
      ),
      body: PdfView(
        controller: _controller,
        scrollDirection: Axis.vertical,
        onPageChanged: (page) async {
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
    );
  }
}

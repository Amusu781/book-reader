import 'dart:io';
import 'package:epubx/epubx.dart';
import '../models/book.dart';

class Chapter {
  final String title;
  final int startChar;
  Chapter(this.title, this.startChar);
}

class ParsedBook {
  final String text;
  final List<Chapter> chapters;
  ParsedBook(this.text, this.chapters);
}

/// Reads EPUB / TXT files into plain text. PDF is rendered separately
/// with pdfx (see PdfReaderScreen) — this parser returns empty text for PDF.
class BookParser {
  static Future<ParsedBook> parse(Book book) async {
    final file = File(book.filePath);
    if (!await file.exists()) return ParsedBook('', []);
    switch (book.format) {
      case BookFormat.txt:
        final text = await file.readAsString();
        return ParsedBook(text, _chaptersFromText(text));
      case BookFormat.epub:
        return _parseEpub(file);
      case BookFormat.pdf:
      case BookFormat.unknown:
        return ParsedBook('', []);
    }
  }

  static Future<ParsedBook> _parseEpub(File file) async {
    final bytes = await file.readAsBytes();
    final epub = await EpubReader.readBook(bytes);
    final buffer = StringBuffer();
    final chapters = <Chapter>[];
    final docs = epub.Chapters ?? <EpubChapter>[];
    for (final ch in docs) {
      final title = (ch.Title ?? 'Chapter').trim();
      if (title.isNotEmpty) chapters.add(Chapter(title, buffer.length));
      final html = ch.HtmlContent ?? '';
      buffer.writeln(_stripHtml(html));
      buffer.writeln();
      for (final sub in ch.SubChapters ?? <EpubChapter>[]) {
        final subTitle = (sub.Title ?? '').trim();
        if (subTitle.isNotEmpty) {
          chapters.add(Chapter('  $subTitle', buffer.length));
        }
        buffer.writeln(_stripHtml(sub.HtmlContent ?? ''));
        buffer.writeln();
      }
    }
    var text = buffer.toString().trim();
    if (text.isEmpty) text = 'This EPUB has no readable text chapters.';
    if (chapters.isEmpty) chapters.add(Chapter('Start', 0));
    return ParsedBook(text, chapters);
  }

  static List<Chapter> _chaptersFromText(String text) {
    // Headings in all-caps / "Chapter N" lines become TOC entries.
    final chapters = <Chapter>[Chapter('Start', 0)];
    final lines = text.split('\n');
    var offset = 0;
    final re = RegExp(r'^(chapter\s+\w+|part\s+\w+)\.?$', caseSensitive: false);
    for (final line in lines) {
      final t = line.trim();
      if (t.length > 3 && t.length < 60 && re.hasMatch(t)) {
        chapters.add(Chapter(t, offset));
      }
      offset += line.length + 1;
    }
    return chapters;
  }

  static String _stripHtml(String html) {
    var s = html
        .replaceAll(RegExp(r'<(br|p|h[1-6]|div|li)[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    // Collapse 3+ newlines.
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

  /// Split [text] into page-sized chunks at word boundaries.
  static List<String> paginate(String text, int charsPerPage) {
    if (text.isEmpty) return [''];
    final pages = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = (start + charsPerPage).clamp(0, text.length);
      if (end < text.length) {
        final lastSpace = text.lastIndexOf(' ', end);
        if (lastSpace > start + 200) end = lastSpace;
      }
      pages.add(text.substring(start, end).trim());
      start = end;
    }
    return pages;
  }

  static int charsPerPageForFontSize(double fontSize) {
    // Rough estimate: larger font -> fewer characters per page.
    // 18sp ~= 1600 chars; scale inversely.
    return (1600 * 18 / fontSize).round().clamp(700, 2600);
  }
}

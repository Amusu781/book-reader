import 'dart:io';
import 'dart:math' as math;
import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import '../models/book.dart';
import 'pdf_text.dart';

class Chapter {
  final String title;
  final int startChar;
  Chapter(this.title, this.startChar);
}

class ParsedBook {
  final String text;
  final List<Chapter> chapters;

  /// For PDFs converted to reflowable text: the page map back to the
  /// original PDF pages. Null for EPUB/TXT.
  final PdfReflow? pdf;
  ParsedBook(this.text, this.chapters, {this.pdf});

  /// A PDF whose pages are images (scanned) — nothing to restyle.
  bool get pdfHasNoText => pdf != null && !pdf!.hasText;
}

/// One page of measured text: the exact char range in the parsed text
/// plus the (trimmed) text to render. Pages never scroll — each one is
/// measured to fit the real page box exactly.
class TextPage {
  final int start;
  final int end;
  final String text;
  const TextPage(this.start, this.end, this.text);
}

/// Reads EPUB / TXT / PDF files into plain text for the restyleable
/// reader. PDFs are converted with [PdfTextService] (cached); a PDF
/// with no extractable text (scanned pages) comes back with
/// [ParsedBook.pdfHasNoText] so the app can show the original layout.
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
        return _parsePdf(book.filePath);
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

  static Future<ParsedBook> _parsePdf(String path) async {
    final reflow = await PdfTextService.load(path);
    final chapters = <Chapter>[];
    if (reflow.outline.isNotEmpty) {
      for (final (title, page) in reflow.outline) {
        chapters.add(Chapter(title, reflow.charForPage(page)));
      }
    } else {
      chapters.addAll(_chaptersFromText(reflow.text));
    }
    if (chapters.isEmpty) chapters.add(Chapter('Start', 0));
    return ParsedBook(reflow.text, chapters, pdf: reflow);
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
        .replaceAll(
          RegExp(r'<(br|p|h[1-6]|div|li)[^>]*>', caseSensitive: false),
          '\n',
        )
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

  /// Split [text] into pages that each fit exactly inside a box of
  /// [pageSize] when rendered with [style] (and [textScaler], matching
  /// the Text widget that will render the page). Splits happen at word
  /// boundaries; a page never overflows — leftover text flows to the
  /// next page. Each page records its start char offset in the full
  /// text so the table of contents can jump to the exact page.
  static List<TextPage> paginateMeasured(
    String text,
    TextStyle style,
    Size pageSize, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    if (text.isEmpty) return const [TextPage(0, 0, '')];
    final pages = <TextPage>[];
    var start = 0;
    final n = text.length;
    while (start < n) {
      // Skip blank lines / spaces at the top of a new page.
      while (start < n && (text[start] == '\n' || text[start] == ' ')) {
        start++;
      }
      if (start >= n) break;
      final end = _fitEnd(text, start, style, pageSize, textScaler);
      final pageText = text.substring(start, end).trimRight();
      pages.add(TextPage(start, end, pageText));
      // Guard against zero progress (e.g. a single unbreakable word
      // wider than the page — TextPainter wraps it, so _fitEnd always
      // advances, but never loop forever).
      start = end > start ? end : start + 1;
    }
    if (pages.isEmpty) pages.add(const TextPage(0, 0, ''));
    return pages;
  }

  /// Largest end offset in (start, text.length] whose substring fits
  /// inside [pageSize] when laid out with [style]. Binary search around
  /// a rough estimate so a whole book costs only a few layouts per page.
  static int _fitEnd(
    String text,
    int start,
    TextStyle style,
    Size pageSize,
    TextScaler textScaler,
  ) {
    final n = text.length;
    final fontSize = style.fontSize ?? 18;
    final lineHeight = (style.height ?? 1.6) * fontSize;
    // Rough estimate: ~0.5em average char width, one line per lineHeight.
    final charsPerLine = math.max(
      10,
      (pageSize.width / (fontSize * 0.5)).floor(),
    );
    final linesPerPage = math.max(1, (pageSize.height / lineHeight).floor());
    var estimate = charsPerLine * linesPerPage;
    estimate = estimate.clamp(1, n - start);

    bool fits(int end) {
      final tp = TextPainter(
        text: TextSpan(text: text.substring(start, end), style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: pageSize.width);
      return tp.size.height <= pageSize.height + 0.5;
    }

    int end;
    if (fits(start + estimate)) {
      // Fits: grow towards the true limit (cap the search window).
      var lo = start + estimate;
      var hi = math.min(n, start + (estimate * 2));
      if (hi == n && fits(n)) return _wordBoundary(text, start, n);
      while (lo < hi) {
        final mid = (lo + hi + 1) ~/ 2;
        if (fits(mid)) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      end = lo;
    } else {
      // Does not fit: shrink towards the true limit.
      var lo = start + 1;
      var hi = start + estimate;
      while (lo < hi) {
        final mid = (lo + hi + 1) ~/ 2;
        if (fits(mid)) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      end = lo;
    }
    return _wordBoundary(text, start, end);
  }

  /// Pull [end] back to the previous word boundary so a word is never
  /// split across pages (unless it is a single word longer than a page).
  static int _wordBoundary(String text, int start, int end) {
    if (end >= text.length) return end;
    if (end <= start) return end;
    final atEnd = text[end];
    final beforeEnd = text[end - 1];
    bool isSpace(String c) => c == ' ' || c == '\n' || c == '\t';
    if (isSpace(atEnd) || isSpace(beforeEnd)) return end;
    var i = end - 1;
    while (i > start && !isSpace(text[i])) {
      i--;
    }
    // No space found before start+some margin: keep the measured end
    // (TextPainter will wrap the long word mid-word, as a real book would).
    if (i <= start + 10) return end;
    return i;
  }

  /// Page index whose start offset is the last one <= [charOffset].
  /// Used to jump the table of contents to the exact page.
  static int pageForChar(List<TextPage> pages, int charOffset) {
    var page = 0;
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].start <= charOffset) {
        page = i;
      } else {
        break;
      }
    }
    return page;
  }
}

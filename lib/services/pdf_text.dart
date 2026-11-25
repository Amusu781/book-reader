import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// The result of converting a PDF into reflowable text.
class PdfReflow {
  /// The whole book as plain text, paragraphs separated by blank lines.
  final String text;

  /// Char offset in [text] where each original PDF page starts, so
  /// progress can be mapped between the restyled text and the PDF's
  /// original pages.
  final List<int> pageStarts;

  /// Table of contents from the PDF's bookmarks: (title, page index).
  final List<(String, int)> outline;

  final int pageCount;

  const PdfReflow({
    required this.text,
    required this.pageStarts,
    required this.outline,
    required this.pageCount,
  });

  /// True when the PDF has (almost) no extractable text — a scanned
  /// book made of page images. Those fall back to the original layout.
  bool get hasText {
    final letters = text.replaceAll(RegExp(r'\s'), '').length;
    return letters >= 40 && letters >= pageCount * 15;
  }

  /// PDF page (0-based) that contains [charOffset].
  int pageForChar(int charOffset) {
    var page = 0;
    for (var i = 0; i < pageStarts.length; i++) {
      if (pageStarts[i] <= charOffset) {
        page = i;
      } else {
        break;
      }
    }
    return page;
  }

  /// First char offset of PDF page [page] (0-based).
  int charForPage(int page) {
    if (pageStarts.isEmpty) return 0;
    return pageStarts[page.clamp(0, pageStarts.length - 1)];
  }

  Map<String, dynamic> toJson() => {
    'v': PdfTextService.cacheVersion,
    'text': text,
    'pageStarts': pageStarts,
    'outline': outline.map((e) => [e.$1, e.$2]).toList(),
    'pageCount': pageCount,
  };

  static PdfReflow? fromJson(Map<String, dynamic> j) {
    if (j['v'] != PdfTextService.cacheVersion) return null;
    return PdfReflow(
      text: j['text'] as String,
      pageStarts: (j['pageStarts'] as List)
          .map((e) => (e as num).toInt())
          .toList(),
      outline: (j['outline'] as List)
          .map((e) => ((e as List)[0] as String, (e[1] as num).toInt()))
          .toList(),
      pageCount: (j['pageCount'] as num).toInt(),
    );
  }
}

/// Converts imported PDFs into text the reader can restyle (page
/// themes, textures, font size, line spacing, night mode, leaf turn).
///
/// Extraction is pure Dart (syncfusion_flutter_pdf), runs in a
/// background isolate so the UI never freezes, works fully offline,
/// and is cached next to the book (`<book>.reflow.json`) so each PDF
/// is only converted once.
class PdfTextService {
  static const cacheVersion = 1;

  static File cacheFileFor(String pdfPath) => File('$pdfPath.reflow.json');

  /// Extract (or load the cached) reflowable text for [pdfPath].
  static Future<PdfReflow> load(String pdfPath) async {
    final cache = cacheFileFor(pdfPath);
    if (await cache.exists()) {
      try {
        final cached = PdfReflow.fromJson(
          jsonDecode(await cache.readAsString()) as Map<String, dynamic>,
        );
        if (cached != null) return cached;
      } catch (_) {
        // Corrupt cache: re-extract below.
      }
    }
    final bytes = await File(pdfPath).readAsBytes();
    final reflow = await Isolate.run(() => extractFromBytes(bytes));
    try {
      await cache.writeAsString(jsonEncode(reflow.toJson()));
    } catch (_) {
      // Cache is an optimisation only.
    }
    return reflow;
  }

  /// Synchronous extraction (used inside the isolate, and by tests).
  static PdfReflow extractFromBytes(List<int> bytes) {
    final doc = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(doc);
      final pageCount = doc.pages.count;
      final buffer = StringBuffer();
      final starts = <int>[];
      for (var i = 0; i < pageCount; i++) {
        starts.add(buffer.length);
        String raw;
        try {
          raw = extractor.extractText(startPageIndex: i, endPageIndex: i);
        } catch (_) {
          raw = '';
        }
        final page = reflowPageText(raw);
        if (page.isNotEmpty) {
          buffer.write(page);
          buffer.write('\n\n');
        }
      }
      final outline = <(String, int)>[];
      try {
        void walk(PdfBookmarkBase base, int depth) {
          for (var i = 0; i < base.count; i++) {
            final bm = base[i];
            final dest = bm.destination;
            if (dest != null) {
              final index = doc.pages.indexOf(dest.page);
              if (index >= 0 && bm.title.trim().isNotEmpty) {
                outline.add(('${'  ' * depth}${bm.title.trim()}', index));
              }
            }
            if (depth < 2) walk(bm, depth + 1);
          }
        }

        walk(doc.bookmarks, 0);
      } catch (_) {
        // A broken outline must not stop the book opening.
      }
      return PdfReflow(
        text: buffer.toString().trimRight(),
        pageStarts: starts,
        outline: outline,
        pageCount: pageCount,
      );
    } finally {
      doc.dispose();
    }
  }

  /// Turn one PDF page's hard-wrapped lines back into flowing
  /// paragraphs: join lines that were only broken for the PDF's column
  /// width, mend words hyphenated across a line break, and keep real
  /// paragraph breaks (blank lines, short last lines, sentence ends
  /// followed by a capital).
  static String reflowPageText(String raw) {
    final lines = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .toList();
    final nonEmpty = lines.where((l) => l.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return '';
    final lengths = nonEmpty.map((l) => l.length).toList()..sort();
    final typical =
        lengths[(lengths.length * 0.75).floor().clamp(0, lengths.length - 1)];

    final out = StringBuffer();
    var paragraph = StringBuffer();
    void endParagraph() {
      final p = paragraph.toString().trim();
      if (p.isNotEmpty) {
        if (out.isNotEmpty) out.write('\n\n');
        out.write(p);
      }
      paragraph = StringBuffer();
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) {
        endParagraph();
        continue;
      }
      // Lone page numbers are page furniture, not text.
      if (RegExp(r'^\d{1,4}$').hasMatch(line)) continue;
      final current = paragraph.toString();
      if (current.isEmpty) {
        paragraph.write(line);
      } else if (current.endsWith('-') &&
          RegExp(
            r'[a-z]$',
          ).hasMatch(current.substring(0, current.length - 1)) &&
          RegExp(r'^[a-z]').hasMatch(line)) {
        // "begin-\nning" -> "beginning"
        final s = current.substring(0, current.length - 1);
        paragraph = StringBuffer(s)..write(line);
      } else {
        paragraph.write(' ');
        paragraph.write(line);
      }
      final next = i + 1 < lines.length ? lines[i + 1] : '';
      final shortLine = typical > 30 && line.length < typical * 0.6;
      final sentenceEnd = RegExp(r'[.!?:"”’)]$').hasMatch(line);
      final nextStartsNew =
          next.isNotEmpty && RegExp(r'^[A-Z0-9“"‘(•\-–—]').hasMatch(next);
      if (shortLine && sentenceEnd && nextStartsNew) endParagraph();
      // A short heading-like line on its own.
      if (shortLine &&
          !sentenceEnd &&
          nextStartsNew &&
          line.length < 50 &&
          line == line.toUpperCase() &&
          RegExp(r'[A-Z]').hasMatch(line)) {
        endParagraph();
      }
    }
    endParagraph();
    return out.toString();
  }
}

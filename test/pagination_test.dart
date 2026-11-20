import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_reader/services/book_parser.dart';

void main() {
  testWidgets('measured pagination fits every page and covers the text',
      (tester) async {
    const lorem =
        'It was a bright cold day in April, and the clocks were striking thirteen. '
        'Winston Smith, his chin nuzzled into his breast in an effort to escape the '
        'vile wind, slipped quickly through the glass doors of Victory Mansions, '
        'though not quickly enough to prevent a swirl of gritty dust from entering along with him. ';
    final text = List.filled(12, lorem).join('\n\n');
    const style = TextStyle(fontSize: 18, height: 1.6);
    const size = Size(300, 400);

    final pages = BookParser.paginateMeasured(text, style, size);
    expect(pages.length, greaterThan(1));

    // Every page fits its box when laid out with the same style.
    for (final page in pages) {
      final tp = TextPainter(
        text: TextSpan(text: page.text, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      expect(tp.size.height, lessThanOrEqualTo(size.height + 0.5));
      expect(page.end, greaterThan(page.start));
    }

    // Pages chain across the whole text (only whitespace may be skipped
    // between pages) and no word is split across a boundary.
    for (var i = 0; i < pages.length - 1; i++) {
      final end = pages[i].end;
      final nextStart = pages[i + 1].start;
      expect(nextStart, greaterThanOrEqualTo(end));
      final gap = text.substring(end, nextStart);
      expect(gap.trim(), isEmpty);
      if (end < text.length) {
        final atEnd = text[end];
        final beforeEnd = text[end - 1];
        bool isSpace(String c) => c == ' ' || c == '\n' || c == '\t';
        expect(isSpace(atEnd) || isSpace(beforeEnd), isTrue);
      }
    }
    expect(pages.first.start, 0);
    expect(pages.last.end, text.length);

    // TOC lookup: every chapter offset lands on the page that holds it.
    for (var i = 0; i < pages.length; i++) {
      expect(BookParser.pageForChar(pages, pages[i].start), i);
      if (pages[i].end > pages[i].start) {
        expect(BookParser.pageForChar(pages, pages[i].end - 1), i);
      }
    }

    // Deterministic: paginating twice gives identical pages.
    final again = BookParser.paginateMeasured(text, style, size);
    expect(again.length, pages.length);
    for (var i = 0; i < pages.length; i++) {
      expect(again[i].start, pages[i].start);
      expect(again[i].end, pages[i].end);
    }
  });

  testWidgets('pagination handles empty text and a single long word',
      (tester) async {
    const style = TextStyle(fontSize: 18, height: 1.6);
    const size = Size(300, 400);
    expect(BookParser.paginateMeasured('', style, size).length, 1);
    final longWord = 'a' * 5000;
    final pages = BookParser.paginateMeasured(longWord, style, size);
    expect(pages.length, greaterThan(1));
    expect(pages.first.start, 0);
    expect(pages.last.end, longWord.length);
  });
}

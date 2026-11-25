import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:book_reader/models/book.dart';
import 'package:book_reader/screens/library_screen.dart';
import 'package:book_reader/services/app_prefs.dart';
import 'package:book_reader/services/library_service.dart';
import 'package:book_reader/services/pdf_text.dart';
import 'package:book_reader/widgets/bookshelf.dart';
import 'package:book_reader/widgets/leaf_turn_view.dart';

Book _book(
  String id,
  String title, {
  String shelf = 'want',
  String series = '',
  double? part,
  String genre = '',
  int order = 0,
}) => Book(
  id: id,
  title: title,
  author: 'A',
  filePath: '/tmp/$id.txt',
  format: BookFormat.txt,
  shelfId: shelf,
  addedAtMillis: 1,
  order: order,
  series: series,
  seriesIndex: part,
  genre: genre,
);

LibraryService _lib(List<Book> books) => LibraryService()
  ..shelves = [
    Shelf(id: 'reading', name: 'Currently Reading', isDefault: true),
    Shelf(id: 'want', name: 'Want to Read', isDefault: true),
  ]
  ..books = books
  ..loaded = true;

List<int> _pdfBytes(List<String> pages) {
  final doc = PdfDocument();
  final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
  for (final text in pages) {
    final page = doc.pages.add();
    if (text.isNotEmpty) {
      page.graphics.drawString(
        text,
        font,
        bounds: const Rect.fromLTWH(0, 0, 500, 700),
      );
    }
  }
  final bytes = doc.saveSync();
  doc.dispose();
  return bytes;
}

/// A tall phone screen so several bookcases are laid out at once.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412 * 3, 2400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('1 · bookcases, series and genre', () {
    testWidgets('every shelf is a bookcase with a brass name plate', (
      tester,
    ) async {
      _phone(tester);
      final lib = _lib([
        _book('a', 'Dune', shelf: 'reading'),
        _book('b', 'Emma'),
      ]);
      final prefs = AppPrefs()
        ..loaded = true
        ..focusOnboardingDone = true;
      await tester.pumpWidget(
        MaterialApp(
          home: LibraryScreen(library: lib, prefs: prefs),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShelfRow), findsNWidgets(2));
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is BookcaseFramePainter,
        ),
        findsNWidgets(2),
      );
      expect(find.text('Add a bookcase'), findsOneWidget);
    });

    test('a full board wraps onto the next board of the same case', () {
      final books = List.generate(30, (i) => _book('x$i', 'Book number $i'));
      final rows = ShelfRow.layoutRows(
        books,
        LibraryStyle.classic,
        360 - 32 - 28,
      );
      expect(rows.length, greaterThan(2));
      expect(rows.expand((r) => r).toList(), List.generate(30, (i) => i));
    });

    test('series grouping keeps parts in reading order', () {
      final lib = _lib([
        _book('3', 'The Return', series: 'Rings', part: 3),
        _book('1', 'Fellowship', series: 'Rings', part: 1),
        _book('2', 'Two Towers', series: 'Rings', part: 2),
        _book('z', 'Loose Book'),
      ]);
      final groups = lib.groupBySeries();
      expect(groups.first.$1, 'Rings');
      expect(groups.first.$2.map((b) => b.id), ['1', '2', '3']);
      expect(groups.last.$1, 'Not in a series');
    });

    test('genre grouping', () {
      final lib = _lib([
        _book('a', 'A', genre: 'Fantasy'),
        _book('b', 'B', genre: 'History'),
        _book('c', 'C'),
      ]);
      expect(lib.groupByGenre().map((g) => g.$1), [
        'Fantasy',
        'History',
        'No genre yet',
      ]);
    });

    test('series, genre and resume fields persist; old JSON still loads', () {
      final b = _book('s', 'Part Two', series: 'Saga', part: 2, genre: 'Epic')
        ..lastCharOffset = 1234
        ..pdfOriginalLayout = true;
      final back = Book.fromJsonString(b.toJsonString());
      expect(back.series, 'Saga');
      expect(back.seriesIndex, 2);
      expect(back.genre, 'Epic');
      expect(back.lastCharOffset, 1234);
      expect(back.pdfOriginalLayout, true);
      final v2 = jsonDecode(b.toJsonString()) as Map<String, dynamic>
        ..remove('series')
        ..remove('seriesIndex')
        ..remove('genre')
        ..remove('lastCharOffset')
        ..remove('pdfOriginalLayout');
      final old = Book.fromJson(v2);
      expect(old.series, '');
      expect(old.lastCharOffset, -1);
      expect(old.pdfOriginalLayout, false);
    });

    testWidgets('arrange by series shows one bookcase per series', (
      tester,
    ) async {
      _phone(tester);
      final lib = _lib([
        _book('1', 'Fellowship', series: 'Rings', part: 1),
        _book('2', 'Two Towers', series: 'Rings', part: 2),
        _book('z', 'Loose Book'),
      ]);
      final prefs = AppPrefs()
        ..loaded = true
        ..focusOnboardingDone = true
        ..grouping = LibraryGrouping.series;
      await tester.pumpWidget(
        MaterialApp(
          home: LibraryScreen(library: lib, prefs: prefs),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rings'), findsOneWidget);
      expect(find.text('2 parts'), findsOneWidget);
      expect(find.text('Not in a series'), findsOneWidget);
    });

    testWidgets('edit details sets series and genre', (tester) async {
      _phone(tester);
      final lib = _lib([_book('a', 'Dune')]);
      final prefs = AppPrefs()
        ..loaded = true
        ..focusOnboardingDone = true;
      await tester.pumpWidget(
        MaterialApp(
          home: LibraryScreen(library: lib, prefs: prefs),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Dune'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit details'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Series'),
        'Dune Chronicles',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Part'), '1');
      await tester.enterText(find.widgetWithText(TextField, 'Genre'), 'Sci-fi');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final b = lib.books.single;
      expect(b.series, 'Dune Chronicles');
      expect(b.seriesIndex, 1);
      expect(b.genre, 'Sci-fi');
    });
  });

  group('2 · library settings (style) and 5 · Focus Mode', () {
    testWidgets('first launch asks for Focus Mode; Not now turns it off', (
      tester,
    ) async {
      _phone(tester);
      final prefs = AppPrefs();
      await prefs.load();
      await tester.pumpWidget(
        MaterialApp(
          home: LibraryScreen(
            library: _lib([_book('a', 'Dune')]),
            prefs: prefs,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Read without interruptions?'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(prefs.focusOnboardingDone, true);
      expect(prefs.focusModeDefault, false);
      final reloaded = AppPrefs();
      await reloaded.load();
      expect(reloaded.focusOnboardingDone, true);
    });

    testWidgets('first launch: Allow turns Focus Mode on by default', (
      tester,
    ) async {
      _phone(tester);
      final prefs = AppPrefs();
      await prefs.load();
      await tester.pumpWidget(
        MaterialApp(
          home: LibraryScreen(library: _lib([]), prefs: prefs),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow Focus Mode'));
      await tester.pumpAndSettle();
      expect(prefs.focusModeDefault, true);
    });

    testWidgets('top-right gear: style + focus switch persist', (tester) async {
      _phone(tester);
      final prefs = AppPrefs()
        ..loaded = true
        ..focusOnboardingDone = true;
      await tester.pumpWidget(
        MaterialApp(
          home: LibraryScreen(
            library: _lib([_book('a', 'Dune')]),
            prefs: prefs,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Library settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ancient'));
      await tester.pumpAndSettle();
      expect(prefs.style, LibraryStyle.ancient);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(prefs.focusModeDefault, true);
      final reloaded = AppPrefs();
      await reloaded.load();
      expect(reloaded.style, LibraryStyle.ancient);
      expect(reloaded.focusModeDefault, true);
    });

    testWidgets('spines render in every style', (tester) async {
      _phone(tester);
      for (final style in LibraryStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BookSpine(book: _book('a', 'Dune'), style: style),
            ),
          ),
        );
        expect(find.text('Dune'), findsOneWidget);
      }
    });
  });

  group('3 · PDFs convert to restyleable text', () {
    test('text PDF is extracted page by page with a page map', () {
      final bytes = _pdfBytes([
        'Chapter One\nIt was a dark and stormy night, and the rain fell in torrents.',
        'Page two begins here with the second part of the story.',
      ]);
      final r = PdfTextService.extractFromBytes(bytes);
      expect(r.pageCount, 2);
      expect(r.hasText, true);
      expect(r.text, contains('dark and stormy night'));
      expect(r.text, contains('second part of the story'));
      expect(r.pageStarts.length, 2);
      final p2 = r.text.indexOf('Page two');
      expect(r.pageForChar(p2), 1);
      expect(r.pageForChar(0), 0);
      expect(r.charForPage(1), lessThanOrEqualTo(p2));
    });

    test(
      'scanned (no text) PDF is detected for the original-layout fallback',
      () {
        final r = PdfTextService.extractFromBytes(_pdfBytes(['', '']));
        expect(r.hasText, false);
      },
    );

    test('hard-wrapped lines reflow into paragraphs, hyphens mended', () {
      const raw =
          'This is a long line of text that the PDF wrapped at the\n'
          'column edge and it continues on the next line with a beauti-\n'
          'ful word broken across lines.\n'
          '\n'
          'A new paragraph starts here.\n'
          '12';
      final out = PdfTextService.reflowPageText(raw);
      expect(out, contains('at the column edge'));
      expect(out, contains('beautiful word'));
      expect(out, contains('lines.\n\nA new paragraph'));
      expect(out, isNot(contains('12')));
    });

    test('reflow cache round-trips', () {
      const r = PdfReflow(
        text: 'abc',
        pageStarts: [0, 2],
        outline: [('Intro', 0)],
        pageCount: 2,
      );
      final back = PdfReflow.fromJson(
        jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>,
      )!;
      expect(back.pageStarts, [0, 2]);
      expect(back.outline.single.$1, 'Intro');
    });
  });

  group('4 · page turn folds to the LEFT', () {
    test('fold line moves right-to-left as the turn progresses', () {
      const w = 400.0;
      var last = double.infinity;
      for (final t in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]) {
        final g = LeafFoldGeometry(w, t);
        expect(g.foldX, lessThan(last + 0.001));
        last = g.foldX;
        // The flap lies LEFT of the fold, never right of it.
        expect(g.flapLeft, lessThanOrEqualTo(g.flapRight));
        expect(g.flapRight, lessThanOrEqualTo(g.foldX + 0.001));
      }
      expect(const LeafFoldGeometry(w, 0).foldX, w);
      expect(const LeafFoldGeometry(w, 1).foldX, 0);
      // The free edge of the leaf travels twice as fast, leftward.
      expect(const LeafFoldGeometry(w, 0.25).edgeX, 200);
    });

    testWidgets('tap right edge turns forward with a leftward fold', (
      tester,
    ) async {
      var page = 0;
      final key = GlobalKey<LeafTurnViewState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 600,
              child: LeafTurnView(
                key: key,
                pageCount: 3,
                initialPage: 0,
                onPageChanged: (p) => page = p,
                onTapMiddle: () {},
                pageBuilder: (_, i) => ColoredBox(
                  color: Colors.white,
                  child: Center(child: Text('Page $i')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(390, 300));
      await tester.pump(); // turn starts this frame
      await tester.pump(const Duration(milliseconds: 200));
      final fold = tester.widget<LeafFold>(find.byType(LeafFold));
      expect(fold.t, greaterThan(0));
      expect(key.currentState!.direction, 1);
      await tester.pumpAndSettle();
      expect(page, 1);
      // Back: the previous leaf returns from the left (t falls to 0).
      await tester.tapAt(const Offset(10, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final early = tester.widget<LeafFold>(find.byType(LeafFold)).t;
      await tester.pump(const Duration(milliseconds: 250));
      final later = tester.widget<LeafFold>(find.byType(LeafFold)).t;
      expect(later, lessThan(early));
      await tester.pumpAndSettle();
      expect(page, 0);
    });
  });
}

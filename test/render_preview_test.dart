import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:book_reader/models/book.dart';
import 'package:book_reader/screens/library_screen.dart';
import 'package:book_reader/screens/reader_screen.dart';
import 'package:book_reader/services/app_prefs.dart';
import 'package:book_reader/services/library_service.dart';
import 'package:book_reader/widgets/leaf_turn_view.dart';
import 'package:book_reader/widgets/page_texture.dart';
import 'package:book_reader/services/reader_theme.dart';

/// Reader-level PDF test, plus optional PNG previews of the new look.
/// Previews are written only when RR_PREVIEW_DIR is set, e.g.
///   RR_PREVIEW_DIR=/tmp/rr flutter test test/render_preview_test.dart
final _previewDir = Platform.environment['RR_PREVIEW_DIR'];

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File(f);
      if (file.existsSync()) {
        loader.addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
      }
    }
    await loader.load();
  }

  const serif = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf',
  ];
  const sans = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
  ];
  await load('serif', serif);
  await load('sans-serif', sans);
  await load('Roboto', sans);
  await load('MaterialIcons', [
    '${Platform.environment['FLUTTER_ROOT'] ?? '/home/hatch/flutter'}'
        '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

Future<void> _snap(WidgetTester tester, String name) async {
  if (_previewDir == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('snap')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_previewDir!).createSync(recursive: true);
    File('$_previewDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Book _b(String id, String title, String shelf, {double progress = 0}) => Book(
  id: id,
  title: title,
  author: 'Author',
  filePath: '/tmp/$id.txt',
  format: BookFormat.txt,
  shelfId: shelf,
  addedAtMillis: 1,
  progress: progress,
);

void main() {
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(412 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  for (final style in LibraryStyle.values) {
    testWidgets('library room preview — ${style.name}', (tester) async {
      phone(tester);
      final lib = LibraryService()
        ..shelves = [
          Shelf(id: 'reading', name: 'Currently Reading', isDefault: true),
          Shelf(id: 'want', name: 'Want to Read', isDefault: true),
          Shelf(id: 'fav', name: 'Favourites', isDefault: true),
        ]
        ..books = [
          _b('1', 'The Library at Dusk', 'reading', progress: 0.4),
          _b('2', 'Basic5 Mathematics Exam', 'reading', progress: 0.1),
          _b('3', 'The Metamorphosis', 'want'),
          _b('4', 'Pride and Prejudice', 'want'),
          _b('5', 'Things Fall Apart', 'want'),
          _b('6', 'Half of a Yellow Sun', 'want'),
          _b('7', 'Purple Hibiscus', 'want'),
          _b('8', 'The Odyssey', 'want'),
          _b('9', 'Beowulf', 'want'),
          _b('10', 'Meditations', 'fav', progress: 1),
          _b('11', 'Arrow of God', 'fav'),
        ]
        ..loaded = true;
      final prefs = AppPrefs()
        ..loaded = true
        ..focusOnboardingDone = true
        ..style = style;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('snap'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E4A3D),
              ),
              fontFamily: 'serif',
            ),
            home: LibraryScreen(library: lib, prefs: prefs),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Things Fall Apart'), findsOneWidget);
      await _snap(tester, 'library_${style.name}');
    });
  }

  testWidgets('leaf fold preview (mid-turn, folding left)', (tester) async {
    phone(tester);
    Widget page(int i) => PageTexture(
      theme: PageTheme.frayed,
      pageIndex: i,
      nightMode: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          i == 0
              ? 'Page 1\n\n${'It was the best of times, it was the worst of times. ' * 12}'
              : 'Page 2\n\n${'Call me Ishmael. Some years ago, never mind how long. ' * 12}',
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 17,
            height: 1.5,
            color: Color(0xFF3B2F23),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('snap'),
        child: MaterialApp(
          home: Material(
            child: LeafFold(t: 0.35, front: page(0), under: page(1)),
          ),
        ),
      ),
    );
    await tester.pump();
    await _snap(tester, 'leaf_fold_t035');
  });

  testWidgets('imported PDF opens restyled: page theme + night mode apply', (
    tester,
  ) async {
    phone(tester);
    // Build a real 2-page text PDF on disk.
    final dir = Directory.systemTemp.createTempSync('rr_pdf');
    final file = File('${dir.path}/story.pdf');
    final doc = PdfDocument();
    final font = PdfStandardFont(PdfFontFamily.timesRoman, 12);
    for (final t in [
      'The rain came down over Lagos lagoon, and the ferry horns sounded twice.',
      'Second page: the market woke slowly, stall by stall, under grey skies.',
    ]) {
      doc.pages.add().graphics.drawString(
        t,
        font,
        bounds: const Rect.fromLTWH(0, 0, 480, 700),
      );
    }
    file.writeAsBytesSync(doc.saveSync());
    doc.dispose();

    SharedPreferences.setMockInitialValues({'reader_theme': 'ancient'});
    final book = Book(
      id: 'pdf1',
      title: 'Story PDF',
      author: 'Tester',
      filePath: file.path,
      format: BookFormat.pdf,
      shelfId: 'want',
      addedAtMillis: 1,
    );
    final lib = LibraryService()
      ..books = [book]
      ..shelves = [Shelf(id: 'want', name: 'Want to Read')]
      ..loaded = true;

    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('snap'),
        child: MaterialApp(
          home: ReaderScreen(book: book, library: lib),
        ),
      ),
    );
    // Extraction runs in an isolate: let real async work happen.
    for (
      var i = 0;
      i < 40 && find.byType(PageTexture).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();
    final pageWidget = tester.widget<PageTexture>(
      find.byType(PageTexture).first,
    );
    expect(
      pageWidget.theme,
      PageTheme.ancient,
      reason: 'page style applies to PDF',
    );
    expect(find.textContaining('ferry horns'), findsOneWidget);
    expect(find.byTooltip('Original PDF layout'), findsOneWidget);
    expect(
      File('${file.path}.reflow.json').existsSync(),
      true,
      reason: 'cached',
    );
    await _snap(tester, 'pdf_restyled_ancient');
    dir.deleteSync(recursive: true);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:book_reader/models/book.dart';
import 'package:book_reader/screens/library_screen.dart';
import 'package:book_reader/services/library_service.dart';

LibraryService _libraryWithBooks() {
  return LibraryService()
    ..shelves = [
      Shelf(id: 'reading', name: 'Currently Reading', isDefault: true),
      Shelf(id: 'want', name: 'Want to Read', isDefault: true),
    ]
    ..books = [
      Book(
        id: 'b1',
        title: 'Dune',
        author: 'Frank Herbert',
        filePath: '/tmp/dune.txt',
        format: BookFormat.txt,
        shelfId: 'reading',
        addedAtMillis: 1,
        order: 0,
      ),
      Book(
        id: 'b2',
        title: 'Foundation',
        author: 'Isaac Asimov',
        filePath: '/tmp/foundation.txt',
        format: BookFormat.txt,
        shelfId: 'reading',
        addedAtMillis: 2,
        order: 1000,
      ),
      Book(
        id: 'b3',
        title: 'Neuromancer',
        author: 'William Gibson',
        filePath: '/tmp/neuromancer.txt',
        format: BookFormat.txt,
        shelfId: 'want',
        addedAtMillis: 3,
        order: 0,
      ),
    ]
    ..loaded = true;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('library home renders shelves and spines',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LibraryScreen(library: _libraryWithBooks())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Currently Reading'), findsOneWidget);
    expect(find.text('Want to Read'), findsOneWidget);
    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Foundation'), findsOneWidget);
    expect(find.text('Neuromancer'), findsOneWidget);
  });

  testWidgets('long-press drag reorders a spine without crashing',
      (tester) async {
    final library = _libraryWithBooks();
    await tester.pumpWidget(
      MaterialApp(home: LibraryScreen(library: library)),
    );
    await tester.pumpAndSettle();

    // Long-press Dune, wait past the 250ms drag delay, drag right
    // across Foundation's slot, release.
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Dune')));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Foundation'), findsOneWidget);
  });

  testWidgets('plain long-press opens the book menu', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LibraryScreen(library: _libraryWithBooks())),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Dune'));
    await tester.pumpAndSettle();

    expect(find.text('Move to shelf…'), findsOneWidget);
  });
}

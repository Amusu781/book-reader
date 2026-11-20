import 'package:flutter/material.dart';
import 'config.dart';
import 'screens/library_screen.dart';
import 'services/library_service.dart';

void main() {
  runApp(const BookReaderApp());
}

class BookReaderApp extends StatefulWidget {
  const BookReaderApp({super.key});

  @override
  State<BookReaderApp> createState() => _BookReaderAppState();
}

class _BookReaderAppState extends State<BookReaderApp> {
  final _library = LibraryService();

  @override
  void initState() {
    super.initState();
    _library.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E4A3D)),
        useMaterial3: true,
        fontFamily: 'serif',
      ),
      home: AnimatedBuilder(
        animation: _library,
        builder: (_, __) {
          if (!_library.loaded) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return LibraryScreen(library: _library);
        },
      ),
    );
  }
}

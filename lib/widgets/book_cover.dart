import 'package:flutter/material.dart';
import '../models/book.dart';

/// Simple generated cover: warm library colours, title + author.
/// Real covers from EPUB files are a v2 improvement.
class BookCover extends StatelessWidget {
  final Book book;
  final double width;
  final double height;
  const BookCover({super.key, required this.book, this.width = 110, this.height = 160});

  static const _palette = [
    Color(0xFF5D4037),
    Color(0xFF2E4A3D),
    Color(0xFF3E4A6B),
    Color(0xFF6B3E4A),
    Color(0xFF7A5C2E),
    Color(0xFF37474F),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[book.title.hashCode.abs() % _palette.length];
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.35), width: 4)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'serif',
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            book.author,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            book.format.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

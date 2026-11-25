import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/app_prefs.dart';
import 'book_spine.dart';
import 'leaf_turn_view.dart';

/// Opening a book: the book's cover appears, then swings open by
/// folding over TO THE LEFT (the same leftward fold as a page turn),
/// revealing the reader underneath.
class BookOpenRoute<T> extends PageRouteBuilder<T> {
  final Book book;
  final LibraryStyle style;

  BookOpenRoute({
    required this.book,
    required this.style,
    required WidgetBuilder builder,
  }) : super(
         transitionDuration: const Duration(milliseconds: 900),
         reverseTransitionDuration: const Duration(milliseconds: 300),
         pageBuilder: (context, _, __) => builder(context),
         transitionsBuilder: (context, animation, secondary, child) {
           if (animation.status == AnimationStatus.reverse) {
             // Closing the book: a quick fade back to the library.
             return FadeTransition(opacity: animation, child: child);
           }
           return AnimatedBuilder(
             animation: animation,
             builder: (context, _) {
               final a = animation.value;
               if (a >= 1) return child;
               // 0.00-0.30: the cover rises into view.
               // 0.30-1.00: the cover folds open to the left.
               final rise = Curves.easeOut.transform(
                 (a / 0.30).clamp(0.0, 1.0),
               );
               final fold = Curves.easeInOut.transform(
                 ((a - 0.30) / 0.70).clamp(0.0, 1.0),
               );
               return Opacity(
                 opacity: rise,
                 child: Transform.scale(
                   scale: 0.88 + 0.12 * rise,
                   child: LeafFold(
                     t: fold,
                     backColor: const Color(0xFFEFE6D2),
                     front: BookCoverFace(book: book, style: style),
                     under: child,
                   ),
                 ),
               );
             },
           );
         },
       );
}

/// A full-screen book cover in the library style, used by the opening
/// animation.
class BookCoverFace extends StatelessWidget {
  final Book book;
  final LibraryStyle style;
  const BookCoverFace({super.key, required this.book, required this.style});

  @override
  Widget build(BuildContext context) {
    final color = BookSpine.colorFor(book, style);
    final gold = style == LibraryStyle.modern ? Colors.white : style.gold;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.lerp(color, Colors.black, 0.45)!,
            color,
            Color.lerp(color, Colors.black, 0.15)!,
          ],
          stops: const [0, 0.12, 1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 80, 28, 60),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: gold.withValues(alpha: 0.7), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  book.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: gold,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 60,
                  height: 1.5,
                  color: gold.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 18),
                Text(
                  book.author,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: gold.withValues(alpha: 0.85),
                    fontFamily: 'serif',
                    fontSize: 16,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

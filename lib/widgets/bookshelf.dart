import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/book.dart';

/// The visual bookshelf: books stand upright as vertical spines on a
/// wooden plank. Drag a spine (long-press and drag) to reorder it
/// within its shelf or carry it onto another shelf's row.
class ShelfRow extends StatelessWidget {
  final Shelf shelf;
  final List<Book> books;
  final bool enableDrop;
  final void Function(Book book) onOpen;
  final void Function(Book book) onLongPressMenu;
  final void Function(Book dragged, String targetShelfId, int targetIndex)
      onReorder;

  const ShelfRow({
    super.key,
    required this.shelf,
    required this.books,
    this.enableDrop = true,
    required this.onOpen,
    required this.onLongPressMenu,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Text(
                  shelf.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${books.length} book${books.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            // The scroll view gives this child unbounded width, so a
            // stretch Column on its own would force its children to an
            // infinite width and crash layout. IntrinsicWidth sizes the
            // Column to the Row of spines, so the plank below stretches
            // to exactly the shelf's width.
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ...books.asMap().entries.map((entry) {
                        final index = entry.key;
                        final book = entry.value;
                        return _ShelfDropTarget(
                          // A spine never accepts itself: dropping a book
                          // back where it started is a no-op, so a plain
                          // long-press-and-release falls through to the
                          // book menu instead of a phantom reorder.
                          accept: (dragged) =>
                              enableDrop && dragged.id != book.id,
                          onAccept: (dragged) =>
                              onReorder(dragged, shelf.id, index),
                          child: _DraggableSpine(
                            book: book,
                            onOpen: () => onOpen(book),
                            onLongPressMenu: () => onLongPressMenu(book),
                          ),
                        );
                      }),
                      // Empty plank space at the end of the row: dropping
                      // here appends the book to this shelf.
                      _ShelfDropTarget(
                        accept: (dragged) =>
                            enableDrop &&
                            !(books.isNotEmpty &&
                                books.last.id == dragged.id &&
                                dragged.shelfId == shelf.id),
                        onAccept: (dragged) =>
                            onReorder(dragged, shelf.id, books.length),
                        child: const SizedBox(width: 72, height: 120),
                      ),
                    ],
                  ),
                  const SizedBox(height: 0),
                  _Plank(seed: shelf.id.hashCode),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A drop zone on a shelf row. While a book hovers over it, a green
/// insertion bar shows where the book will land.
class _ShelfDropTarget extends StatelessWidget {
  final Widget child;
  final bool Function(Book dragged) accept;
  final void Function(Book dragged) onAccept;

  const _ShelfDropTarget({
    required this.child,
    required this.accept,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Book>(
      onWillAcceptWithDetails: (details) => accept(details.data),
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (candidateData.isNotEmpty)
              Container(
                width: 4,
                height: 150,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF8FBC8F),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            child,
          ],
        );
      },
    );
  }
}

class _DraggableSpine extends StatelessWidget {
  final Book book;
  final VoidCallback onOpen;
  final VoidCallback onLongPressMenu;

  const _DraggableSpine({
    required this.book,
    required this.onOpen,
    required this.onLongPressMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: LongPressDraggable<Book>(
        data: book,
        delay: const Duration(milliseconds: 250),
        feedback: Material(
          color: Colors.transparent,
          child: Transform.scale(
            scale: 1.06,
            child: BookSpine(book: book, lifted: true),
          ),
        ),
        // Distinct spine instances for the two slots: the child and
        // childWhenDragging are never mounted at once, but sharing one
        // widget instance between them is fragile.
        childWhenDragging: Opacity(opacity: 0.3, child: BookSpine(book: book)),
        // Long-press and release without moving shows the book menu
        // (move to shelf / remove). Long-press and drag reorders.
        onDragEnd: (details) {
          if (!details.wasAccepted) onLongPressMenu();
        },
        child: GestureDetector(
          onTap: onOpen,
          child: BookSpine(book: book),
        ),
      ),
    );
  }
}

/// One book standing on the plank: a vertical spine whose colour,
/// height and width come from a hash of the title, with the title
/// written vertically along the spine.
class BookSpine extends StatelessWidget {
  final Book book;
  final bool lifted;
  const BookSpine({super.key, required this.book, this.lifted = false});

  static const _palette = [
    Color(0xFF5D4037),
    Color(0xFF2E4A3D),
    Color(0xFF3E4A6B),
    Color(0xFF6B3E4A),
    Color(0xFF7A5C2E),
    Color(0xFF37474F),
    Color(0xFF6D4C41),
    Color(0xFF4E342E),
  ];

  @override
  Widget build(BuildContext context) {
    final hash = book.title.hashCode.abs();
    final color = _palette[hash % _palette.length];
    final height = 150.0 + (hash % 5) * 8; // 150-182
    final width = 46.0 + (hash % 3) * 4; // 46-54
    final progress = book.progress.clamp(0, 1).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color.withValues(alpha: 0.75),
                color,
                color.withValues(alpha: 0.85),
              ],
              stops: const [0, 0.35, 1],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
              topRight: Radius.circular(3),
            ),
            boxShadow: lifted
                ? const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 12,
                      offset: Offset(4, 6),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 3,
                      offset: Offset(2, 1),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              // Decorative bands near the top and bottom, like a real spine.
              Positioned(
                left: 0,
                right: 0,
                top: 10,
                child: Container(
                  height: 2,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: Container(
                  height: 2,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SizedBox(
                    width: height - 36,
                    child: Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'serif',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: width,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            color: progress >= 1
                ? const Color(0xFF8FBC8F)
                : const Color(0xFFD9B36A),
            minHeight: 3,
          ),
        ),
      ],
    );
  }
}

/// The wooden plank the spines stand on: a wood gradient with grain
/// lines and a soft shadow underneath.
class _Plank extends StatelessWidget {
  final int seed;
  const _Plank({required this.seed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: CustomPaint(
          painter: _PlankPainter(seed: seed),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF8A6844), Color(0xFF6B4A2B)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlankPainter extends CustomPainter {
  final int seed;
  const _PlankPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    // Top highlight, then a few horizontal grain streaks.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 1.5),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    final rng = math.Random(seed);
    for (var i = 0; i < 3; i++) {
      final y = 3 + rng.nextDouble() * (size.height - 5);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 28) {
        path.lineTo(x, y + math.sin(x / 60 + i) * 1.2);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    // Soft radial shading so the plank reads as rounded wood.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          [
            Colors.white.withValues(alpha: 0.06),
            Colors.black.withValues(alpha: 0.12),
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(_PlankPainter old) => old.seed != seed;
}

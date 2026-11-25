import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/app_prefs.dart';
import 'book_spine.dart';

export 'book_spine.dart' show BookSpine;

/// One shelf of the library, drawn as a real piece of furniture: a
/// bookcase with a crown moulding and a brass name plate on top, two
/// side panels, a dark back panel with inner walls that give it depth,
/// shelf boards with a front lip, and a plinth with feet. Books fill
/// the boards left to right; when a board is full the next book goes
/// on the board below, so a big shelf becomes a taller bookcase.
/// Adding a shelf adds a whole new bookcase to the room.
///
/// Drag a spine (long-press and drag) to reorder it within its case or
/// carry it into another bookcase.
class ShelfRow extends StatelessWidget {
  final Shelf shelf;
  final List<Book> books;
  final bool enableDrop;
  final LibraryStyle style;
  final String? subtitle;
  final void Function(Book book) onOpen;
  final void Function(Book book) onLongPressMenu;
  final void Function(Book dragged, String targetShelfId, int targetIndex)
  onReorder;

  const ShelfRow({
    super.key,
    required this.shelf,
    required this.books,
    this.enableDrop = true,
    this.style = LibraryStyle.classic,
    this.subtitle,
    required this.onOpen,
    required this.onLongPressMenu,
    required this.onReorder,
  });

  static const sideWidth = 16.0;
  static const crownHeight = 40.0;
  static const plinthHeight = 22.0;
  static const boardHeight = 20.0; // top face + front lip
  static const innerDepth = 11.0; // how deep the inner walls look
  static const compartmentHeight = 196.0;
  static const endSlotWidth = 56.0;

  /// Split the books into boards that fit [innerWidth]. The last board
  /// always keeps room for the "drop here to add at the end" slot.
  static List<List<int>> layoutRows(
    List<Book> books,
    LibraryStyle style,
    double innerWidth,
  ) {
    final usable = innerWidth - innerDepth * 2 - 8;
    final rows = <List<int>>[[]];
    var x = 0.0;
    for (var i = 0; i < books.length; i++) {
      final w = BookSpine.slotWidth(books[i], style);
      if (x + w > usable && rows.last.isNotEmpty) {
        rows.add([]);
        x = 0;
      }
      rows.last.add(i);
      x += w;
    }
    if (x + endSlotWidth > usable && rows.last.isNotEmpty) rows.add([]);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final innerWidth = constraints.maxWidth - sideWidth * 2;
          final rows = layoutRows(books, style, innerWidth);
          return Stack(
            children: [
              CustomPaint(
                painter: BookcaseFramePainter(
                  style: style,
                  seed: shelf.id.hashCode,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    sideWidth,
                    crownHeight,
                    sideWidth,
                    plinthHeight,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var r = 0; r < rows.length; r++) ...[
                        _Compartment(
                          style: style,
                          child: _buildBoard(
                            rows[r],
                            isLast: r == rows.length - 1,
                          ),
                        ),
                        _ShelfBoard(style: style, seed: shelf.id.hashCode + r),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 13,
                left: 0,
                right: 0,
                child: Center(
                  child: _NamePlate(
                    name: shelf.name,
                    detail:
                        subtitle ??
                        '${books.length} book${books.length == 1 ? '' : 's'}',
                    style: style,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBoard(List<int> indexes, {required bool isLast}) {
    return Padding(
      padding: const EdgeInsets.only(left: innerDepth + 4, right: innerDepth),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final index in indexes)
            _ShelfDropTarget(
              // A spine never accepts itself: dropping a book back where
              // it started is a no-op, so a plain long-press-and-release
              // falls through to the book menu instead of a phantom
              // reorder.
              accept: (dragged) => enableDrop && dragged.id != books[index].id,
              onAccept: (dragged) => onReorder(dragged, shelf.id, index),
              child: _DraggableSpine(
                book: books[index],
                style: style,
                onOpen: () => onOpen(books[index]),
                onLongPressMenu: () => onLongPressMenu(books[index]),
              ),
            ),
          if (isLast)
            // Empty board space at the end: dropping here appends the
            // book to this bookcase.
            Expanded(
              child: _ShelfDropTarget(
                fill: true,
                accept: (dragged) =>
                    enableDrop &&
                    !(books.isNotEmpty &&
                        books.last.id == dragged.id &&
                        dragged.shelfId == shelf.id),
                onAccept: (dragged) =>
                    onReorder(dragged, shelf.id, books.length),
                child: SizedBox(
                  width: double.infinity,
                  height: compartmentHeight - 16,
                  child: books.isEmpty
                      ? Center(
                          child: Text(
                            enableDrop
                                ? 'Empty shelf — drag a book here'
                                : 'No books here yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NamePlate extends StatelessWidget {
  final String name;
  final String detail;
  final LibraryStyle style;
  const _NamePlate({
    required this.name,
    required this.detail,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final brass = style == LibraryStyle.modern
        ? const [Color(0xFFF3F1EC), Color(0xFFD9D5CC)]
        : style == LibraryStyle.ancient
        ? const [Color(0xFFB89A5A), Color(0xFF7D6332)]
        : const [Color(0xFFE6C878), Color(0xFFAF8838)];
    final ink = style == LibraryStyle.modern
        ? const Color(0xFF2B2B2B)
        : const Color(0xFF2A1A08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: brass,
        ),
        borderRadius: BorderRadius.circular(
          style == LibraryStyle.ancient ? 1 : 3,
        ),
        border: Border.all(color: Colors.black.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 3,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ink,
                fontFamily: 'serif',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            detail,
            style: TextStyle(color: ink.withValues(alpha: 0.75), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// The inside of one compartment: the dark back panel, the inner side
/// walls (lit on the left, shaded on the right) and the underside of
/// the board above, so books look like they sit inside a box.
class _Compartment extends StatelessWidget {
  final LibraryStyle style;
  final Widget child;
  const _Compartment({required this.style, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ShelfRow.compartmentHeight,
      child: CustomPaint(
        painter: CompartmentPainter(style: style),
        child: Align(alignment: Alignment.bottomLeft, child: child),
      ),
    );
  }
}

class CompartmentPainter extends CustomPainter {
  final LibraryStyle style;
  const CompartmentPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const d = ShelfRow.innerDepth;
    final wood = style.wood;

    // Back panel: darker wood with vertical board seams.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [
          Color.lerp(wood[2], Colors.black, 0.35)!,
          wood[2],
        ]),
    );
    final seam = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (var x = d + 38.0; x < w - d; x += 46) {
      canvas.drawLine(Offset(x, d), Offset(x, h), seam);
    }

    // Left inner wall (catches the room light).
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(d, d)
        ..lineTo(d, h)
        ..lineTo(0, h)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(d, 0), [
          wood[1],
          Color.lerp(wood[1], wood[2], 0.6)!,
        ]),
    );
    // Right inner wall (in shadow).
    canvas.drawPath(
      Path()
        ..moveTo(w, 0)
        ..lineTo(w - d, d)
        ..lineTo(w - d, h)
        ..lineTo(w, h)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(Offset(w, 0), Offset(w - d, 0), [
          Color.lerp(wood[2], Colors.black, 0.2)!,
          Color.lerp(wood[2], Colors.black, 0.5)!,
        ]),
    );
    // Underside of the board above.
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(w, 0)
        ..lineTo(w - d, d)
        ..lineTo(d, d)
        ..close(),
      Paint()..color = Color.lerp(wood[2], Colors.black, 0.55)!,
    );
    // Soft ambient shadow hanging under the top board.
    canvas.drawRect(
      Rect.fromLTWH(d, d, w - 2 * d, 34),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, d),
          const Offset(0, d + 34),
          [
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0),
          ],
        ),
    );
    // Warm light pooling on the back panel.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(Offset(w * 0.4, h * 0.75), w * 0.7, [
          const Color(
            0xFFFFD9A0,
          ).withValues(alpha: style == LibraryStyle.modern ? 0.12 : 0.08),
          const Color(0x00FFD9A0),
        ]),
    );
  }

  @override
  bool shouldRepaint(CompartmentPainter old) => old.style != style;
}

/// A shelf board seen from slightly above: the top face (narrower at
/// the back, so it reads as depth), the front lip with a highlight
/// along its edge, and wood grain.
class _ShelfBoard extends StatelessWidget {
  final LibraryStyle style;
  final int seed;
  const _ShelfBoard({required this.style, required this.seed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ShelfRow.boardHeight,
      child: CustomPaint(
        painter: ShelfBoardPainter(style: style, seed: seed),
      ),
    );
  }
}

class ShelfBoardPainter extends CustomPainter {
  final LibraryStyle style;
  final int seed;
  const ShelfBoardPainter({required this.style, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const d = ShelfRow.innerDepth;
    const top = 7.0; // depth of the visible top face
    final wood = style.wood;

    // Top face: a trapezoid from the back (inset) to the front edge.
    canvas.drawPath(
      Path()
        ..moveTo(d, -0.5)
        ..lineTo(w - d, -0.5)
        ..lineTo(w, top)
        ..lineTo(0, top)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, top), [
          Color.lerp(wood[1], Colors.black, 0.25)!,
          wood[0],
        ]),
    );
    // Front lip.
    final lip = Rect.fromLTWH(0, top, w, size.height - top);
    canvas.drawRect(
      lip,
      Paint()
        ..shader = ui.Gradient.linear(
          lip.topLeft,
          lip.bottomLeft,
          [wood[0], wood[1], Color.lerp(wood[1], Colors.black, 0.35)!],
          const [0, 0.45, 1],
        ),
    );
    canvas.drawLine(
      Offset(0, top + 0.5),
      Offset(w, top + 0.5),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = 1,
    );
    // Grain on the lip.
    final rng = math.Random(seed);
    for (var i = 0; i < 3; i++) {
      final y = top + 3 + rng.nextDouble() * (size.height - top - 5);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= w; x += 20) {
        path.lineTo(x, y + math.sin(x / 45 + i * 2) * 0.9);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.black.withValues(alpha: 0.13),
      );
    }
  }

  @override
  bool shouldRepaint(ShelfBoardPainter old) =>
      old.style != style || old.seed != seed;
}

/// The outer bookcase: drop shadow on the room, side panels with a
/// bevel and grain, crown moulding on top, plinth with feet below.
class BookcaseFramePainter extends CustomPainter {
  final LibraryStyle style;
  final int seed;
  const BookcaseFramePainter({required this.style, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const side = ShelfRow.sideWidth;
    const crown = ShelfRow.crownHeight;
    const plinth = ShelfRow.plinthHeight;
    final wood = style.wood;

    // Shadow the case casts on the wall and floor.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 9, w, h),
        const Radius.circular(4),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    Paint woodPaint(Rect r, {bool across = true, double darken = 0}) =>
        Paint()
          ..shader = ui.Gradient.linear(
            r.topLeft,
            across ? r.topRight : r.bottomLeft,
            [
              Color.lerp(wood[0], Colors.black, darken)!,
              Color.lerp(wood[1], Colors.black, darken)!,
              Color.lerp(wood[1], Colors.black, (darken + 0.25).clamp(0, 1))!,
            ],
            const [0, 0.55, 1],
          );

    // Side panels.
    final left = Rect.fromLTWH(0, crown - 6, side, h - crown - plinth + 12);
    final right = Rect.fromLTWH(
      w - side,
      crown - 6,
      side,
      h - crown - plinth + 12,
    );
    canvas.drawRect(left, woodPaint(left));
    canvas.drawRect(right, woodPaint(right, darken: 0.12));
    _grain(canvas, left, vertical: true);
    _grain(canvas, right, vertical: true);
    final bevel = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(
      left.topLeft + const Offset(1, 0),
      left.bottomLeft + const Offset(1, 0),
      bevel,
    );
    canvas.drawLine(
      right.topLeft + const Offset(1, 0),
      right.bottomLeft + const Offset(1, 0),
      bevel,
    );
    final edge = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(
      left.topRight - const Offset(0.5, 0),
      left.bottomRight - const Offset(0.5, 0),
      edge,
    );
    canvas.drawLine(
      right.topRight - const Offset(0.5, 0),
      right.bottomRight - const Offset(0.5, 0),
      edge,
    );

    // Crown moulding: a cornice that overhangs the sides a little.
    final cornice = Rect.fromLTWH(-4, 0, w + 8, 12);
    canvas.drawRect(cornice, woodPaint(cornice, across: false));
    final frieze = Rect.fromLTWH(0, 12, w, crown - 12);
    canvas.drawRect(frieze, woodPaint(frieze, across: false, darken: 0.08));
    canvas.drawLine(
      const Offset(-4, 12),
      Offset(w + 4, 12),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      const Offset(-4, 1),
      Offset(w + 4, 1),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..strokeWidth = 1,
    );
    if (style != LibraryStyle.modern) {
      // Dentil row under the cornice (classic/ancient joinery).
      final dentil = Paint()..color = Colors.black.withValues(alpha: 0.22);
      for (var x = 6.0; x < w - 6; x += 9) {
        canvas.drawRect(Rect.fromLTWH(x, 13, 5, 4), dentil);
      }
    }
    _grain(canvas, frieze, vertical: false);

    // Plinth with feet.
    final base = Rect.fromLTWH(-2, h - plinth, w + 4, plinth - 5);
    canvas.drawRect(base, woodPaint(base, across: false, darken: 0.1));
    canvas.drawLine(
      Offset(-2, h - plinth),
      Offset(w + 2, h - plinth),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..strokeWidth = 1,
    );
    final footPaint = Paint()..color = Color.lerp(wood[2], Colors.black, 0.2)!;
    canvas.drawRect(Rect.fromLTWH(2, h - 5, 22, 5), footPaint);
    canvas.drawRect(Rect.fromLTWH(w - 24, h - 5, 22, 5), footPaint);

    if (style == LibraryStyle.ancient) {
      // Iron corner brackets on the old hall's cases.
      final iron = Paint()
        ..color = const Color(0xFF2B2B2B).withValues(alpha: 0.85);
      for (final c in [Offset(0, crown - 6), Offset(w - side, crown - 6)]) {
        canvas.drawRect(Rect.fromLTWH(c.dx, c.dy, side, 6), iron);
        canvas.drawCircle(
          c + const Offset(side / 2, 3),
          1.4,
          Paint()..color = const Color(0xFF777777),
        );
      }
    }
  }

  void _grain(Canvas canvas, Rect r, {required bool vertical}) {
    final rng = math.Random(seed ^ r.left.toInt() ^ r.top.toInt());
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.black.withValues(alpha: 0.12);
    for (var i = 0; i < 4; i++) {
      final path = Path();
      if (vertical) {
        final x = r.left + 2 + rng.nextDouble() * (r.width - 4);
        path.moveTo(x, r.top);
        for (var y = r.top; y <= r.bottom; y += 18) {
          path.lineTo(x + math.sin(y / 40 + i) * 1.2, y);
        }
      } else {
        final y = r.top + 2 + rng.nextDouble() * (r.height - 4);
        path.moveTo(r.left, y);
        for (var x = r.left; x <= r.right; x += 18) {
          path.lineTo(x, y + math.sin(x / 50 + i) * 1.0);
        }
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(BookcaseFramePainter old) =>
      old.style != style || old.seed != seed;
}

/// A drop zone on a board. While a book hovers over it, a glowing
/// insertion bar shows where the book will land.
class _ShelfDropTarget extends StatelessWidget {
  final Widget child;
  final bool fill;
  final bool Function(Book dragged) accept;
  final void Function(Book dragged) onAccept;

  const _ShelfDropTarget({
    required this.child,
    required this.accept,
    required this.onAccept,
    this.fill = false,
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
                  color: const Color(0xFFFFD27A),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: const [
                    BoxShadow(color: Color(0xAAFFD27A), blurRadius: 6),
                  ],
                ),
              ),
            if (fill) Expanded(child: child) else child,
          ],
        );
      },
    );
  }
}

class _DraggableSpine extends StatelessWidget {
  final Book book;
  final LibraryStyle style;
  final VoidCallback onOpen;
  final VoidCallback onLongPressMenu;

  const _DraggableSpine({
    required this.book,
    required this.style,
    required this.onOpen,
    required this.onLongPressMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: LongPressDraggable<Book>(
        data: book,
        delay: const Duration(milliseconds: 250),
        feedback: Material(
          color: Colors.transparent,
          child: Transform.rotate(
            angle: -0.06,
            child: Transform.scale(
              scale: 1.08,
              child: BookSpine(book: book, style: style, lifted: true),
            ),
          ),
        ),
        // Distinct spine instances for the two slots.
        childWhenDragging: Opacity(
          opacity: 0.25,
          child: BookSpine(book: book, style: style),
        ),
        // Long-press and release without moving shows the book menu
        // (edit details / move to shelf / remove). Long-press and drag
        // reorders.
        onDragEnd: (details) {
          if (!details.wasAccepted) onLongPressMenu();
        },
        child: GestureDetector(
          onTap: onOpen,
          child: BookSpine(book: book, style: style),
        ),
      ),
    );
  }
}

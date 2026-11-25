import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/app_prefs.dart';

/// One book standing on a shelf, seen spine-first.
///
/// The spine is painted, not a flat box: a rounded-spine highlight
/// (cylindrical shading), a cloth weave (Modern), leather grain with
/// gold bands and a title label (Classic) or worn, cracked leather
/// with raised gilded bands (Ancient). Colour, height and width come
/// from a hash of the title, so every book looks different but always
/// looks the same.
class BookSpine extends StatelessWidget {
  final Book book;
  final LibraryStyle style;
  final bool lifted;

  const BookSpine({
    super.key,
    required this.book,
    this.style = LibraryStyle.classic,
    this.lifted = false,
  });

  static int _hash(Book b) {
    // Stable across runs (String.hashCode is not guaranteed stable).
    var h = 2166136261;
    for (final c in b.title.codeUnits) {
      h = ((h ^ c) * 16777619) & 0x7fffffff;
    }
    return h;
  }

  /// Spine size for [book] in [style]. Used by the bookcase to work
  /// out how many books fit on each shelf board.
  static Size sizeFor(Book book, LibraryStyle style) {
    final h = _hash(book);
    final height = 138.0 + (h % 7) * 7; // 138-180
    var width = 30.0 + ((h >> 3) % 6) * 5; // 30-55
    if (style == LibraryStyle.ancient) width += 6; // thick old volumes
    return Size(width, height);
  }

  /// The spine (and cover) colour for [book] in [style].
  static Color colorFor(Book book, LibraryStyle style) {
    final palette = style.spinePalette;
    return palette[_hash(book) % palette.length];
  }

  /// Full footprint including the gap to the next book.
  static double slotWidth(Book book, LibraryStyle style) =>
      sizeFor(book, style).width + 3;

  @override
  Widget build(BuildContext context) {
    final size = sizeFor(book, style);
    final hash = _hash(book);
    final palette = style.spinePalette;
    final color = palette[hash % palette.length];
    final progress = book.progress.clamp(0, 1).toDouble();
    final titleColor = style.gold;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: lifted ? 0.6 : 0.45),
              blurRadius: lifted ? 14 : 4,
              offset: lifted ? const Offset(6, 8) : const Offset(3, 0),
            ),
          ],
        ),
        child: CustomPaint(
          painter: SpinePainter(
            color: color,
            style: style,
            seed: hash,
            progress: progress,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: style == LibraryStyle.modern ? 14 : 30,
              horizontal: 2,
            ),
            child: Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        style == LibraryStyle.modern &&
                            color.computeLuminance() > 0.45
                        ? const Color(0xFF1E1E1E)
                        : titleColor,
                    fontFamily: style == LibraryStyle.modern
                        ? 'sans-serif'
                        : 'serif',
                    fontWeight: FontWeight.bold,
                    letterSpacing: style == LibraryStyle.modern ? 0.6 : 0.3,
                    fontSize: math.min(12.5, size.width * 0.34),
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(0.6, 0.6),
                        blurRadius: 0.8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SpinePainter extends CustomPainter {
  final Color color;
  final LibraryStyle style;
  final int seed;
  final double progress;

  const SpinePainter({
    required this.color,
    required this.style,
    required this.seed,
    required this.progress,
  });

  Color _shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final r = style == LibraryStyle.ancient ? 3.0 : 2.0;
    final body = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(r),
      topRight: Radius.circular(r),
      bottomLeft: const Radius.circular(1),
      bottomRight: const Radius.circular(1),
    );
    canvas.save();
    canvas.clipRRect(body);

    // Base colour (ancient spines are faded towards the top, where
    // light has hit them for centuries).
    final base = style == LibraryStyle.ancient
        ? [_shade(color, 0.08), color, _shade(color, -0.04)]
        : [color, color, color];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), base, const [
          0,
          0.5,
          1,
        ]),
    );

    final rng = math.Random(seed);
    switch (style) {
      case LibraryStyle.modern:
        _clothWeave(canvas, size);
      case LibraryStyle.classic:
        _leatherGrain(canvas, size, rng, 160, 0.05);
      case LibraryStyle.ancient:
        _leatherGrain(canvas, size, rng, 260, 0.08);
        _wear(canvas, size, rng);
    }

    // Rounded spine: dark at both edges, a soft highlight a third of
    // the way across, like light falling on a curved back.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(w, 0),
          [
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.0),
            Colors.white.withValues(
              alpha: style == LibraryStyle.modern ? 0.20 : 0.16,
            ),
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.6),
          ],
          const [0, 0.16, 0.34, 0.62, 1],
        ),
    );

    switch (style) {
      case LibraryStyle.modern:
        _modernBands(canvas, size);
      case LibraryStyle.classic:
        _goldBands(canvas, size, raised: false);
        _labelPanel(canvas, size);
      case LibraryStyle.ancient:
        _goldBands(canvas, size, raised: true);
    }

    // Top edge cap and a hint of the page block at the very top.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, 2),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // Reading progress: a thin ribbon-coloured bookmark tail at the
    // foot of the spine (green when finished).
    if (progress > 0) {
      final barH = 3.0;
      canvas.drawRect(
        Rect.fromLTWH(2, h - barH - 2, (w - 4) * progress, barH),
        Paint()
          ..color = progress >= 1
              ? const Color(0xFF8FBC8F)
              : const Color(0xFFE2B857),
      );
    }
    canvas.restore();
  }

  void _clothWeave(Canvas canvas, Size size) {
    final p = Paint()
      ..strokeWidth = 0.6
      ..color = Colors.white.withValues(alpha: 0.05);
    for (var x = 0.0; x < size.width; x += 2.0) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    final q = Paint()
      ..strokeWidth = 0.6
      ..color = Colors.black.withValues(alpha: 0.06);
    for (var y = 0.0; y < size.height; y += 2.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), q);
    }
  }

  void _leatherGrain(
    Canvas canvas,
    Size size,
    math.Random rng,
    int count,
    double alpha,
  ) {
    for (var i = 0; i < count; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final rad = 0.4 + rng.nextDouble() * 1.3;
      canvas.drawCircle(
        Offset(dx, dy),
        rad,
        Paint()
          ..color = (rng.nextBool() ? Colors.black : Colors.white).withValues(
            alpha: alpha * (0.5 + rng.nextDouble()),
          ),
      );
    }
  }

  /// Ancient leather: scuffed corners, cracks across the spine and a
  /// rubbed, lighter top and foot.
  void _wear(Canvas canvas, Size size, math.Random rng) {
    final w = size.width;
    final h = size.height;
    // Rubbed head and tail.
    for (final top in [true, false]) {
      canvas.drawRect(
        Rect.fromLTWH(0, top ? 0 : h - 14, w, 14),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, top ? 0 : h),
            Offset(0, top ? 14 : h - 14),
            [
              const Color(0xFFCDB58A).withValues(alpha: 0.35),
              const Color(0xFFCDB58A).withValues(alpha: 0.0),
            ],
          ),
      );
    }
    // Cracks: short jagged dark lines with a light lip.
    final crackCount = 4 + rng.nextInt(5);
    for (var i = 0; i < crackCount; i++) {
      var x = rng.nextDouble() * w * 0.3;
      var y = 20 + rng.nextDouble() * (h - 40);
      final path = Path()..moveTo(x, y);
      final steps = 3 + rng.nextInt(4);
      for (var s = 0; s < steps; s++) {
        x += w / steps * (0.6 + rng.nextDouble() * 0.6);
        y += (rng.nextDouble() * 2 - 1) * 3;
        path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = Colors.black.withValues(alpha: 0.45),
      );
      canvas.drawPath(
        path.shift(const Offset(0, 0.9)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = const Color(0xFFE0C9A0).withValues(alpha: 0.25),
      );
    }
    // Scuffed patches.
    for (var i = 0; i < 3; i++) {
      final c = Offset(rng.nextDouble() * w, rng.nextDouble() * h);
      canvas.drawCircle(
        c,
        3 + rng.nextDouble() * 6,
        Paint()
          ..color = const Color(0xFFBFA478).withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  void _modernBands(Canvas canvas, Size size) {
    // A contrasting colour block near the foot and a thin rule at the
    // head — a clean modern hardback.
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Rect.fromLTWH(0, h - 30, w, 18),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 8, w, 1.6),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  void _goldBands(Canvas canvas, Size size, {required bool raised}) {
    final w = size.width;
    final h = size.height;
    final gold = style.gold;
    final bands = raised
        ? [14.0, h * 0.22, h * 0.78, h - 18]
        : [10.0, 16.0, h - 20, h - 14];
    for (final y in bands) {
      if (raised) {
        // Raised band (a "hub" over the sewing cord): a ridge with a
        // highlight on top and a shadow below, gilded lines either side.
        canvas.drawRect(
          Rect.fromLTWH(0, y - 3, w, 6),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, y - 3),
              Offset(0, y + 3),
              [
                Colors.white.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.05),
                Colors.black.withValues(alpha: 0.5),
              ],
              const [0, 0.5, 1],
            ),
        );
        for (final o in [-4.5, 4.5]) {
          canvas.drawRect(
            Rect.fromLTWH(0, y + o - 0.6, w, 1.2),
            Paint()..color = gold.withValues(alpha: 0.75),
          );
        }
      } else {
        canvas.drawRect(
          Rect.fromLTWH(0, y, w, 1.6),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, 0),
              Offset(w, 0),
              [_shade(gold, -0.2), _shade(gold, 0.15), _shade(gold, -0.25)],
              const [0, 0.35, 1],
            ),
        );
      }
    }
  }

  /// Classic: a darker leather label panel framed in gold where the
  /// title sits.
  void _labelPanel(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final panel = Rect.fromLTWH(2, 26, w - 4, h - 56);
    canvas.drawRect(
      panel,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = style.gold.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(SpinePainter old) =>
      old.color != color ||
      old.style != style ||
      old.seed != seed ||
      old.progress != progress;
}

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/app_prefs.dart';

/// The library ROOM behind the bookcases, painted procedurally and
/// following the library style:
///  * Modern  — pale plaster wall, slim oak wainscot, pendant lamp glow,
///              light oak floor.
///  * Classic — deep green damask wallpaper above walnut wainscot
///              panels, brass wall-lamp glow, herringbone-ish parquet.
///  * Ancient — stone-block hall wall with an arched window of
///              moonlight, timber beams, worn flagstone floor.
/// The room stays put while the bookcases scroll over it, like
/// walking along the stacks. Painted once inside a RepaintBoundary.
class LibraryBackground extends StatelessWidget {
  final Widget child;
  final LibraryStyle style;
  const LibraryBackground({
    super.key,
    required this.child,
    this.style = LibraryStyle.classic,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: LibraryRoomPainter(style: style)),
          ),
        ),
        child,
      ],
    );
  }
}

class LibraryRoomPainter extends CustomPainter {
  final LibraryStyle style;
  const LibraryRoomPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final floorTop = h * 0.80;
    final wainscotTop = h * 0.56;

    switch (style) {
      case LibraryStyle.modern:
        _wall(canvas, Rect.fromLTWH(0, 0, w, floorTop), const [
          Color(0xFF8C8177),
          Color(0xFF6E645B),
        ]);
        _verticalLines(canvas, Rect.fromLTWH(0, 0, w, wainscotTop), 0.04);
        _wainscot(
          canvas,
          Rect.fromLTWH(0, wainscotTop, w, floorTop - wainscotTop),
          const Color(0xFF9C7B57),
          panels: 3,
        );
        _floorBoards(
          canvas,
          Rect.fromLTWH(0, floorTop, w, h - floorTop),
          const Color(0xFFB08A60),
        );
        _glow(
          canvas,
          Offset(w * 0.5, -h * 0.05),
          w * 1.1,
          const Color(0xFFFFF1D6),
          0.30,
        );
      case LibraryStyle.classic:
        _wall(canvas, Rect.fromLTWH(0, 0, w, floorTop), const [
          Color(0xFF233A2E),
          Color(0xFF16261D),
        ]);
        _damask(canvas, Rect.fromLTWH(0, 0, w, wainscotTop));
        _wainscot(
          canvas,
          Rect.fromLTWH(0, wainscotTop, w, floorTop - wainscotTop),
          const Color(0xFF4A2E1A),
          panels: 3,
        );
        _parquet(
          canvas,
          Rect.fromLTWH(0, floorTop, w, h - floorTop),
          const Color(0xFF5A3A20),
        );
        for (final x in [w * 0.15, w * 0.85]) {
          _glow(
            canvas,
            Offset(x, h * 0.12),
            w * 0.55,
            const Color(0xFFFFC46B),
            0.22,
          );
        }
      case LibraryStyle.ancient:
        _wall(canvas, Rect.fromLTWH(0, 0, w, floorTop), const [
          Color(0xFF4A443B),
          Color(0xFF2C2822),
        ]);
        _stoneBlocks(canvas, Rect.fromLTWH(0, 0, w, floorTop));
        _archWindow(
          canvas,
          Rect.fromLTWH(w * 0.32, h * 0.06, w * 0.36, h * 0.30),
        );
        _beams(canvas, w);
        _flagstones(canvas, Rect.fromLTWH(0, floorTop, w, h - floorTop));
        _glow(
          canvas,
          Offset(w * 0.5, h * 0.2),
          w * 0.8,
          const Color(0xFFBFD3FF),
          0.10,
        );
        _glow(
          canvas,
          Offset(w * 0.1, h * 0.7),
          w * 0.6,
          const Color(0xFFFF9C40),
          0.16,
        ); // candle/torch light
    }

    // Vignette so the bookcases sit in a pool of light.
    final radius = math.max(w, h) * 0.85;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w / 2, h * 0.42),
          radius,
          [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.45),
          ],
          [0.45, 1.0],
        ),
    );
  }

  void _wall(Canvas c, Rect r, List<Color> colors) {
    c.drawRect(
      r,
      Paint()..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, colors),
    );
  }

  void _verticalLines(Canvas c, Rect r, double alpha) {
    final p = Paint()..color = Colors.white.withValues(alpha: alpha);
    for (var x = r.left; x < r.right; x += 22) {
      c.drawRect(Rect.fromLTWH(x, r.top, 1, r.height), p);
    }
  }

  /// Repeating diamond-and-dot wallpaper motif.
  void _damask(Canvas c, Rect r) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFC9A75A).withValues(alpha: 0.10);
    final dot = Paint()
      ..color = const Color(0xFFC9A75A).withValues(alpha: 0.12);
    const sx = 34.0, sy = 44.0;
    var row = 0;
    for (var y = r.top; y < r.bottom; y += sy) {
      final offset = row.isOdd ? sx / 2 : 0.0;
      for (var x = r.left - sx + offset; x < r.right + sx; x += sx) {
        final cx = x, cy = y + sy / 2;
        final path = Path()
          ..moveTo(cx, cy - 14)
          ..quadraticBezierTo(cx + 9, cy, cx, cy + 14)
          ..quadraticBezierTo(cx - 9, cy, cx, cy - 14);
        c.drawPath(path, p);
        c.drawCircle(Offset(cx, cy), 2, dot);
      }
      row++;
    }
  }

  void _wainscot(Canvas c, Rect r, Color wood, {required int panels}) {
    c.drawRect(r, Paint()..color = wood);
    // Chair rail.
    c.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 8),
      Paint()..color = Color.lerp(wood, Colors.white, 0.18)!,
    );
    c.drawRect(
      Rect.fromLTWH(r.left, r.top + 8, r.width, 2),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );
    // Raised panels.
    final pw = (r.width - 16) / panels;
    for (var i = 0; i < panels; i++) {
      final pr = Rect.fromLTWH(
        r.left + 8 + i * pw + 6,
        r.top + 22,
        pw - 12,
        r.height - 40,
      );
      c.drawRect(pr, Paint()..color = Colors.black.withValues(alpha: 0.12));
      c.drawLine(
        pr.topLeft,
        pr.topRight,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..strokeWidth = 1.5,
      );
      c.drawLine(
        pr.topLeft,
        pr.bottomLeft,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.30)
          ..strokeWidth = 1.5,
      );
      c.drawLine(
        pr.bottomLeft,
        pr.bottomRight,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..strokeWidth = 1.5,
      );
      c.drawLine(
        pr.topRight,
        pr.bottomRight,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10)
          ..strokeWidth = 1.5,
      );
    }
    // Skirting.
    c.drawRect(
      Rect.fromLTWH(r.left, r.bottom - 10, r.width, 10),
      Paint()..color = Color.lerp(wood, Colors.black, 0.35)!,
    );
  }

  /// Floorboards in perspective: lines converge towards a vanishing
  /// point above the screen centre.
  void _floorBoards(Canvas c, Rect r, Color wood) {
    c.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [
          Color.lerp(wood, Colors.black, 0.35)!,
          wood,
        ]),
    );
    final vp = Offset(r.center.dx, r.top - r.height * 1.4);
    final p = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    for (var x = -r.width; x <= r.width * 2; x += r.width / 9) {
      final bottom = Offset(x, r.bottom);
      final t = (r.top - vp.dy) / (bottom.dy - vp.dy);
      final top = Offset(vp.dx + (bottom.dx - vp.dx) * t, r.top);
      c.drawLine(top, bottom, p);
    }
    // Horizontal board ends, closer together at the back.
    for (var i = 1; i < 6; i++) {
      final y = r.top + r.height * math.pow(i / 6, 1.6);
      c.drawLine(
        Offset(r.left, y),
        Offset(r.right, y),
        Paint()..color = Colors.black.withValues(alpha: 0.10),
      );
    }
  }

  void _parquet(Canvas c, Rect r, Color wood) {
    _floorBoards(c, r, wood);
    // A rug in front of the cases.
    final rug = Rect.fromLTWH(
      r.left + r.width * 0.12,
      r.top + r.height * 0.35,
      r.width * 0.76,
      r.height * 0.6,
    );
    c.drawRect(
      rug,
      Paint()..color = const Color(0xFF6B1F24).withValues(alpha: 0.75),
    );
    c.drawRect(
      rug.deflate(6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFC9A75A).withValues(alpha: 0.5),
    );
  }

  void _stoneBlocks(Canvas c, Rect r) {
    final rng = math.Random(1793);
    const bh = 30.0;
    var row = 0;
    for (var y = r.top; y < r.bottom; y += bh) {
      final offset = row.isOdd ? 28.0 : 0.0;
      var x = r.left - offset;
      while (x < r.right) {
        final bw = 46 + rng.nextDouble() * 30;
        final block = Rect.fromLTWH(x + 1, y + 1, bw - 2, bh - 2);
        c.drawRect(
          block,
          Paint()
            ..color = (rng.nextBool() ? Colors.white : Colors.black).withValues(
              alpha: 0.03 + rng.nextDouble() * 0.05,
            ),
        );
        c.drawLine(
          block.bottomLeft,
          block.bottomRight,
          Paint()..color = Colors.black.withValues(alpha: 0.35),
        );
        c.drawLine(
          block.topRight,
          block.bottomRight,
          Paint()..color = Colors.black.withValues(alpha: 0.30),
        );
        x += bw;
      }
      row++;
    }
  }

  void _archWindow(Canvas c, Rect r) {
    final arch = Path()
      ..moveTo(r.left, r.bottom)
      ..lineTo(r.left, r.top + r.width / 2)
      ..arcToPoint(
        Offset(r.right, r.top + r.width / 2),
        radius: Radius.circular(r.width / 2),
      )
      ..lineTo(r.right, r.bottom)
      ..close();
    c.drawPath(
      arch,
      Paint()
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [
          Color(0xFF2E4466),
          Color(0xFF1A2438),
        ]),
    );
    // Mullions.
    final bar = Paint()
      ..color = const Color(0xFF1A140E)
      ..strokeWidth = 3;
    c.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom), bar);
    for (var i = 1; i < 4; i++) {
      final y = r.top + r.width / 2 + (r.height - r.width / 2) * i / 4;
      c.drawLine(Offset(r.left, y), Offset(r.right, y), bar);
    }
    c.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = const Color(0xFF6E6656),
    );
    // Moon.
    c.drawCircle(
      Offset(r.left + r.width * 0.72, r.top + r.width * 0.42),
      7,
      Paint()..color = const Color(0xFFEFE6C8).withValues(alpha: 0.85),
    );
  }

  void _beams(Canvas c, double w) {
    final p = Paint()..color = const Color(0xFF2A1D12);
    c.drawRect(Rect.fromLTWH(0, 0, w, 14), p);
    c.drawRect(
      Rect.fromLTWH(0, 14, w, 3),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
  }

  void _flagstones(Canvas c, Rect r) {
    c.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [
          Color(0xFF2A2620),
          Color(0xFF4A4338),
        ]),
    );
    final rng = math.Random(77);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.black.withValues(alpha: 0.35);
    for (var y = r.top; y < r.bottom; y += 26) {
      var x = r.left - rng.nextDouble() * 30;
      while (x < r.right) {
        final sw = 50 + rng.nextDouble() * 40;
        c.drawRect(Rect.fromLTWH(x, y, sw, 26), p);
        x += sw;
      }
    }
  }

  void _glow(Canvas c, Offset center, double radius, Color color, double a) {
    c.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          color.withValues(alpha: a),
          color.withValues(alpha: 0),
        ]),
    );
  }

  @override
  bool shouldRepaint(LibraryRoomPainter old) => old.style != style;
}

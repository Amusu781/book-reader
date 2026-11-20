import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// The library wall behind the shelves: a warm dark wood wall, painted
/// procedurally — a vertical warm-brown gradient, subtle vertical
/// wood-grain stripes, a few wavy grain lines, and a soft vignette.
/// Painted once inside a RepaintBoundary; nothing here animates.
class LibraryBackground extends StatelessWidget {
  final Widget child;
  const LibraryBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: const _LibraryWallPainter(),
        child: child,
      ),
    );
  }
}

class _LibraryWallPainter extends CustomPainter {
  const _LibraryWallPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Warm dark wood, slightly lighter towards the top.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          const [Color(0xFF4A3222), Color(0xFF2E2015)],
        ),
    );

    // Vertical grain stripes: deterministic bands of slightly lighter
    // and darker wood running top to bottom.
    final rng = math.Random(20261120);
    const bandCount = 26;
    final bandWidth = size.width / bandCount;
    for (var i = 0; i < bandCount; i++) {
      final lighter = rng.nextBool();
      final alpha = 0.02 + rng.nextDouble() * 0.05;
      canvas.drawRect(
        Rect.fromLTWH(i * bandWidth, 0, bandWidth, size.height),
        Paint()
          ..color = (lighter ? const Color(0xFF8B6B45) : Colors.black)
              .withValues(alpha: alpha),
      );
      // A thin darker seam between planks every few bands.
      if (i % 4 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(i * bandWidth, 0, 1.5, size.height),
          Paint()..color = Colors.black.withValues(alpha: 0.12),
        );
      }
    }

    // A few wavy grain lines running down the wall.
    for (var i = 0; i < 7; i++) {
      final x0 = rng.nextDouble() * size.width;
      final amp = 4 + rng.nextDouble() * 10;
      final phase = rng.nextDouble() * math.pi * 2;
      final path = Path()..moveTo(x0, 0);
      for (var y = 0.0; y <= size.height; y += 24) {
        path.lineTo(x0 + math.sin(y / 90 + phase) * amp, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Soft vignette so the shelves sit in a pool of warm light.
    final radius = math.max(size.width, size.height) * 0.85;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * 0.42),
          radius,
          [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.32),
          ],
          [0.5, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(_LibraryWallPainter old) => false;
}

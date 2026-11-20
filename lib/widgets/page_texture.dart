import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/reader_theme.dart';

/// A reader page that looks like real paper, not a flat colour.
///
/// The painted paper sits underneath the text. Stains and the frayed
/// page edge are seeded by the page index, so they are identical every
/// frame — nothing shimmers or moves while reading. The whole page is
/// wrapped in a RepaintBoundary so turning a page only re-composites,
/// it never repaints the paper.
class PageTexture extends StatelessWidget {
  final PageTheme theme;
  final int pageIndex;
  final bool nightMode;
  final Widget child;

  const PageTexture({
    super.key,
    required this.theme,
    required this.pageIndex,
    required this.nightMode,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipPath(
        clipper: _PageEdgeClipper(theme: theme, pageIndex: pageIndex),
        child: CustomPaint(
          painter: _PageTexturePainter(
            theme: theme,
            pageIndex: pageIndex,
            nightMode: nightMode,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Slightly irregular page edge for the worn themes. Crisp pages keep a
/// straight edge. The wobble is deterministic per page.
class _PageEdgeClipper extends CustomClipper<Path> {
  final PageTheme theme;
  final int pageIndex;

  const _PageEdgeClipper({required this.theme, required this.pageIndex});

  double get _fray {
    switch (theme) {
      case PageTheme.crisp:
        return 0;
      case PageTheme.frayed:
        return 2.5;
      case PageTheme.ancient:
        return 4.5;
    }
  }

  @override
  Path getClip(Size size) {
    final fray = _fray;
    final path = Path();
    if (fray == 0) {
      path.addRect(Offset.zero & size);
      return path;
    }
    // Deterministic wobble, seeded by page + theme.
    final rng = math.Random(pageIndex * 1000003 + theme.index * 9176 + 12345);
    double wobble() => (rng.nextDouble() * 2 - 1) * fray;
    const step = 16.0;

    // Walk the edges clockwise, nudging each vertex in/out.
    path.moveTo(0, wobble());
    for (var y = step; y < size.height; y += step) {
      path.lineTo(wobble(), y + wobble());
    }
    path.lineTo(wobble(), size.height);
    for (var x = step; x < size.width; x += step) {
      path.lineTo(x + wobble(), size.height + wobble());
    }
    path.lineTo(size.width, size.height + wobble());
    for (var y = size.height - step; y > 0; y -= step) {
      path.lineTo(size.width + wobble(), y + wobble());
    }
    path.lineTo(size.width + wobble(), 0);
    for (var x = size.width - step; x > 0; x -= step) {
      path.lineTo(x + wobble(), wobble());
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_PageEdgeClipper old) =>
      old.theme != theme || old.pageIndex != pageIndex;
}

class _PageTexturePainter extends CustomPainter {
  final PageTheme theme;
  final int pageIndex;
  final bool nightMode;

  const _PageTexturePainter({
    required this.theme,
    required this.pageIndex,
    required this.nightMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (nightMode) {
      // Night reading: plain dark paper, faint vignette only.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, 0),
            Offset(0, size.height),
            const [Color(0xFF161616), Color(0xFF0E0E0E)],
          ),
      );
      _vignette(canvas, size, 0.25);
      return;
    }

    switch (theme) {
      case PageTheme.crisp:
        _crisp(canvas, size, rect);
      case PageTheme.frayed:
        _aged(canvas, size, rect, stainCount: 5, vignetteStrength: 0.10);
      case PageTheme.ancient:
        _aged(canvas, size, rect, stainCount: 9, vignetteStrength: 0.22);
    }
  }

  void _crisp(Canvas canvas, Size size, Rect rect) {
    // Clean new white page: soft top light, faint shadow at the spine.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          const [Color(0xFFFFFFFF), Color(0xFFF6F4EF)],
        ),
    );
    _spineShadow(canvas, size, 0.05);
  }

  void _aged(
    Canvas canvas,
    Size size,
    Rect rect, {
    required int stainCount,
    required double vignetteStrength,
  }) {
    final base = theme == PageTheme.ancient
        ? const [Color(0xFFE9D6A8), Color(0xFFD6B983)]
        : const [Color(0xFFF6EEDC), Color(0xFFEDDFBE)];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          base,
        ),
    );

    // Faint age stains: soft brown blotches, seeded per page.
    final rng = math.Random(pageIndex * 2654435761 + theme.index * 40503);
    for (var i = 0; i < stainCount; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final r = 18 + rng.nextDouble() * 46;
      final alpha = 0.05 + rng.nextDouble() * 0.05;
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          r,
          [
            Color(0xFF8B6F47).withValues(alpha: alpha),
            Color(0xFF8B6F47).withValues(alpha: 0),
          ],
        );
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    _spineShadow(canvas, size, theme == PageTheme.ancient ? 0.12 : 0.09);
    _vignette(canvas, size, vignetteStrength);
  }

  void _spineShadow(Canvas canvas, Size size, double strength) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, 30, size.height),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(30, 0),
          [
            Colors.black.withValues(alpha: strength),
            Colors.black.withValues(alpha: 0),
          ],
        ),
    );
  }

  void _vignette(Canvas canvas, Size size, double strength) {
    final radius = math.max(size.width, size.height) * 0.75;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height / 2),
          radius,
          [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: strength),
          ],
          [0.55, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(_PageTexturePainter old) =>
      old.theme != theme ||
      old.pageIndex != pageIndex ||
      old.nightMode != nightMode;
}

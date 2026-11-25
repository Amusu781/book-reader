import 'package:flutter/material.dart';

/// The fold geometry of a page turning LEFTWARD, like a real book: the
/// right-hand edge of the leaf lifts, folds over and travels to the
/// left, revealing the next page underneath from the right.
///
/// For a turn progress `t` in [0, 1] on a page of width `w`:
///  * the fold line sits at `foldX = w * (1 - t)` and moves right→left;
///  * the part of the leaf left of the fold is still lying flat;
///  * the part right of the fold has flipped over and lies mirrored
///    on top, from `edgeX = 2 * foldX - w` up to the fold;
///  * the page underneath shows to the right of the fold.
///
/// At t = 0 nothing has moved; at t = 1 the whole leaf has folded off
/// to the left and the page underneath is fully visible. The same
/// geometry with `t` running 1 → 0 is a backward turn: the previous
/// leaf comes back from the left and unfolds to the right.
class LeafFoldGeometry {
  final double width;
  final double t;
  const LeafFoldGeometry(this.width, this.t);

  double get foldX => width * (1 - t.clamp(0.0, 1.0));
  double get edgeX => 2 * foldX - width;

  /// Visible width of the flat, unturned part of the leaf.
  double get flatWidth => foldX.clamp(0.0, width);

  /// Visible span of the folded-over flap: [edgeX, foldX] clipped to
  /// the page.
  double get flapLeft => edgeX.clamp(0.0, width);
  double get flapRight => foldX.clamp(0.0, width);
}

/// Draws one moment of a leftward page fold. [front] is the leaf being
/// turned (its unturned part stays put); [under] is the page revealed
/// beneath it; [backColor] is the colour of the paper's reverse side.
class LeafFold extends StatelessWidget {
  final double t;
  final Widget front;
  final Widget under;
  final Color backColor;

  const LeafFold({
    super.key,
    required this.t,
    required this.front,
    required this.under,
    this.backColor = const Color(0xFFF3EAD3),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final g = LeafFoldGeometry(w, t);
        final fold = g.foldX;
        final flapW = g.flapRight - g.flapLeft;
        // How lifted the leaf is (0 flat, 1 at mid-turn): drives shadows.
        final lift = (1 - (2 * t - 1).abs()).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. The page underneath.
            under,
            // 2. Shadow the lifted leaf casts on the revealed page, just
            //    right of the fold.
            if (fold < w)
              Positioned(
                left: fold.clamp(0.0, w),
                top: 0,
                bottom: 0,
                width: 40,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.35 * lift + 0.08),
                          Colors.black.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // 3. The flat, not-yet-turned part of the leaf (left of the
            //    fold).
            if (g.flatWidth > 0)
              ClipRect(clipper: _SpanClipper(0, g.flatWidth), child: front),
            // 4. The folded-over flap: the reverse of the leaf, mirrored
            //    about the fold line, so it travels LEFT as t grows.
            if (flapW > 0)
              ClipRect(
                clipper: _SpanClipper(g.flapLeft, g.flapRight),
                child: Transform(
                  transform: Matrix4.translationValues(2 * fold, 0, 0)
                    ..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      front,
                      // The back of the paper: text shows through
                      // faintly, as it does on a real page.
                      ColoredBox(color: backColor.withValues(alpha: 0.86)),
                    ],
                  ),
                ),
              ),
            // 5. Curl shading on the flap: bright along the fold, darker
            //    towards its free (left) edge.
            if (flapW > 0)
              Positioned(
                left: g.flapLeft,
                width: flapW,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.white.withValues(alpha: 0.30),
                          Colors.black.withValues(alpha: 0.02),
                          Colors.black.withValues(alpha: 0.16),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
              ),
            // 6. The flap's own shadow on the flat leaf, left of its edge.
            if (flapW > 0 && g.flapLeft > 0)
              Positioned(
                left: (g.flapLeft - 18).clamp(0.0, w),
                width: g.flapLeft.clamp(0.0, 18.0),
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.black.withValues(alpha: 0.28 * lift),
                          Colors.black.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SpanClipper extends CustomClipper<Rect> {
  final double left;
  final double right;
  const _SpanClipper(this.left, this.right);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(left, 0, right.clamp(left, size.width), size.height);

  @override
  bool shouldReclip(_SpanClipper old) => old.left != left || old.right != right;
}

/// A single-page reader view where turning a page feels like turning a
/// physical leaf.
///
/// Forward (swipe left, or tap the right edge): the right edge of the
/// current page lifts and folds over TO THE LEFT, revealing the next
/// page from the right. Backward (swipe right, or tap the left edge):
/// the previous page comes back from the left and unfolds over the
/// current one. See [LeafFold] for the geometry.
///
/// A tap in the middle of the page calls [onTapMiddle] (used by the
/// reader to toggle its controls).
class LeafTurnView extends StatefulWidget {
  final int pageCount;
  final int initialPage;
  final Widget Function(BuildContext context, int index) pageBuilder;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTapMiddle;
  final Color backColor;

  const LeafTurnView({
    super.key,
    required this.pageCount,
    required this.initialPage,
    required this.pageBuilder,
    required this.onPageChanged,
    required this.onTapMiddle,
    this.backColor = const Color(0xFFF3EAD3),
  });

  @override
  State<LeafTurnView> createState() => LeafTurnViewState();
}

class LeafTurnViewState extends State<LeafTurnView>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  int _current = 0;
  int _direction = 1; // +1 forward, -1 back
  bool _turning = false;
  bool _dragging = false;
  double _dragDx = 0;

  int get currentPage => _current;
  int get direction => _direction;
  bool get isTurning => _turning;

  /// Fold progress for the current frame in forward-geometry terms
  /// (0 = flat, 1 = folded away to the left).
  double get foldT => _direction == 1 ? _anim.value : 1 - _anim.value;

  @override
  void initState() {
    super.initState();
    _current = widget.initialPage.clamp(0, widget.pageCount - 1);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// Jump to a page instantly (used for table-of-contents jumps).
  void jumpTo(int page) {
    final target = page.clamp(0, widget.pageCount - 1);
    if (target == _current && !_turning) return;
    setState(() {
      _current = target;
      _turning = false;
      _dragging = false;
      _anim.reset();
    });
  }

  /// Turn to a page with the leaf animation when it is adjacent,
  /// otherwise jump straight there.
  void turnTo(int page) {
    final target = page.clamp(0, widget.pageCount - 1);
    if (target == _current + 1) {
      turnForward();
    } else if (target == _current - 1) {
      turnBack();
    } else {
      jumpTo(target);
    }
  }

  Future<void> turnForward() => _turn(1);
  Future<void> turnBack() => _turn(-1);

  Future<void> _turn(int dir) async {
    if (_turning || _anim.isAnimating) return;
    if (dir == 1 && _current >= widget.pageCount - 1) return;
    if (dir == -1 && _current <= 0) return;
    setState(() {
      _turning = true;
      _direction = dir;
    });
    await _anim.forward(from: 0);
    if (!mounted) return;
    _finishTurn();
  }

  void _finishTurn() {
    setState(() {
      _current += _direction;
      _turning = false;
      _dragging = false;
      _anim.reset();
    });
    widget.onPageChanged(_current);
  }

  void _onTapUp(TapUpDetails details) {
    if (_turning || _anim.isAnimating) return;
    final width = context.size?.width ?? 0;
    if (width == 0) return;
    final x = details.localPosition.dx;
    if (x > width * 0.78) {
      turnForward();
    } else if (x < width * 0.22) {
      turnBack();
    } else {
      widget.onTapMiddle();
    }
  }

  void _onDragStart(DragStartDetails details) {
    if (_turning || _anim.isAnimating || widget.pageCount <= 1) return;
    _dragging = true;
    _dragDx = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _dragDx += details.delta.dx;
    if (!_turning) {
      if (_dragDx.abs() < 10) return;
      final forward = _dragDx < 0; // finger moves left = next page
      if (forward && _current >= widget.pageCount - 1) return;
      if (!forward && _current <= 0) return;
      setState(() {
        _turning = true;
        _direction = forward ? 1 : -1;
      });
    }
    final width = context.size?.width ?? 1;
    // The folded edge follows the finger: the edge travels twice as
    // fast as the fold line, so a full-width swipe completes the turn.
    _anim.value = (_dragDx.abs() / (width * 1.1)).clamp(0.0, 1.0);
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    if (!_dragging || !_turning) {
      _dragging = false;
      return;
    }
    _dragging = false;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final flingWithTurn =
        (_direction == 1 && velocity < -450) ||
        (_direction == -1 && velocity > 450);
    if (_anim.value > 0.35 || flingWithTurn) {
      await _anim.forward();
      if (!mounted) return;
      _finishTurn();
    } else {
      await _anim.reverse();
      if (!mounted) return;
      setState(() => _turning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _onTapUp,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: _turning
          ? AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                // Forward: current leaf folds away left over the next
                // page. Back: the previous leaf returns from the left
                // over the current page (same geometry, t reversed).
                final frontIndex = _direction == 1 ? _current : _current - 1;
                final underIndex = _direction == 1 ? _current + 1 : _current;
                return LeafFold(
                  t: foldT,
                  backColor: widget.backColor,
                  front: widget.pageBuilder(context, frontIndex),
                  under: widget.pageBuilder(context, underIndex),
                );
              },
            )
          : widget.pageBuilder(context, _current),
    );
  }
}

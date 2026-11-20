import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A single-page reader view where turning a page feels like turning a
/// physical leaf, not sliding a card.
///
/// How it works: the page being left rotates around its left (spine)
/// edge. Halfway through the turn the leaf is edge-on and invisible,
/// so the leaf's content swaps to the *back* of the leaf — the next
/// page, pre-rotated by pi about the same spine edge, which makes it
/// read the right way round as the leaf lands. The page underneath is
/// the destination page, revealed as the leaf lifts. The same motion
/// runs in reverse when going back a page.
///
/// Turns are driven by swipe (drag), by tapping the right/left page
/// edges, or programmatically via [LeafTurnViewState.turnTo]/[jumpTo].
/// A tap in the middle of the page calls [onTapMiddle] (used by the
/// reader to toggle its controls).
class LeafTurnView extends StatefulWidget {
  final int pageCount;
  final int initialPage;
  final Widget Function(BuildContext context, int index) pageBuilder;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTapMiddle;

  const LeafTurnView({
    super.key,
    required this.pageCount,
    required this.initialPage,
    required this.pageBuilder,
    required this.onPageChanged,
    required this.onTapMiddle,
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

  @override
  void initState() {
    super.initState();
    _current = widget.initialPage.clamp(0, widget.pageCount - 1);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
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
      _turnForward();
    } else if (target == _current - 1) {
      _turnBack();
    } else {
      jumpTo(target);
    }
  }

  Future<void> _turnForward() async {
    if (_turning || _anim.isAnimating) return;
    if (_current >= widget.pageCount - 1) return;
    setState(() {
      _turning = true;
      _direction = 1;
    });
    await _anim.forward();
    if (!mounted) return;
    _finishTurn();
  }

  Future<void> _turnBack() async {
    if (_turning || _anim.isAnimating) return;
    if (_current <= 0) return;
    setState(() {
      _turning = true;
      _direction = -1;
    });
    await _anim.forward();
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
      _turnForward();
    } else if (x < width * 0.22) {
      _turnBack();
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
      // Lock the direction on the first decisive movement.
      if (_dragDx.abs() < 10) return;
      final forward = _dragDx < 0;
      if (forward && _current >= widget.pageCount - 1) return;
      if (!forward && _current <= 0) return;
      setState(() {
        _turning = true;
        _direction = forward ? 1 : -1;
      });
    }
    final width = context.size?.width ?? 1;
    _anim.value = (_dragDx.abs() / width).clamp(0, 1);
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    if (!_dragging || !_turning) {
      _dragging = false;
      return;
    }
    _dragging = false;
    final velocity = details.velocity.pixelsPerSecond.dx.abs();
    if (_anim.value > 0.35 || velocity > 500) {
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
      child: _turning ? _buildTurning() : widget.pageBuilder(context, _current),
    );
  }

  Widget _buildTurning() {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final t = _anim.value;
        // Forward: leaf rotates 0 -> -pi. Back: -pi -> 0.
        final angle = _direction == 1 ? -math.pi * t : -math.pi * (1 - t);
        final showingBack = angle.abs() > math.pi / 2;
        final turnAmount = math.sin(angle.abs()); // 0 flat, 1 edge-on

        // The leaf's visible face. The back of the leaf is pre-rotated
        // by pi about the same spine edge, so it reads correctly as
        // the leaf lands (both rotations share the hinge axis).
        final leafChild = showingBack
            ? Transform(
                transform: Matrix4.identity()..rotateY(math.pi),
                alignment: Alignment.centerLeft,
                child: widget.pageBuilder(
                  context,
                  _direction == 1 ? _current + 1 : _current,
                ),
              )
            : widget.pageBuilder(
                context,
                _direction == 1 ? _current : _current - 1,
              );
        final bottomIndex = _direction == 1 ? _current + 1 : _current;

        return Stack(
          children: [
            widget.pageBuilder(context, bottomIndex),
            // Soft shadow on the revealed page, hugging the spine.
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.20 * turnAmount),
                        Colors.black.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.10],
                    ),
                  ),
                ),
              ),
            ),
            Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              alignment: Alignment.centerLeft,
              child: Stack(
                children: [
                  leafChild,
                  // The turning leaf darkens as it lifts off the page.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withValues(
                          alpha: 0.25 * turnAmount,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/typography.dart';

/// Row/card wrapper that lets the user swipe left to reveal a red delete
/// button on the right — iOS-Mail-style.
///
/// - The child renders normally at rest.
/// - Horizontal drag from right → left slides the child, revealing the
///   delete action.
/// - On release the cell snaps open or closed based on how far the user
///   dragged (half the action width is the threshold).
/// - Tapping the revealed delete button invokes [onDelete].
/// - Programmatic scrolls / route changes keep the cell in its current
///   state — dismissing the underlying route resets it via `dispose`.
class SwipeToDeleteCell extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onDelete;

  /// Width of the delete action reveal. Default 92 fits a "Delete" label
  /// comfortably.
  final double actionWidth;

  /// Delete-button label. Defaults to "Delete".
  final String deleteLabel;

  const SwipeToDeleteCell({
    super.key,
    required this.child,
    required this.onDelete,
    this.actionWidth = 92,
    this.deleteLabel = 'Delete',
  });

  @override
  State<SwipeToDeleteCell> createState() => _SwipeToDeleteCellState();
}

class _SwipeToDeleteCellState extends State<SwipeToDeleteCell>
    with SingleTickerProviderStateMixin {
  static const Duration _snapDuration = Duration(milliseconds: 200);

  /// 0 = closed, 1 = fully open (delete revealed).
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // Rightward drag delta is positive; we want leftward to open, so
    // subtract dx.
    final next = (_controller.value - details.delta.dx / widget.actionWidth)
        .clamp(0.0, 1.0);
    _controller.value = next;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldOpen = velocity < -300 ||
        (velocity.abs() < 300 && _controller.value > 0.5);
    _controller.animateTo(
      shouldOpen ? 1.0 : 0.0,
      duration: _snapDuration,
      curve: Curves.easeOut,
    );
  }

  Future<void> _handleDelete() async {
    await _controller.animateTo(0.0,
        duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
    if (!mounted) return;
    await widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final offset = -widget.actionWidth * _controller.value;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Stack(
            children: [
              // Red delete action — full-height, sits behind the child on
              // the right edge. Its visible width scales with the drag so
              // it doesn't peek at rest.
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: _controller.value.clamp(0.0, 1.0),
                    child: SizedBox(
                      width: widget.actionWidth,
                      child: GestureDetector(
                        onTap: _handleDelete,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          color: AppColors.accentDanger,
                          alignment: Alignment.center,
                          child: Text(
                            widget.deleteLabel,
                            style: AppTypography.ibm(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 20 / 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Foreground child slides left.
              Transform.translate(
                offset: Offset(offset, 0),
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
  }
}

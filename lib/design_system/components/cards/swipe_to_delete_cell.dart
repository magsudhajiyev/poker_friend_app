import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/colors.dart';
import '../../constants/typography.dart';

/// Row/card wrapper that lets the user swipe left to reveal action buttons
/// on the right — iOS-Mail-style.
///
/// - The child renders normally at rest.
/// - Horizontal drag from right → left slides the child, revealing the
///   action buttons.
/// - On release the cell snaps open or closed based on how far the user
///   dragged (half the action width is the threshold).
/// - Delete is always shown. Edit is shown when [onEdit] is non-null.
/// - Figma reference: delete-only 1849:14139, edit+delete 1850:14167.
class SwipeToDeleteCell extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onDelete;

  /// When non-null, an orange Edit action is rendered to the left of Delete.
  final VoidCallback? onEdit;

  /// Width of the reveal area. Defaults sized for delete-only (92) or
  /// edit + delete (120). Pass a value to override.
  final double? actionWidth;

  /// Delete-button label. Defaults to "Delete".
  final String deleteLabel;

  /// Edit-button label. Defaults to "Edit".
  final String editLabel;

  const SwipeToDeleteCell({
    super.key,
    required this.child,
    required this.onDelete,
    this.onEdit,
    this.actionWidth,
    this.deleteLabel = 'Delete',
    this.editLabel = 'Edit',
  });

  @override
  State<SwipeToDeleteCell> createState() => _SwipeToDeleteCellState();
}

class _SwipeToDeleteCellState extends State<SwipeToDeleteCell>
    with SingleTickerProviderStateMixin {
  static const Duration _snapDuration = Duration(milliseconds: 200);

  /// 0 = closed, 1 = fully open (actions revealed).
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

  double get _resolvedActionWidth =>
      widget.actionWidth ?? (widget.onEdit != null ? 120 : 92);

  void _onDragUpdate(DragUpdateDetails details) {
    final next = (_controller.value - details.delta.dx / _resolvedActionWidth)
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

  Future<void> _handleEdit() async {
    await _controller.animateTo(0.0,
        duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
    if (!mounted) return;
    widget.onEdit?.call();
  }

  @override
  Widget build(BuildContext context) {
    final actionWidth = _resolvedActionWidth;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final offset = -actionWidth * _controller.value;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: _controller.value.clamp(0.0, 1.0),
                    child: SizedBox(
                      width: actionWidth,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (widget.onEdit != null) ...[
                            _CircleAction(
                              icon: 'icons/figma_icons/edit.svg',
                              color: AppColors.accentTertiary,
                              label: widget.editLabel,
                              onTap: _handleEdit,
                            ),
                            const SizedBox(width: 14),
                          ],
                          _CircleAction(
                            icon: 'icons/figma_icons/delete.svg',
                            color: AppColors.accentDanger,
                            label: widget.deleteLabel,
                            onTap: _handleDelete,
                          ),
                          const SizedBox(width: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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

/// 38px colored circle with an SVG glyph and a small label underneath —
/// used by [SwipeToDeleteCell] for each reveal action.
class _CircleAction extends StatelessWidget {
  final String icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CircleAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                icon,
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  AppColors.textPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.ibm(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 16 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

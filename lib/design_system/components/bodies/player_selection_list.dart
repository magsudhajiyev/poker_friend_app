import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/decorations.dart';
import '../../constants/spacing.dart';
import '../../constants/typography.dart';

/// Selection semantics for [PlayerSelectionRow].
enum PlayerSelectionMode {
  /// Single-choice — circular dot fills when selected.
  radio,

  /// Multi-choice — rounded square check appears when selected.
  checkbox,
}

/// Single row inside [PlayerSelectionList].
///
/// Filled `bgElevated` container with a radio dot or checkbox on the left,
/// a player name expanded, and optional trailing content (share amount,
/// position badge, etc.). Border uses [accentColor] when selected.
class PlayerSelectionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final PlayerSelectionMode mode;
  final Color accentColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PlayerSelectionRow({
    super.key,
    required this.label,
    required this.selected,
    this.mode = PlayerSelectionMode.radio,
    this.accentColor = AppColors.accentPrimary,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: Border.all(
            color: selected ? accentColor : AppColors.borderStrong,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            _SelectionIndicator(
              selected: selected,
              mode: mode,
              accentColor: accentColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTypography.ibm(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                  height: 1.44,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  final bool selected;
  final PlayerSelectionMode mode;
  final Color accentColor;

  const _SelectionIndicator({
    required this.selected,
    required this.mode,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == PlayerSelectionMode.radio) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? accentColor : AppColors.borderLight,
            width: selected ? 2 : 1,
          ),
        ),
        child: selected
            ? Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                  ),
                ),
              )
            : null,
      );
    }
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: selected ? accentColor : Colors.transparent,
        border: Border.all(
          color: selected ? accentColor : AppColors.borderLight,
          width: 1,
        ),
      ),
      child: selected
          ? const Center(
              child: Icon(Icons.check, size: 14, color: AppColors.textInverse),
            )
          : null,
    );
  }
}

/// Simple vertical stack of [PlayerSelectionRow]s used as an [AppDialog] /
/// [AppSheet] body. Rows spacing defaults to 10px.
class PlayerSelectionList extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const PlayerSelectionList({
    super.key,
    required this.children,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(SizedBox(height: spacing));
      rows.add(children[i]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

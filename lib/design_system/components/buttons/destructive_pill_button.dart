import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/decorations.dart';
import '../../constants/typography.dart';

/// Destructive pill — used for dangerous confirm actions in modals
/// (Delete, End Session, Discard).
///
/// Style: `accentDanger` (#FF3B30) fill, 999px radius, 20h/12v padding,
/// 15px SemiBold white label.
class DestructivePillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool expand;

  const DestructivePillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accentDanger,
          borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.ibm(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 20 / 15,
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

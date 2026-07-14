import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/decorations.dart';
import '../../constants/typography.dart';

/// Secondary full-width pill button — the muted counterpart to a primary
/// green CTA. Used for confirm/save actions where a bold color would be
/// visually loud, and for standalone actions inside modals (Close, View
/// Hand History, Save, etc.).
///
/// Style: `bgElevated` (#2C2C2E) fill, 1px `borderStrong` (#3A3A3C)
/// outline, 999px radius, 20h/12v padding, 15px SemiBold white label.
class SecondaryPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool expand;

  const SecondaryPillButton({
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
          color: AppColors.bgElevated,
          border: Border.all(color: AppColors.borderStrong),
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

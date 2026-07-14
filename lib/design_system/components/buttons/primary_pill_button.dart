import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/decorations.dart';
import '../../constants/typography.dart';

/// Primary full-width pill CTA — the brand's main affordance for a
/// positive action (Save, Continue, Log a Hand, Move to Next Hand).
///
/// Style: `accentSecondary` (#A3FF78) fill, 999px radius, 20h/12v padding,
/// 15px SemiBold `textInverse` (near-black) label.
class PrimaryPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool expand;

  const PrimaryPillButton({
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
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.accentSecondary,
            borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textInverse,
              height: 20 / 15,
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

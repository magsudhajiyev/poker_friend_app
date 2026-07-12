import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/spacing.dart';
import '../../constants/typography.dart';
import '../buttons/close_circle_button.dart';

/// Standard header row for [AppDialog].
///
/// Left-aligned 17px w600 title with an optional close X in the top-right.
class DialogHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  const DialogHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: subtitle == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.ibm(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 22 / 17,
                  letterSpacing: -0.43,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxxs),
                Text(
                  subtitle!,
                  style: AppTypography.ibm(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 18 / 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onClose != null) ...[
          const SizedBox(width: AppSpacing.xs),
          CloseCircleButton(onTap: onClose!),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/spacing.dart';
import '../../constants/typography.dart';
import '../buttons/close_circle_button.dart';

/// Standard header row for [AppSheet].
///
/// Unified with `DialogHeader`: left-aligned 17px w600 title, optional
/// trailing action (e.g. save check), 38×38 close circle on the right.
/// Cross-axis alignment shifts to `start` when a subtitle is present so
/// the close circle sits aligned with the title row instead of the
/// title+subtitle block.
class SheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;
  final Widget? trailing;

  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
    this.trailing,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.xs),
          trailing!,
        ],
        if (onClose != null) ...[
          const SizedBox(width: AppSpacing.xs),
          CloseCircleButton(onTap: onClose!),
        ],
      ],
    );
  }
}

/// 38px circular X close button — matches [BackButtonCircle] sizing/colour.
class SheetCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const SheetCloseButton({
    super.key,
    required this.onTap,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) =>
      CloseCircleButton(onTap: onTap, size: size);
}

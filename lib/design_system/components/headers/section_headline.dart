import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/typography.dart';
import '../containers/avg_badge.dart';

/// Section headline with teal color and optional right-side widget
/// Used for Recent Activity, Earnings, Sessions, Events sections
class SectionHeadline extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionPressed;
  final Widget? trailing;
  final String? badgeText;

  const SectionHeadline({
    Key? key,
    required this.title,
    this.actionText,
    this.onActionPressed,
    this.trailing,
    this.badgeText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTypography.sectionHeadline(),
          ),
          if (trailing != null)
            trailing!
          else if (badgeText != null)
            AvgBadge(text: badgeText!)
          else if (actionText != null)
            GestureDetector(
              onTap: onActionPressed,
              child: Text(
                actionText!,
                style: AppTypography.viewAllButton(),
              ),
            ),
        ],
      ),
    );
  }
}

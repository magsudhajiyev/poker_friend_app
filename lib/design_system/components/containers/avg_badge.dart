import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/typography.dart';

/// Rounded pill badge showing average earnings
/// Used in the Earnings section header
class AvgBadge extends StatelessWidget {
  final String text;

  const AvgBadge({
    Key? key,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.iconButtonBg,
        borderRadius: BorderRadius.circular(300),
      ),
      child: Text(
        text,
        style: AppTypography.labelChip(),
      ),
    );
  }
}

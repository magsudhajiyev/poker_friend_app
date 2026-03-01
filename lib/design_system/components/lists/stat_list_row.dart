import 'package:flutter/material.dart';
import '../../constants/typography.dart';

/// Simple list row with label on left and value on right
/// Used for stats display in home screen
class StatListRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const StatListRow({
    Key? key,
    required this.label,
    required this.value,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.listRowText(),
            ),
            Text(
              value,
              style: AppTypography.listRowText(),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../constants/typography.dart';

/// Simple list row with label on left and value on right
/// Used for stats display in home screen
///
/// Label and value are [Flexible] so long text wraps instead of overflowing
/// (large text scale, narrow phones, long translations). Optional
/// [labelStyle] / [valueStyle] allow compact variants.
class StatListRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const StatListRow({
    Key? key,
    required this.label,
    required this.value,
    this.onTap,
    this.labelStyle,
    this.valueStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // Figma: px-4, py-8 (inside Table-list container which has px-16)
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                label,
                style: labelStyle ?? AppTypography.listRowLabel(),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: valueStyle ?? AppTypography.listRowValue(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

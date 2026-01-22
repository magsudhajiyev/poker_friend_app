import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/decorations.dart';
import '../../constants/typography.dart';

/// Rounded pill-shaped label container
///
/// Used for small labels like "Wallet Balance" with semi-transparent
/// white background.
///
/// Usage:
/// ```dart
/// PillLabel(
///   text: 'Wallet Balance',
/// )
/// ```
class PillLabel extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final double? backgroundOpacity;
  final TextStyle? textStyle;
  final EdgeInsets? padding;

  const PillLabel({
    super.key,
    required this.text,
    this.backgroundColor,
    this.backgroundOpacity,
    this.textStyle,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: backgroundColor != null
            ? backgroundColor!.withOpacity(backgroundOpacity ?? 0.2)
            : AppColors.whiteOverlay(),
        borderRadius: BorderRadius.circular(
          AppDecorations.pillRadius,
        ),
      ),
      child: Text(
        text,
        style: textStyle ?? AppTypography.pillLabel(),
      ),
    );
  }
}

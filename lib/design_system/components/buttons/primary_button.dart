import 'package:flutter/material.dart';
import '../../constants/decorations.dart';
import '../../constants/typography.dart';

/// Primary white button with black text and optional arrow icon
///
/// This is the main action button used throughout the app, featuring
/// a white background with rounded corners and optional forward arrow.
///
/// Usage:
/// ```dart
/// PrimaryButton(
///   label: 'Log in',
///   onTap: () => navigateToNextScreen(),
/// )
/// ```
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool showArrow;
  final EdgeInsets? padding;
  final double? borderRadius;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.showArrow = true,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppDecorations.buttonRadius,
          ),
        ),
        padding: padding ?? const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 14,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.buttonText(),
            ),
            if (showArrow)
              const Icon(
                Icons.arrow_forward,
                color: Colors.black,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

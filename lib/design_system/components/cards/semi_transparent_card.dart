import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/decorations.dart';

/// Semi-transparent card without blur effect
///
/// Used for mode selection cards and other non-glassy semi-transparent
/// containers.
///
/// Usage:
/// ```dart
/// SemiTransparentCard(
///   child: Column(
///     children: [
///       Text('Title'),
///       Text('Content'),
///     ],
///   ),
/// )
/// ```
class SemiTransparentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? borderRadius;
  final Color? backgroundColor;
  final double? backgroundOpacity;

  const SemiTransparentCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.backgroundOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor != null
            ? backgroundColor!.withOpacity(backgroundOpacity ?? 0.5)
            : AppColors.semiTransparentDarkColor(),
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppDecorations.modeCardRadius,
        ),
      ),
      padding: padding ?? const EdgeInsets.all(24),
      child: child,
    );
  }
}

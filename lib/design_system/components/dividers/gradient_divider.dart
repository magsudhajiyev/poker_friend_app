import 'package:flutter/material.dart';

/// Horizontal gradient divider line
///
/// Creates a subtle divider with gradient effect that fades in and out
/// from the edges, commonly used between list items.
///
/// Usage:
/// ```dart
/// Column(
///   children: [
///     Text('Item 1'),
///     GradientDivider(),
///     Text('Item 2'),
///   ],
/// )
/// ```
class GradientDivider extends StatelessWidget {
  final EdgeInsets? margin;
  final double? height;

  const GradientDivider({
    super.key,
    this.margin,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 1,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.1),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

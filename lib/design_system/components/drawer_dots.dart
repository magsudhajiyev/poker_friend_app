import 'package:flutter/material.dart';

/// Compact 3-dot action icon in a dark pill container.
///
/// Matches the Figma "Drawer" component: a rounded-rect pill (#1B1E24)
/// containing three small white circles.
class DrawerDots extends StatelessWidget {
  final VoidCallback? onTap;
  final double dotSize;
  final double dotSpacing;
  final Color backgroundColor;
  final Color dotColor;

  const DrawerDots({
    Key? key,
    this.onTap,
    this.dotSize = 3.5,
    this.dotSpacing = 1.5,
    this.backgroundColor = const Color(0xFF1B1E24),
    this.dotColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (_) => Container(
              width: dotSize,
              height: dotSize,
              margin: EdgeInsets.symmetric(horizontal: dotSpacing),
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            )),
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: child);
    }
    return child;
  }
}

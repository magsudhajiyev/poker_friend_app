import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../constants/colors.dart';
import '../../constants/decorations.dart';

/// Standard gradient background used across all screens
///
/// This creates the green elliptical gradient with heavy blur
/// positioned at the top-left of the screen, plus a lighter green
/// glow at the very top for depth.
///
/// Usage:
/// ```dart
/// Stack(
///   children: [
///     GradientBackground(),
///     // ... your content
///   ],
/// )
/// ```
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main gradient ellipse
        Positioned(
          left: -98,
          top: -148,
          child: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: AppDecorations.blurHeavy,
                sigmaY: AppDecorations.blurHeavy,
              ),
              child: Container(
                width: 595,
                height: 727,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.gradientGreenTop.withOpacity(0.6),
                      AppColors.gradientGreenMid.withOpacity(0.6),
                      const Color(0xFF000000).withOpacity(0.6),
                    ],
                    stops: const [0.0, 0.32, 1.0],
                  ),
                  borderRadius: const BorderRadius.all(
                    Radius.elliptical(297.5, 363.5),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Light green ellipse at top (Ellipse 19 from Figma)
        // Accounting for 132px blur spread in all directions
        Positioned(
          left: 54 - 132, // Offset for blur spread
          top: -120 - 132, // Moved down to -120
          child: Transform.rotate(
            angle: -1.5708, // -90 degrees in radians
            child: Container(
              width: 291 + 264, // Original width + 2*blur (132px each side)
              height: 326 + 264, // Original height + 2*blur (132px each side)
              decoration: const BoxDecoration(
                // Radial gradient simulating CSS blur effect
                // Center has color, edges are fully transparent
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.5, // Color concentrated in center half
                  colors: [
                    Color(0x4D84ff95), // 30% opacity at center
                    Color(0x3384ff95), // 20% opacity
                    Color(0x1A84ff95), // 10% opacity
                    Color(0x0D84ff95), // 5% opacity
                    Color(0x0084ff95), // Fully transparent at edges
                  ],
                  stops: [0.0, 0.3, 0.5, 0.75, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

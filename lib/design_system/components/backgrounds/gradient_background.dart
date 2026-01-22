import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../constants/colors.dart';
import '../../constants/decorations.dart';

/// Standard gradient background used across all screens
///
/// This creates the green elliptical gradient with heavy blur
/// positioned at the top-left of the screen.
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
    return Positioned(
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
    );
  }
}

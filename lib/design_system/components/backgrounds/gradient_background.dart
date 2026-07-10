import 'package:flutter/material.dart';
import '../../constants/colors.dart';

/// Solid page background — `AppColors.bgPrimary` (`#0C0C0C`).
///
/// Legacy name retained for callsite compatibility. The green ellipse +
/// cyan glow that used to render here has been removed; the design system
/// now uses a flat dark background across all screens.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: ColoredBox(color: AppColors.bgPrimary),
    );
  }
}

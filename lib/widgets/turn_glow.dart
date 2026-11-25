import 'package:flutter/painting.dart';

import '../design_system/constants/colors.dart';

/// Glow around the avatar of the seat whose turn it is. Two layers: a tight,
/// strong core and a wide soft halo, both breathing with the pulse value
/// `t` (0..1). Pure, so the animation parameters are unit-tested.
class TurnGlow {
  TurnGlow._();

  /// Ring / glow colour of the seat on turn.
  static const Color color = AppColors.warningAmber;

  // Previous look (kept for the regression test): alpha 0.25..0.55, blur
  // 6..12, no spread.
  static const double coreAlphaMin = 0.50;
  static const double coreAlphaRange = 0.40;
  static const double coreBlurMin = 12;
  static const double coreBlurRange = 12;
  static const double coreSpreadMin = 1.5;
  static const double coreSpreadRange = 2.5;
  static const double haloAlphaMin = 0.22;
  static const double haloAlphaRange = 0.22;
  static const double haloBlurMin = 22;
  static const double haloBlurRange = 12;

  static List<BoxShadow> shadows(double t) {
    final p = t.clamp(0.0, 1.0);
    return [
      BoxShadow(
        color: color.withValues(alpha: coreAlphaMin + coreAlphaRange * p),
        blurRadius: coreBlurMin + coreBlurRange * p,
        spreadRadius: coreSpreadMin + coreSpreadRange * p,
      ),
      BoxShadow(
        color: color.withValues(alpha: haloAlphaMin + haloAlphaRange * p),
        blurRadius: haloBlurMin + haloBlurRange * p,
      ),
    ];
  }
}

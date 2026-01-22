import 'package:flutter/material.dart';

/// Extended color palette for the design system
/// Extends the existing PokerFriendColors with new colors used in the app designs
class AppColors {
  // Primary Accents (Lime Green Theme)
  static const Color limeGreen = Color(0xFF87ED81);
  static const Color accentGreen = Color(0xFFA5EC44);

  // Gradient Colors
  static const Color gradientGreenStart = Color(0xFF022F00);
  static const Color gradientGreenEnd = Color(0xFF079500);
  static const Color gradientGreenTop = Color(0xFFABFFB4);
  static const Color gradientGreenMid = Color(0xFF006434);

  // Card & Background Colors
  static const Color glassyCardBase = Color(0xFF546165);
  static const Color semiTransparentDark = Color(0xFF3D3D3D);
  static const Color navBarBackground = Color(0xFF1E1E1E);
  static const Color navBarBorder = Color(0xFF292F29);

  // Chart Colors
  static const Color tournamentBlue = Color(0xFF00C3FF);
  static const Color cashGameGreen = Color(0xFF44EC49);
  static const Color avgBadgeGreen = Color(0xFF009548);

  // Opacity helpers for commonly used transparent colors
  static Color glassyCardColor({double opacity = 0.74}) =>
    glassyCardBase.withOpacity(opacity);

  static Color semiTransparentDarkColor({double opacity = 0.5}) =>
    semiTransparentDark.withOpacity(opacity);

  static Color navBarBackgroundColor({double opacity = 0.1}) =>
    navBarBackground.withOpacity(opacity);

  static Color whiteBorder({double opacity = 0.1}) =>
    Colors.white.withOpacity(opacity);

  static Color whiteOverlay({double opacity = 0.2}) =>
    Colors.white.withOpacity(opacity);
}

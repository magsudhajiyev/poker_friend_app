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

  // Figma Home Screen Colors
  static const Color tealAccent = Color(0xFF7DCAB4);
  static const Color headerGradientCyan = Color(0x574CDBFF);  // rgba(76,219,255,0.34)
  static const Color headerGradientGreen = Color(0x572EB46A); // rgba(46,180,106,0.34)
  static const Color darkPillBg = Color(0xFF0C1209);
  static const Color iconButtonBg = Color(0x4D3C3C43);        // rgba(60,60,67,0.3)
  static const Color infoCardBg = Color(0xFF131616);
  static const Color separatorColor = Color(0x4DEBEBF5);      // rgba(235,235,245,0.3)
  static const Color labelSecondary = Color(0xB3EBEBF5);      // rgba(235,235,245,0.7)

  // Calendar Screen Colors
  static const Color calendarAccentGreen = Color(0xFF62E3BC);
  static const Color calendarCardBg = Color(0x12FFFFFF);       // rgba(255,255,255,0.07)
  static const Color calendarCardOverlay = Color(0x08FFFFFF);  // rgba(255,255,255,0.03)
  static const Color timePillBg = Color(0x1F76807F);           // rgba(118,118,128,0.12)
  static const Color labelTertiary = Color(0x4DEBEBF5);        // rgba(235,235,245,0.3)
  static const Color calendarDayText = Color(0xFFFFFFFF);
  static const Color calendarDayDisabled = Color(0x4DEBEBF5);  // rgba(235,235,245,0.3)

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

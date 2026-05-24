import 'package:flutter/material.dart';

/// Extended color palette for the design system
/// Extends the existing PokerFriendColors with new colors used in the app designs
class AppColors {
  // Primary Accents (Lime Green Theme)
  static const Color limeGreen = Color(0xFF87ED81);
  static const Color accentGreen = Color(0xFFA5EC44);
  static const Color accentSecondary = Color(0xFFA3FF78); // Figma --semantic/accent/secondary

  // Gradient Colors
  static const Color gradientGreenStart = Color(0xFF022F00);
  static const Color gradientGreenEnd = Color(0xFF079500);
  static const Color gradientGreenTop = Color(0xFFABFFB4);
  static const Color gradientGreenMid = Color(0xFF006434);

  // Card & Background Colors
  static const Color bgMainV2 = Color(0xFF0C0C0C);           // Nav bar / page bg v2
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

  // Figma Design System Colors (node 20:774)
  static const Color backgroundPaper = Color(0xFF02050B);    // Main screen background
  static const Color backgroundSurface = Color(0xFF101115);  // Cards, nav, progress bar bg
  static const Color textSecondary = Color(0xFFD3FFFD);      // Mint - subtitle, view all, accents
  static const Color textDisabled = Color(0xFF8C8C8C);       // Section headers
  static const Color buttonPrimary = Color(0xFF89F1EC);      // Mint button
  static const Color accentGreenBright = Color(0xFF54E98A);  // Progress bar fill
  static const Color separatorDark = Color(0xFF1C1F21);      // List separators

  // Updated Header Gradient (Figma node 520-3288)
  static const Color headerGradientBlack = Color(0xFF000000);
  static const Color headerGradientTeal = Color(0xFF133538);

  // Progress Bar Gradient
  static const Color progressBarStart = Color(0xFF54E98A);
  static const Color progressBarEnd = Color(0xFF66D9CC);

  // Dark Pill (notification/menu container)
  static const Color darkPillBg = Color(0xFF0C1209);
  static const Color darkPillGradientEnd = Color(0xFF253734);
  static const Color darkPillBorder = Color(0xFF232517);
  static const Color darkPillInnerShadow = Color(0x40416D70);  // rgba(65,109,112,0.25)
  static const Color iconButtonBg = Color(0x4D3C3C43);        // rgba(60,60,67,0.3)
  static const Color infoCardBg = Color(0xFF131616);
  static const Color separatorColor = Color(0x4DEBEBF5);      // rgba(235,235,245,0.3)
  static const Color labelSecondary = Color(0xB3EBEBF5);      // rgba(235,235,245,0.7)

  // Dealer Table Status Bar Colors (Figma node 1015:7172)
  static const Color statusPotLabel = Color(0xFF7C8125);
  static const Color statusPotValue = Color(0xFFF3FF15);
  static const Color statusStreetLabel = Color(0xFF6388A5);
  static const Color statusStreetValue = Color(0xFF97CBF3);
  static const Color mint500 = Color(0xFF5EB7B3);
  static const Color mint600 = Color(0xFF4B9A96);
  static const Color mint700 = Color(0xFF3A7D7A);
  static const Color mint800 = Color(0xFF2A605D); // Figma mint/800 - seated pill bg
  static const Color mint900 = Color(0xFF1B4341);
  static const Color neutral500 = Color(0xFF67696D);
  static const Color neutral800 = Color(0xFF1B1E24);
  static const Color neutral700 = Color(0xFF35373C);
  static const Color secondary900 = Color(0xFF3C4D59);
  static const Color betPill = Color(0xFF4C94FF);
  static const Color warningText = Color(0xFFBD8F2D);
  static const Color errorRed = Color(0xFFD55A41);

  // Calendar Screen Colors
  static const Color calendarAccentGreen = Color(0xFF62E3BC);
  static const Color calendarCardBg = Color(0xFF101115);       // #101115
  static const Color calendarCardOverlay = Color(0x08FFFFFF);  // rgba(255,255,255,0.03)
  static const Color timePillBg = Color(0x1F76807F);           // rgba(118,118,128,0.12)
  static const Color labelTertiary = Color(0x4DEBEBF5);        // rgba(235,235,245,0.3)
  static const Color calendarDayText = Color(0xFFFFFFFF);
  static const Color calendarDayDisabled = Color(0x4DEBEBF5);  // rgba(235,235,245,0.3)

  // Info Card Colors (Figma node 731:9032)
  static const Color infoCardPillText = Color(0xFF89F1EC);     // Cyan pill text (matches buttonPrimary)
  static const Color infoCardPillTextNeutral = Color(0xFFCACACA); // Neutral pill text
  static const Color infoCardDateText = Color(0xFF4E5054);     // Date/timestamp text
  static const Color eventBuyInText = Color(0xFFCEEFFF);       // Event buy-in pill text

  // Figma v2 Home Screen — stat card icon backgrounds
  static const Color cardIconBlue   = Color(0xFF4879FF);  // Play Style
  static const Color cardIconPurple = Color(0xFFA148FF);  // Sessions
  static const Color cardIconOrange = Color(0xFFFF7648);  // Win Rate
  static const Color cardIconRed    = Color(0xFFFF4848);  // Hours

  // Figma v2 general surface tokens
  static const Color bgElevated     = Color(0xFF2C2C2E);  // currency/period pills
  static const Color progressTrack  = Color(0xFF3A3A3C);  // progress bar background
  static const Color accentGreenV2  = Color(0xFF4CDE78);  // earnings amount, cash game legend
  static const Color accentBlueV2   = Color(0xFF007AFF);  // tournament legend
  static const Color cardBorderV2   = Color(0xFF161719);  // stat card border + header bg
  static const Color bgMainV2       = Color(0xFF0C0C0C);  // main scaffold background
  static const Color textSecondaryV2 = Color(0xFFB9B9B9); // secondary labels

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

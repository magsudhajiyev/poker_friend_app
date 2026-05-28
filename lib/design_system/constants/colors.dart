import 'package:flutter/material.dart';

class AppColors {
  // ─────────────────────────────────────────────────────────────────────────
  // PRIMITIVES — Figma color scale (private, do not use directly in UI)
  // ─────────────────────────────────────────────────────────────────────────

  static const Color _grayBlack = Color(0xFF0C0C0C);
  static const Color _gray50    = Color(0xFFFDFDFD);
  static const Color _gray100   = Color(0xFFEFEFEF);
  static const Color _gray200   = Color(0xFF161719);
  static const Color _gray300   = Color(0xFF2C2C2E);
  static const Color _gray400   = Color(0xFF3A3A3C);
  static const Color _gray500   = Color(0xFFB9B9B9);
  static const Color _gray900   = Color(0xFFEBEBF0);
  static const Color _grayWhite = Color(0xFFFFFFFF);
  static const Color _green500  = Color(0xFF4CDE78);
  static const Color _green300  = Color(0xFFA3FF78);
  static const Color _red500    = Color(0xFFFF3B30);
  static const Color _blue500   = Color(0xFF007AFF);
  static const Color _orange500 = Color(0xFFFF8A54);
  static const Color _purple500 = Color(0xFF763EED);

  // ─────────────────────────────────────────────────────────────────────────
  // SEMANTIC TOKENS — mirrors Figma variable definitions exactly
  // ─────────────────────────────────────────────────────────────────────────

  // Backgrounds
  static const Color bgPrimary        = _grayBlack;  // semantic/bg/primary
  static const Color bgSurface        = _gray200;    // semantic/bg/surface
  static const Color bgElevated       = _gray300;    // semantic/bg/elevated
  static const Color bgOverlay        = _gray400;    // semantic/bg/overlay
  static const Color bgInverse        = _grayWhite;  // semantic/bg/inverse
  static const Color bgInputOnInverse = _gray50;     // semantic/bg/input-on-inverse

  // Text
  static const Color textPrimary            = _grayWhite;  // semantic/text/primary
  static const Color textSecondary          = _gray500;    // semantic/text/secondary
  static const Color textInverse            = _grayBlack;  // semantic/text/inverse
  static const Color textOnInverse          = _grayBlack;  // semantic/text/on-inverse
  static const Color textOnInverseSecondary = _gray500;    // semantic/text/on-inverse-secondary

  // Borders
  static const Color borderDefault      = _gray200;   // semantic/border/default
  static const Color borderStrong       = _gray400;   // semantic/border/strong
  static const Color borderLight        = _gray500;   // semantic/border/light
  static const Color borderOnInverse    = _gray300;   // semantic/border/on-inverse
  static const Color borderOnInverseSubtle = _gray100; // semantic/border/on-inverse-subtle

  // Accents
  static const Color accentPrimary   = _green500;   // semantic/accent/primary
  static const Color accentSecondary = _green300;   // semantic/accent/secondary
  static const Color accentDanger    = _red500;     // semantic/accent/danger
  static const Color accentInfo      = _blue500;    // semantic/accent/info
  static const Color accentTertiary  = _orange500;  // semantic/accent/tertiary
  static const Color accentPurple    = _purple500;  // semantic/accent/purple

  // Content
  static const Color contentActive   = _grayWhite;  // semantic/content/active
  static const Color contentInactive = _gray500;    // semantic/content/inactive
  static const Color contentDisabled = _gray400;    // semantic/content/disabled

  // ─────────────────────────────────────────────────────────────────────────
  // APP-SPECIFIC — poker/game colors not in Figma variables
  // ─────────────────────────────────────────────────────────────────────────

  // Legacy design system (screens not yet migrated to v2)
  static const Color buttonPrimary = Color(0xFF89F1EC);  // Mint CTA buttons
  static const Color limeGreen     = Color(0xFF87ED81);  // Section header labels
  static const Color textMint      = Color(0xFFD3FFFD);  // Mint subtitle / accent text
  static const Color textDisabled  = Color(0xFF8C8C8C);  // Muted text labels
  static const Color errorRed      = Color(0xFFD55A41);  // Error state (distinct from accentDanger)

  // Navigation
  static const Color navBarBackground = Color(0xFF1E1E1E);
  static const Color navBarBorder     = Color(0xFF292F29);

  // Separators
  static const Color separatorDark  = Color(0xFF1C1F21);
  static const Color separatorColor = Color(0x4DEBEBF5);  // rgba(235,235,245,0.3) — overlay

  // Glassmorphism
  static const Color glassyCardBase      = Color(0xFF546165);
  static const Color semiTransparentDark = Color(0xFF3D3D3D);
  static const Color iconButtonBg        = Color(0x4D3C3C43);  // rgba(60,60,67,0.3)

  // Home header gradient
  static const Color headerGradientBlack = Color(0xFF000000);
  static const Color headerGradientTeal  = Color(0xFF133538);

  // Dark pill container
  static const Color darkPillBg          = Color(0xFF0C1209);
  static const Color darkPillGradientEnd = Color(0xFF253734);
  static const Color darkPillBorder      = Color(0xFF232517);
  static const Color darkPillInnerShadow = Color(0x40416D70);

  // Progress bar gradient
  static const Color progressBarStart = Color(0xFF54E98A);
  static const Color progressBarEnd   = Color(0xFF66D9CC);
  static const Color accentGreenBright = Color(0xFF54E98A);  // alias of progressBarStart

  // Misc UI
  static const Color infoCardBg        = Color(0xFF131616);
  static const Color labelSecondary    = Color(0xB3EBEBF5);  // rgba(235,235,245,0.7)
  static const Color labelTertiary     = Color(0x4DEBEBF5);  // rgba(235,235,245,0.3)
  static const Color timePillBg        = Color(0x1F76807F);  // rgba(118,128,127,0.12)

  // Session / betting UI
  static const Color betPill      = Color(0xFF4C94FF);
  static const Color warningText  = Color(0xFFBD8F2D);

  // Chart
  static const Color tournamentBlue = Color(0xFF00C3FF);
  static const Color cashGameGreen  = Color(0xFF44EC49);
  static const Color avgBadgeGreen  = Color(0xFF009548);

  // Home screen stat card icon backgrounds
  static const Color cardIconBlue   = Color(0xFF4879FF);
  static const Color cardIconPurple = Color(0xFFA148FF);
  static const Color cardIconOrange = Color(0xFFFF7648);
  static const Color cardIconRed    = Color(0xFFFF4848);

  // Info card text
  static const Color infoCardPillTextNeutral = Color(0xFFCACACA);
  static const Color infoCardDateText        = Color(0xFF4E5054);
  static const Color eventBuyInText          = Color(0xFFCEEFFF);

  // Dealer UI status bar
  static const Color statusPotLabel    = Color(0xFF7C8125);
  static const Color statusPotValue    = Color(0xFFF3FF15);
  static const Color statusStreetLabel = Color(0xFF6388A5);
  static const Color statusStreetValue = Color(0xFF97CBF3);

  // Dealer UI mint scale
  static const Color mint500 = Color(0xFF5EB7B3);
  static const Color mint600 = Color(0xFF4B9A96);
  static const Color mint700 = Color(0xFF3A7D7A);
  static const Color mint800 = Color(0xFF2A605D);
  static const Color mint900 = Color(0xFF1B4341);

  // Dealer UI neutral scale
  static const Color neutral500  = Color(0xFF67696D);
  static const Color neutral700  = Color(0xFF35373C);
  static const Color neutral800  = Color(0xFF1B1E24);
  static const Color secondary900 = Color(0xFF3C4D59);

  // ─────────────────────────────────────────────────────────────────────────
  // OPACITY HELPERS
  // ─────────────────────────────────────────────────────────────────────────

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

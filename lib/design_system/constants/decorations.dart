/// Decoration constants for the design system
/// Includes border radius, blur values, and other decoration properties
class AppDecorations {
  // Border Radius (legacy)
  static const double cardRadius = 12.0;
  static const double modeCardRadius = 24.0;
  static const double buttonRadius = 60.0;
  static const double navBarRadius = 70.0;
  static const double pillRadius = 40.0;
  static const double legendDotRadius = 3.5;

  // Border Radius — Figma tokens (mirrors "Radius" variable collection)
  static const double radiusSm   = 8.0;    // radius/sm   — chips, tags
  static const double radiusMd   = 12.0;   // radius/md   — cards (= cardRadius)
  static const double radiusLg   = 16.0;   // radius/lg   — info cards, overlays
  static const double radiusXl   = 24.0;   // radius/xl   — mode cards (= modeCardRadius)
  static const double radiusFull = 999.0;  // radius/full — pills, fully rounded

  // Observed scale (tokenized 2026-07; consolidate in phase 3)
  static const double radius10 = 10.0;
  static const double radius14 = 14.0;
  static const double radius18 = 18.0;
  static const double radius20 = 20.0;

  // Blur Values
  static const double blurLight = 45.0;    // For glassy cards
  static const double blurHeavy = 132.0;   // For gradient backgrounds

  // Border Widths
  static const double borderThin = 1.0;

  // Shadow & Elevation
  static const double cardElevation = 0.0;  // No elevation, using blur instead
}

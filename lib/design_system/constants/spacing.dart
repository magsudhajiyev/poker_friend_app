class AppSpacing {
  // ─────────────────────────────────────────────────────────────────────────
  // FIGMA TOKENS — mirrors "Spacing" variable collection exactly
  // ─────────────────────────────────────────────────────────────────────────

  static const double space1  = 4.0;   // space/1
  static const double space2  = 8.0;   // space/2
  static const double space3  = 12.0;  // space/3
  static const double space4  = 16.0;  // space/4
  static const double space5  = 20.0;  // space/5
  static const double space6  = 24.0;  // space/6
  static const double space8  = 32.0;  // space/8
  static const double space10 = 40.0;  // space/10
  static const double space12 = 48.0;  // space/12
  static const double space16 = 64.0;  // space/16

  // ─────────────────────────────────────────────────────────────────────────
  // SEMANTIC ALIASES — legacy names pointing to Figma tokens
  // ─────────────────────────────────────────────────────────────────────────

  static const double xxxs = space1;   // 4
  static const double xxs  = space2;   // 8
  static const double xs   = space3;   // 12
  static const double md   = space4;   // 16
  static const double xl   = space6;   // 24
  static const double xxxl = space8;   // 32

  // ─────────────────────────────────────────────────────────────────────────
  // APP-SPECIFIC — not in Figma, kept for existing screens
  // ─────────────────────────────────────────────────────────────────────────

  static const double sm  = 14.0;   // legacy — between space/3 and space/4
  static const double lg  = 18.0;   // legacy — between space/4 and space/5
  static const double xxl = 28.0;   // legacy — between space/6 and space/8

  static const double cardPadding   = space6;   // 24 — standard card padding
  static const double bottomPadding = 120.0;    // nav bar scroll clearance
}

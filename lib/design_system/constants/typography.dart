import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Typography constants for the design system
/// Provides reusable text styles used throughout the app
/// Primary font: IBM Plex Sans (17px base)
class AppTypography {
  // Section Headers (Lime green uppercase titles)
  static TextStyle sectionHeader({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 12,
    color: color ?? AppColors.limeGreen,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
  );

  // Page Titles
  static TextStyle pageTitle({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 28,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.56,
  );

  static TextStyle pageTitleLarge({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 32,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  // Subtitles
  static TextStyle pageSubtitle({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 16,
    color: color ?? Colors.white.withOpacity(0.8),
    fontWeight: FontWeight.w500,
  );

  static TextStyle subtitle({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 14,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.0,
  );

  // Card Titles
  static TextStyle cardTitle({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 24,
    color: color ?? AppColors.limeGreen,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    height: 1.0,
  );

  // Body Text - base 17px
  static TextStyle bodyLarge({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 17,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w400,
    height: 1.44,
  );

  static TextStyle bodyMedium({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 15,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w400,
    height: 1.44,
  );

  static TextStyle bodySmall({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 14,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w400,
    height: 1.44,
  );

  // Button Text
  static TextStyle buttonText({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 17,
    color: color ?? Colors.black,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.43,
  );

  // Monetary Values (Roboto Mono for numbers)
  static TextStyle monetaryLarge({Color? color}) => GoogleFonts.robotoMono(
    fontSize: 38,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w700,
  );

  static TextStyle monetaryMedium({Color? color}) => GoogleFonts.robotoMono(
    fontSize: 24,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w500,
  );

  // Labels
  static TextStyle label({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 14,
    color: color ?? Colors.white.withOpacity(0.8),
    fontWeight: FontWeight.w400,
  );

  static TextStyle pillLabel({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 14,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  // IBM Plex Sans styles for Figma Home Screen
  static TextStyle homeGreeting({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 32,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.0,
    height: 1.36,
  );

  static TextStyle homeSubtitle({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 17,
    color: color ?? AppColors.textSecondary,
    fontWeight: FontWeight.w500,
    height: 1.44,
  );

  static TextStyle bankrollAmount({Color? color}) => GoogleFonts.familjenGrotesk(
    fontSize: 40,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  static TextStyle bankrollSubtext({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 17,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w500,
    height: 1.44,
  );

  static TextStyle sectionHeadline({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 17,
    color: color ?? AppColors.textDisabled,
    fontWeight: FontWeight.w500,
    height: 1.44,
  );

  static TextStyle listRowLabel({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 17,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w500,
    height: 1.44,
  );

  static TextStyle listRowValue({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 17,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w400,
    height: 1.44,
  );

  // Keep old method for backwards compatibility
  static TextStyle listRowText({Color? color}) => listRowLabel(color: color);

  static TextStyle viewAllButton({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 17,
    color: color ?? AppColors.textSecondary,
    fontWeight: FontWeight.w500,
    height: 1.44,
  );

  static TextStyle labelChip({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 15,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w500,
    height: 1.44,
  );

  static TextStyle chartAxisLabel({Color? color}) => GoogleFonts.robotoMono(
    fontSize: 11,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w300,
  );

  static TextStyle infoCardText({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 17,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w400,
    height: 1.44,
  );

  static TextStyle infoCardAccent({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 17,
    color: color ?? AppColors.textSecondary,
    fontWeight: FontWeight.w400,
    height: 1.44,
  );

  // Info Card Pill Text (12px medium, used in session/event card pills)
  static TextStyle infoCardPill({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 12,
    color: color ?? AppColors.infoCardPillText,
    fontWeight: FontWeight.w500,
  );

  // Info Card Date (13px medium, muted timestamp)
  static TextStyle infoCardDate({Color? color}) => GoogleFonts.ibmPlexSans(
    fontSize: 13,
    color: color ?? AppColors.infoCardDateText,
    fontWeight: FontWeight.w500,
    height: 1.44,
  );
}

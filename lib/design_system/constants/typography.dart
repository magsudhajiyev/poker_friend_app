import 'package:flutter/material.dart';
import 'colors.dart';

/// Typography constants for the design system
/// Provides reusable text styles used throughout the app
class AppTypography {
  // Font Families
  static const String inter = 'Inter';
  static const String robotoMono = 'RobotoMono';

  // Section Headers (Lime green uppercase titles)
  static TextStyle sectionHeader({Color? color}) => TextStyle(
    fontFamily: inter,
    fontSize: 12,
    color: color ?? AppColors.limeGreen,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
  );

  // Page Titles
  static TextStyle pageTitle({Color? color}) => TextStyle(
    fontFamily: inter,
    fontSize: 28,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.56,
  );

  static TextStyle pageTitleLarge({Color? color}) => TextStyle(
    fontFamily: inter,
    fontSize: 32,
    color: color ?? Colors.white,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  // Subtitles
  static TextStyle pageSubtitle({Color? color}) => TextStyle(
    fontFamily: inter,
    fontSize: 16,
    color: color ?? Colors.white.withOpacity(0.8),
    fontWeight: FontWeight.w500,
  );

  static TextStyle subtitle({Color? color}) => TextStyle(
    fontFamily: inter,
    fontSize: 14,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.0,
  );

  // Card Titles
  static TextStyle cardTitle({Color? color}) => TextStyle(
    fontFamily: inter,
    fontSize: 24,
    color: color ?? AppColors.limeGreen,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    height: 1.0,
  );

  // Body Text
  static TextStyle bodyLarge({Color? color}) => TextStyle(
    fontFamily: inter,
    fontSize: 18,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.0,
    height: 1.0,
  );

  static TextStyle bodyMedium({Color? color}) => TextStyle(
    fontFamily: inter,
    fontSize: 16,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.0,
    height: 1.0,
  );

  static TextStyle bodySmall({Color? color}) => TextStyle(
    fontFamily: inter,
    fontSize: 14,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.0,
    height: 1.0,
  );

  // Button Text
  static TextStyle buttonText({Color? color}) => TextStyle(
    fontFamily: inter,
    fontSize: 18,
    color: color ?? Colors.black,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
    height: 1.5,
  );

  // Monetary Values (RobotoMono)
  static TextStyle monetaryLarge({Color? color}) => TextStyle(
    fontFamily: robotoMono,
    fontSize: 38,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w700,
  );

  static TextStyle monetaryMedium({Color? color}) => TextStyle(
    fontFamily: robotoMono,
    fontSize: 24,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w500,
  );

  // Labels
  static TextStyle label({Color? color}) => TextStyle(
    fontFamily: inter,
    fontSize: 14,
    color: color ?? Colors.white.withOpacity(0.8),
    fontWeight: FontWeight.w400,
  );

  static TextStyle pillLabel({Color? color}) => TextStyle(
    fontFamily: inter,
    fontSize: 14,
    color: color ?? Colors.white,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );
}

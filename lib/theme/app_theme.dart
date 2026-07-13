import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

/// Legacy no-op transition — kept for the (rare) case a caller wants
/// an explicit instant swap. New screens should not use this.
class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class AppTheme {
  // IBM Plex Sans base text style
  static TextStyle get _baseTextStyle => AppTypography.ibm(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: Colors.white,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: false,
      // iOS-style horizontal slide + parallax fade on every platform, so
      // detail pushes feel consistent between iOS sim, Android, and macOS.
      // Enables edge-swipe-back on iOS for free.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // Set IBM Plex Sans as the default font family
      fontFamily: AppTypography.ibm().fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1B4332),
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.accentPrimary,
        secondary: AppColors.accentPrimary,
        tertiary: AppColors.accentPrimary,
        surface: AppColors.infoCardBg,
        onSurface: Colors.white,
        background: Colors.black,
        onBackground: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.black,
      textTheme: TextTheme(
        // Display styles
        displayLarge: AppTypography.ibm(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        displayMedium: AppTypography.ibm(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        displaySmall: AppTypography.ibm(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        // Headline styles
        headlineLarge: AppTypography.ibm(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        headlineMedium: AppTypography.ibm(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        headlineSmall: AppTypography.ibm(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.43,
        ),
        // Title styles
        titleLarge: AppTypography.ibm(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: AppTypography.ibm(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.43,
        ),
        titleSmall: AppTypography.ibm(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        // Body styles - base 17px
        bodyLarge: AppTypography.ibm(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        bodyMedium: AppTypography.ibm(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        bodySmall: AppTypography.ibm(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.white.withOpacity(0.7),
        ),
        // Label styles
        labelLarge: AppTypography.ibm(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        labelMedium: AppTypography.ibm(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        labelSmall: AppTypography.ibm(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(110),
          ),
          elevation: 0,
          textStyle: AppTypography.ibm(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.43,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          textStyle: AppTypography.ibm(
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF3C3C43).withOpacity(0.18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
          borderSide: BorderSide(
            color: AppColors.accentPrimary.withOpacity(0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
          borderSide: BorderSide(
            color: AppColors.accentPrimary.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
          borderSide: const BorderSide(
            color: AppColors.accentPrimary,
          ),
        ),
        hintStyle: AppTypography.ibm(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: Colors.white.withOpacity(0.5),
        ),
        labelStyle: AppTypography.ibm(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        color: AppColors.infoCardBg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.ibm(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.infoCardBg,
        selectedItemColor: AppColors.accentPrimary,
        unselectedItemColor: Colors.white.withOpacity(0.5),
        selectedLabelStyle: AppTypography.ibm(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: AppTypography.ibm(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusXl),
        ),
        titleTextStyle: AppTypography.ibm(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: AppTypography.ibm(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.accentPrimary,
        contentTextStyle: AppTypography.ibm(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        ),
      ),
    );
  }
}

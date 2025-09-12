import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PokerFriendColors {
  static const Color white = Color(0xFFFFFDF8);
  static const Color black = Color(0xFF1C1C1C);
  static const Color purple = Color(0xFFAB9FF2);
  static const Color lilac = Color(0xFFE2DFFE);
  static const Color yellow = Color(0xFFFFD13F);
  static const Color blue = Color(0xFF4A87F2);
  static const Color midnightPurple = Color(0xFF3C315B);
  static const Color midnightPurple70 = Color(0xB33C315B);
  static const Color pink = Color(0xFFFFDADC);
  static const Color green = Color(0xFF2EC08B);
  static const Color moonYellow = Color(0xFFFFFFC4);
  static const Color red = Color(0xFFFF7243);
  static const Color grey = Color(0xFFE8E6E2);

  // Dark Scale
  static const Color dark1 = Color(0xFF161618);
  static const Color dark3 = Color(0xFF232326);
  static const Color dark4 = Color(0xFF28282C);
  static const Color dark5 = Color(0xFF2E2E32);
  static const Color dark6 = Color(0xFF34343A);
  static const Color dark8 = Color(0xFF5842C3);
  static const Color dark9 = Color(0xFF706F78);
  static const Color dark10 = Color(0xFF7E7D86);
  static const Color dark11 = Color(0xFFA09FA6);
  static const Color dark12 = Color(0xFFEDEDEF);

  // Light Scale
  static const Color light3 = Color(0xFFF4F2F4);
  static const Color light5 = Color(0xFFE9E8EA);
  static const Color light6 = Color(0xFFE4E2E4);
  static const Color light9 = Color(0xFF908E96);
  static const Color light10 = Color(0xFF86848D);

  // Violet Scale
  static const Color darkViolet4 = Color(0xFF2C2250);
  static const Color darkViolet6 = Color(0xFF392C72);
  static const Color violet1 = Color(0xFFFDFCFE);
  static const Color violet3 = Color(0xFFF5F2FF);
  static const Color violet4 = Color(0xFFEDE9FE);
  static const Color violet6 = Color(0xFFD7CFF9);
  static const Color violet8 = Color(0xFFAA99EC);
}

class PokerFriendSpacing {
  static const double xxxs = 4.0;
  static const double xxs = 8.0;
  static const double xs = 16.0;
  static const double s = 24.0;
  static const double m = 32.0;
  static const double l = 48.0;
  static const double xl = 64.0;
  static const double xxl = 96.0;
  static const double xxxl = 128.0;
}

class PokerFriendRadius {
  static const double s = 4.0;
  static const double m = 8.0;
  static const double l = 16.0;
  static const double xl = 32.0;
  static const double xxl = 100.0;
}

class PokerFriendTheme {
  static const Duration transitionDuration = Duration(milliseconds: 300);
  static const Curve transitionCurve = Curves.easeInOutCubic;

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: PokerFriendColors.purple,
      primaryContainer: PokerFriendColors.lilac,
      secondary: PokerFriendColors.midnightPurple,
      secondaryContainer: PokerFriendColors.violet3,
      tertiary: PokerFriendColors.blue,
      surface: PokerFriendColors.white,
      surfaceContainerLowest: PokerFriendColors.violet1,
      surfaceContainerLow: PokerFriendColors.violet3,
      surfaceContainer: PokerFriendColors.light3,
      surfaceContainerHigh: PokerFriendColors.light6,
      onPrimary: PokerFriendColors.white,
      onPrimaryContainer: PokerFriendColors.midnightPurple,
      onSecondary: PokerFriendColors.white,
      onSurface: PokerFriendColors.midnightPurple,
      onSurfaceVariant: PokerFriendColors.light10,
      outline: PokerFriendColors.light6,
      outlineVariant: PokerFriendColors.light5,
      error: PokerFriendColors.red,
      onError: PokerFriendColors.white,
      shadow: PokerFriendColors.light6,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: PokerFriendColors.violet3,
      
      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(
          color: PokerFriendColors.white,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: const IconThemeData(
          color: PokerFriendColors.white,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: PokerFriendColors.white,
        shadowColor: PokerFriendColors.light6,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PokerFriendRadius.l),
        ),
        margin: const EdgeInsets.all(PokerFriendSpacing.xxs),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
          shadowColor: PokerFriendColors.light6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PokerFriendRadius.m),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: PokerFriendSpacing.s,
            vertical: PokerFriendSpacing.xs,
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PokerFriendRadius.m),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: PokerFriendSpacing.xs,
            vertical: PokerFriendSpacing.xxs,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PokerFriendRadius.m),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: PokerFriendSpacing.s,
            vertical: PokerFriendSpacing.xs,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PokerFriendColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PokerFriendRadius.m),
          borderSide: const BorderSide(color: PokerFriendColors.light6),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PokerFriendRadius.m),
          borderSide: const BorderSide(color: PokerFriendColors.light6),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PokerFriendRadius.m),
          borderSide: const BorderSide(color: PokerFriendColors.purple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PokerFriendRadius.m),
          borderSide: const BorderSide(color: PokerFriendColors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PokerFriendSpacing.xs,
          vertical: PokerFriendSpacing.xs,
        ),
        labelStyle: const TextStyle(
          color: PokerFriendColors.light10,
          fontSize: 16,
        ),
        hintStyle: const TextStyle(
          color: PokerFriendColors.light9,
          fontSize: 16,
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: PokerFriendColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PokerFriendRadius.l),
        ),
        titleTextStyle: const TextStyle(
          color: PokerFriendColors.midnightPurple,
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
        contentTextStyle: const TextStyle(
          color: PokerFriendColors.midnightPurple,
          fontSize: 16,
          height: 1.5,
        ),
      ),

      // Snack Bar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PokerFriendColors.midnightPurple,
        contentTextStyle: const TextStyle(
          color: PokerFriendColors.white,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PokerFriendRadius.m),
        ),
        behavior: SnackBarBehavior.floating,
        actionTextColor: PokerFriendColors.purple,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: PokerFriendColors.white,
        selectedItemColor: PokerFriendColors.purple,
        unselectedItemColor: PokerFriendColors.light10,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Text Theme
      textTheme: const TextTheme(
        // Display
        displayLarge: TextStyle(
          fontSize: 96,
          fontWeight: FontWeight.w400,
          color: PokerFriendColors.midnightPurple,
          height: 1.1,
        ),
        displayMedium: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w400,
          color: PokerFriendColors.midnightPurple,
          height: 1.1,
        ),
        displaySmall: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w400,
          color: PokerFriendColors.midnightPurple,
          height: 1.15,
        ),
        
        // Headlines
        headlineLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w400,
          color: PokerFriendColors.midnightPurple,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: PokerFriendColors.midnightPurple,
          height: 1.2,
        ),
        headlineSmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          color: PokerFriendColors.midnightPurple,
          height: 1.2,
        ),
        
        // Titles
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: PokerFriendColors.midnightPurple,
          height: 1.2,
        ),
        titleMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: PokerFriendColors.midnightPurple,
          height: 1.2,
        ),
        titleSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: PokerFriendColors.midnightPurple,
          height: 1.3,
        ),
        
        // Labels
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: PokerFriendColors.midnightPurple,
        ),
        labelMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: PokerFriendColors.midnightPurple,
        ),
        labelSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: PokerFriendColors.light10,
        ),
        
        // Body
        bodyLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: PokerFriendColors.midnightPurple,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: PokerFriendColors.midnightPurple,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: PokerFriendColors.light10,
          height: 1.4,
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: PokerFriendColors.midnightPurple,
        size: 24,
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: PokerFriendColors.purple,
        foregroundColor: PokerFriendColors.white,
        elevation: 4,
      ),

      // List Tile Theme
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: PokerFriendSpacing.xs,
          vertical: PokerFriendSpacing.xxs,
        ),
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: PokerFriendColors.midnightPurple,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 14,
          color: PokerFriendColors.light10,
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: PokerFriendColors.light6,
        thickness: 1,
        space: 1,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return PokerFriendColors.white;
          }
          return PokerFriendColors.light9;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return PokerFriendColors.purple;
          }
          return PokerFriendColors.light6;
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return PokerFriendColors.purple;
          }
          return PokerFriendColors.white;
        }),
        checkColor: WidgetStateProperty.all(PokerFriendColors.white),
        side: const BorderSide(color: PokerFriendColors.light6, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PokerFriendRadius.s),
        ),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return PokerFriendColors.purple;
          }
          return PokerFriendColors.light9;
        }),
      ),
    );
  }
}

// Custom widget styles
class PokerFriendWidgets {
  static BoxDecoration get primaryCard => BoxDecoration(
    color: PokerFriendColors.white,
    borderRadius: BorderRadius.circular(PokerFriendRadius.l),
    boxShadow: [
      BoxShadow(
        color: PokerFriendColors.light6.withOpacity(0.3),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration get secondaryCard => BoxDecoration(
    color: PokerFriendColors.violet1,
    borderRadius: BorderRadius.circular(PokerFriendRadius.l),
    border: Border.all(color: PokerFriendColors.light6, width: 1),
  );

  static BoxDecoration get surfaceCard => BoxDecoration(
    color: PokerFriendColors.lilac,
    borderRadius: BorderRadius.circular(PokerFriendRadius.m),
  );

  static BoxDecoration get gradientBackground => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        PokerFriendColors.violet3,
        PokerFriendColors.violet1,
      ],
    ),
  );

  static BoxDecoration get purpleGradient => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        PokerFriendColors.purple,
        PokerFriendColors.violet6,
      ],
    ),
  );
}

// Animation curves matching the design system
class PokerFriendCurves {
  static const Curve snap = Curves.easeOutBack;
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve easeOutQuart = Curves.easeOutQuart;
  static const Curve easeInOutQuart = Curves.easeInOutQuart;
}
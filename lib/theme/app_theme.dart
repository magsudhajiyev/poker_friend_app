import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: false,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1B4332), // Deep forest green
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF1B4332), // Deep forest green
        secondary: const Color(0xFF40916C), // Medium green
        tertiary: const Color(0xFFD4AF37), // Gold accent
        surface: const Color(0xFFF8F9FA), // Light gray background
        onSurface: const Color(0xFF212529), // Dark text
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1B4332),
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1B4332),
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1B4332),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFF495057),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF6C757D),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B4332),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1B4332),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
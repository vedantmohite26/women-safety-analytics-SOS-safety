import 'package:flutter/material.dart';

class AppTheme {
  // Premium Color Palette - SafeGuardian Pink Theme
  static const Color primary = Color(0xFFE91E63); // Material Pink 500
  static const Color secondary = Color(0xFFF48FB1); // Material Pink 200
  static const Color accent = Color(0xFFFF4081); // Pink Accent
  static const Color backgroundStart = Color(0xFFFCE4EC); // Light Pink
  static const Color backgroundEnd = Colors.white;
  static const Color error = Color(0xFFC2185B); // Dark Pink for errors
  static const Color success = Color(0xFF4CAF50); // Green for success
  static const Color darkPink = Color(0xFFC2185B); // Material Pink 700

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        secondary: secondary,
        error: error,
        surface: Colors.white.withValues(alpha: 0.9),
      ),
      scaffoldBackgroundColor:
          Colors.transparent, // Important for GradientScaffold
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white, // Glass effect
        shadowColor: Colors.black,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: primary.withValues(alpha: 0.4),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        prefixIconColor: Colors.grey.shade600,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        bodyLarge: TextStyle(color: Colors.black87),
        bodyMedium: TextStyle(color: Colors.black87),
      ),
    );
  }

  static BoxDecoration get glassDecoration {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.5),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

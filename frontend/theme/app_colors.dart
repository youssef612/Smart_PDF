// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

/// 🎨 Modern Blue-Purple-Cyan Color System
class AppColors {
  // Primary Colors
  static const Color primaryBlue = Color(0xFF2563EB);       // Sapphire Blue
  static const Color primaryPurple = Color(0xFF7C3AED);    // Royal Purple
  static const Color accentCyan = Color(0xFF06B6D4);       // Cyan

  // Secondary Colors
  static const Color secondaryGreen = Color(0xFF10B981);   // Emerald Green
  static const Color secondaryAmber = Color(0xFFF59E0B);   // Amber

  // Background Colors
  static const Color bgLight = Color(0xFFF8FAFC);          // Very Light Blue
  static const Color bgLighter = Color(0xFFEFF6FF);        // Light Blue
  static const Color bgLightest = Color(0xFFF3E8FF);       // Light Purple

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);      // Very Dark Blue
  static const Color textSecondary = Color(0xFF475569);    // Slate Gray
  static const Color textTertiary = Color(0xFF94A3B8);     // Light Gray

  // Surface
  static const Color surface = Colors.white;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryBlue,
      primaryPurple,
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      accentCyan,
      primaryBlue,
    ],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      bgLight,
      bgLighter,
      bgLightest,
    ],
  );

  static const LinearGradient titleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryBlue,
      primaryPurple,
      accentCyan,
    ],
  );
}

/// Theme configuration
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        secondary: AppColors.primaryPurple,
        tertiary: AppColors.accentCyan,
        surface: AppColors.surface,
        background: AppColors.bgLight,
        onBackground: AppColors.textPrimary,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

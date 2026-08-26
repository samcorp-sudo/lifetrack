import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Light and Dark themes (Phase 2 §8 — user switches in Settings).
class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.lightCard,
        elevation: 1,
      ),
      textTheme: _textTheme(AppColors.lightText),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
      ),
      textTheme: _textTheme(AppColors.darkText),
    );
  }

  /// Typography scale from Phase 2 §7 — Large heading / Section heading / Body / Caption.
  static TextTheme _textTheme(Color textColor) {
    return TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor),
      bodyMedium: TextStyle(fontSize: 15, color: textColor),
      bodySmall: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.7)),
    );
  }
}

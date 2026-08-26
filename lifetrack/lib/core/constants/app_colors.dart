import 'package:flutter/material.dart';

/// Shared color values referenced by app/theme.dart and widgets.
/// Keeping these separate from theme.dart means widgets can reference
/// a specific brand color without importing the whole ThemeData setup.
class AppColors {
  // Brand
  static const Color primary = Color(0xFF2E7D32); // green — money/growth feel
  static const Color secondary = Color(0xFFFFA000); // amber — goals/highlights

  // Category accent colors (Screen 2 calendar dots, Screen 8 charts)
  static const Color categorySchool = Color(0xFF1E88E5);
  static const Color categoryCoding = Color(0xFF8E24AA);
  static const Color categoryFreelance = Color(0xFFFB8C00);
  static const Color categoryFarming = Color(0xFF43A047);
  static const Color categoryPersonal = Color(0xFF00ACC1);
  static const Color categoryRest = Color(0xFF9E9E9E);

  // Status
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFFA000);

  // Light theme surfaces
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF212121);

  // Dark theme surfaces
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkText = Color(0xFFECECEC);
}

// ============================================================================
// LifeTrack — App Theme ("Ledger" design system)
// ----------------------------------------------------------------------------
// Design concept: a builder's ledger. LifeTrack is used by someone tracking
// money, time and skills at once, so the palette borrows from a paper ledger
// (warm page, ruled lines, ink) crossed with a code editor at night. The
// amber "highlighter" accent is the one signature color used for progress,
// emphasis and primary actions — everything else stays quiet on purpose.
//
// Tokens:
//   Ink        #12131A   near-black background (dark surfaces)
//   Panel      #1C1E2A   card surface on dark
//   Paper      #F6F3EC   warm off-white background (light surfaces)
//   PanelLight #FFFFFF   card surface on light
//   Highlight  #F2B705   signature accent — progress, CTAs, focus
//   Mint       #2FBF9F   positive / income / success
//   Coral      #E5484D   negative / expense / high priority
//   SkyInfo    #5B8DEF   informational accents, links, "free" chips
//
// WIRING NOTES:
// - No wiring needed here beyond `flutter pub add google_fonts`. This file
//   is pure design system and does not depend on app data.
// - Settings > Appearance > Dark Mode toggle should flip
//   MaterialApp.themeMode between ThemeMode.light / ThemeMode.dark using
//   whatever state layer is chosen in Phase 9 (Provider/Riverpod/etc). See
//   lib/screens/settings/settings_screen.dart for the exact.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LifeTrackColors {
  LifeTrackColors._();

  static const ink = Color(0xFF12131A);
  static const panelDark = Color(0xFF1C1E2A);
  static const strokeDark = Color(0xFF2B2E40);

  static const paper = Color(0xFFF6F3EC);
  static const panelLight = Color(0xFFFFFFFF);
  static const strokeLight = Color(0xFFE6E1D6);

  static const highlight = Color(0xFFF2B705); // signature amber
  static const highlightDeep = Color(0xFFC98F00);
  static const mint = Color(0xFF2FBF9F); // income / success
  static const coral = Color(0xFFE5484D); // expense / danger
  static const skyInfo = Color(0xFF5B8DEF); // info / free-time

  static const textOnDark = Color(0xFFF5F3EE);
  static const textMutedOnDark = Color(0xFF9A9CB0);
  static const textOnLight = Color(0xFF14151C);
  static const textMutedOnLight = Color(0xFF6F7180);
}

class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Color base, Color muted) {
    final display = GoogleFonts.sora(color: base, fontWeight: FontWeight.w700);
    final body = GoogleFonts.inter(color: base);
    return TextTheme(
      displayLarge: display.copyWith(fontSize: 32, letterSpacing: -0.5),
      headlineMedium: display.copyWith(fontSize: 24, letterSpacing: -0.3),
      titleLarge: display.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: body.copyWith(fontSize: 15, height: 1.4),
      bodyMedium: body.copyWith(fontSize: 13.5, height: 1.4, color: muted),
      labelLarge: body.copyWith(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      labelSmall: body.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: muted, letterSpacing: 0.6),
    );
  }

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: LifeTrackColors.highlight,
      onPrimary: LifeTrackColors.textOnLight,
      secondary: LifeTrackColors.mint,
      error: LifeTrackColors.coral,
      surface: LifeTrackColors.panelLight,
      onSurface: LifeTrackColors.textOnLight,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: LifeTrackColors.paper,
      textTheme: _textTheme(LifeTrackColors.textOnLight, LifeTrackColors.textMutedOnLight),
      dividerColor: LifeTrackColors.strokeLight,
      cardColor: LifeTrackColors.panelLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: LifeTrackColors.paper,
        foregroundColor: LifeTrackColors.textOnLight,
        elevation: 0,
        centerTitle: false,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: LifeTrackColors.highlight,
      onPrimary: LifeTrackColors.ink,
      secondary: LifeTrackColors.mint,
      error: LifeTrackColors.coral,
      surface: LifeTrackColors.panelDark,
      onSurface: LifeTrackColors.textOnDark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: LifeTrackColors.ink,
      textTheme: _textTheme(LifeTrackColors.textOnDark, LifeTrackColors.textMutedOnDark),
      dividerColor: LifeTrackColors.strokeDark,
      cardColor: LifeTrackColors.panelDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: LifeTrackColors.ink,
        foregroundColor: LifeTrackColors.textOnDark,
        elevation: 0,
        centerTitle: false,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}

/// Shared corner radii / spacing so every screen stays consistent
/// without re-declaring magic numbers.
class LifeTrackMetrics {
  LifeTrackMetrics._();
  static const double cardRadius = 20;
  static const double chipRadius = 14;
  static const double screenPadding = 20;
  static const double gap = 12;
}

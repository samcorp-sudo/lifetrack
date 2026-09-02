// ============================================================================
// LifeTrack — App Theme ("Ledger" design system) + Philippine seasons
// ----------------------------------------------------------------------------
// Design concept: a builder's ledger. LifeTrack is used by someone tracking
// money, time and skills at once, so the palette borrows from a paper ledger
// (warm page, ruled lines, ink) crossed with a code editor at night.
//
// SEASONS:
//   The one signature accent color changes with the Philippine seasons.
//     Tag-init  (hot dry)   Mar - May   sunny orange
//     Tag-ulan  (rainy)     Jun - Nov   teal
//     Amihan    (cool dry)  Dec - Feb   violet
//   Plus "Classic" (the original amber) and "Auto" (follows today's date).
//
// THEME MODE:
//   Default is ThemeMode.light. "Dark Mode off" always means light, even
//   if the phone's OS is set to dark. This stops the app from going black
//   while the in-app toggle reads off.
//
// Fixed tokens (do not change with the season):
//   Ink        #12131A   near-black background (dark surfaces)
//   Panel      #1C1E2A   card surface on dark
//   Paper      #F6F3EC   warm off-white background (classic light surface)
//   PanelLight #FFFFFF   card surface on light
//   Mint       #2FBF9F   positive / income / success
//   Coral      #E5484D   negative / expense / high priority
//   SkyInfo    #5B8DEF   informational accents, links, "free" chips
//
// NOTE: LifeTrackColors.highlight / highlightDeep still exist and always mean
// the CLASSIC amber. Screens that should follow the season must use
// context.season.* instead.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LifeTrackColors {
  LifeTrackColors._();

  static const ink = Color(0xFF12131A);
  static const panelDark = Color(0xFF1C1E2A);
  static const strokeDark = Color(0xFF2B2E40);

  static const paper = Color(0xFFF6F3EC);
  static const panelLight = Color(0xFFFFFFFF);
  static const strokeLight = Color(0xFFE6E1D6);

  static const highlight = Color(0xFFF2B705); // classic amber
  static const highlightDeep = Color(0xFFC98F00);
  static const mint = Color(0xFF2FBF9F); // income / success
  static const coral = Color(0xFFE5484D); // expense / danger
  static const skyInfo = Color(0xFF5B8DEF); // info / free-time

  static const textOnDark = Color(0xFFF5F3EE);
  static const textMutedOnDark = Color(0xFF9A9CB0);
  static const textOnLight = Color(0xFF14151C);
  static const textMutedOnLight = Color(0xFF6F7180);
}

// ============================================================================
// Theme mode controller
// ============================================================================

class ThemeModeController {
  ThemeModeController._();

  static const String _prefsKey = 'theme_mode';

  /// Default is LIGHT (not system). "Dark Mode off" always means light,
  /// even if the phone's OS is set to dark. This is what stops the app
  /// from going black while the in-app toggle reads off.
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      mode.value = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.light,
      );
    } catch (_) {
      // Keep the default (light) if storage is unavailable.
    }
  }

  static Future<void> setMode(ThemeMode value) async {
    mode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, value.name);
    } catch (_) {}
  }
}

// ============================================================================
// Seasons
// ============================================================================

enum Season { hotDry, rainy, coolDry }

enum SeasonMode { auto, hotDry, rainy, coolDry, classic }

extension SeasonModeX on SeasonMode {
  String get label {
    switch (this) {
      case SeasonMode.auto:
        return 'Auto';
      case SeasonMode.hotDry:
        return 'Tag-init';
      case SeasonMode.rainy:
        return 'Tag-ulan';
      case SeasonMode.coolDry:
        return 'Amihan';
      case SeasonMode.classic:
        return 'Classic amber';
    }
  }

  String get subtitle {
    switch (this) {
      case SeasonMode.auto:
        return 'Follows the date and changes with the season';
      case SeasonMode.hotDry:
        return 'Hot dry season (Mar - May)';
      case SeasonMode.rainy:
        return 'Rainy season (Jun - Nov)';
      case SeasonMode.coolDry:
        return 'Cool dry season (Dec - Feb)';
      case SeasonMode.classic:
        return 'The original amber look, all year';
    }
  }
}

/// Colors for one look of the app.
class SeasonPalette {
  const SeasonPalette({
    required this.name,
    required this.emoji,
    required this.accent,
    required this.accentDeep,
    required this.onAccent,
    required this.paper,
  });

  final String name;
  final String emoji;

  /// Main accent: buttons, progress, selected states, hero card.
  final Color accent;

  /// Darker shade of the accent (gradients, and text/icons on light surfaces).
  final Color accentDeep;

  /// Text / icon color that stays readable ON the accent.
  final Color onAccent;

  /// Light-mode page background, slightly tinted by the season.
  final Color paper;

  static const classic = SeasonPalette(
    name: 'Classic',
    emoji: '✨',
    accent: LifeTrackColors.highlight,
    accentDeep: LifeTrackColors.highlightDeep,
    onAccent: LifeTrackColors.ink,
    paper: LifeTrackColors.paper,
  );

  // Tag-init: sunny orange on warm cream.
  static const hotDry = SeasonPalette(
    name: 'Tag-init',
    emoji: '☀️',
    accent: Color(0xFFFF8A1F),
    accentDeep: Color(0xFFD96A00),
    onAccent: LifeTrackColors.ink,
    paper: Color(0xFFFFF4E3),
  );

  // Tag-ulan: fresh teal (not blue) on a cool mist.
  static const rainy = SeasonPalette(
    name: 'Tag-ulan',
    emoji: '🌧️',
    accent: Color(0xFF14B8A6),
    accentDeep: Color(0xFF0E8F81),
    onAccent: LifeTrackColors.ink,
    paper: Color(0xFFEEF7F5),
  );

  // Amihan: violet on a soft lavender page.
  static const coolDry = SeasonPalette(
    name: 'Amihan',
    emoji: '🎄',
    accent: Color(0xFF8B5CF6),
    accentDeep: Color(0xFF6D28D9),
    onAccent: Colors.white,
    paper: Color(0xFFF4F1FB),
  );

  static SeasonPalette forSeason(Season season) {
    switch (season) {
      case Season.hotDry:
        return hotDry;
      case Season.rainy:
        return rainy;
      case Season.coolDry:
        return coolDry;
    }
  }
}

/// Chooses which palette the whole app uses, and remembers the choice.
/// Call [load] once in main() before runApp, and wrap MaterialApp in a
/// ValueListenableBuilder on [mode] so the app rebuilds when it changes.
class SeasonController {
  SeasonController._();

  static const String _prefsKey = 'season_mode';

  static final ValueNotifier<SeasonMode> mode =
      ValueNotifier<SeasonMode>(SeasonMode.auto);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      mode.value = SeasonMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => SeasonMode.auto,
      );
    } catch (_) {
      // Keep the default (Auto) if storage is unavailable.
    }
  }

  static Future<void> setMode(SeasonMode value) async {
    mode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, value.name);
    } catch (_) {}
  }

  /// Philippine seasons by month.
  static Season seasonForDate(DateTime date) {
    final m = date.month;
    if (m >= 3 && m <= 5) return Season.hotDry; // Mar - May
    if (m >= 6 && m <= 11) return Season.rainy; // Jun - Nov
    return Season.coolDry; // Dec - Feb
  }

  static SeasonPalette paletteFor(SeasonMode m) {
    switch (m) {
      case SeasonMode.auto:
        return SeasonPalette.forSeason(seasonForDate(DateTime.now()));
      case SeasonMode.hotDry:
        return SeasonPalette.hotDry;
      case SeasonMode.rainy:
        return SeasonPalette.rainy;
      case SeasonMode.coolDry:
        return SeasonPalette.coolDry;
      case SeasonMode.classic:
        return SeasonPalette.classic;
    }
  }

  /// The palette in use right now.
  static SeasonPalette get palette => paletteFor(mode.value);
}

/// The active palette, attached to ThemeData so any widget can read it with
/// `context.season`.
@immutable
class SeasonColors extends ThemeExtension<SeasonColors> {
  const SeasonColors({
    required this.name,
    required this.emoji,
    required this.accent,
    required this.accentDeep,
    required this.accentText,
    required this.onAccent,
  });

  final String name;
  final String emoji;

  /// Main accent.
  final Color accent;

  /// Darker accent (gradient end).
  final Color accentDeep;

  /// Accent for text and icons placed on the page / cards:
  /// deeper in light mode, brighter in dark mode, so it stays readable.
  final Color accentText;

  /// Color for text and icons placed ON the accent (hero card, buttons).
  final Color onAccent;

  static const classic = SeasonColors(
    name: 'Classic',
    emoji: '✨',
    accent: LifeTrackColors.highlight,
    accentDeep: LifeTrackColors.highlightDeep,
    accentText: LifeTrackColors.highlightDeep,
    onAccent: LifeTrackColors.ink,
  );

  @override
  SeasonColors copyWith({
    String? name,
    String? emoji,
    Color? accent,
    Color? accentDeep,
    Color? accentText,
    Color? onAccent,
  }) {
    return SeasonColors(
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      accent: accent ?? this.accent,
      accentDeep: accentDeep ?? this.accentDeep,
      accentText: accentText ?? this.accentText,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  SeasonColors lerp(ThemeExtension<SeasonColors>? other, double t) {
    if (other is! SeasonColors) return this;
    return SeasonColors(
      name: t < 0.5 ? name : other.name,
      emoji: t < 0.5 ? emoji : other.emoji,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

extension SeasonContext on BuildContext {
  /// The active season colors: context.season.accent, .accentDeep, ...
  SeasonColors get season =>
      Theme.of(this).extension<SeasonColors>() ?? SeasonColors.classic;
}

// ============================================================================
// Theme
// ============================================================================

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
      labelLarge: body.copyWith(
          fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      labelSmall: body.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: muted,
          letterSpacing: 0.6),
    );
  }

  static ThemeData _build(Brightness brightness, SeasonPalette palette) {
    final isDark = brightness == Brightness.dark;

    final scaffold = isDark ? LifeTrackColors.ink : palette.paper;
    final surface =
        isDark ? LifeTrackColors.panelDark : LifeTrackColors.panelLight;
    // AppBar gets its own surface so it doesn't blend into the page.
    // This is what makes the app stop looking like one flat black slab
    // when dark mode is on.
    final appBarSurface =
        isDark ? LifeTrackColors.panelDark : LifeTrackColors.panelLight;
    final onSurface =
        isDark ? LifeTrackColors.textOnDark : LifeTrackColors.textOnLight;
    final muted = isDark
        ? LifeTrackColors.textMutedOnDark
        : LifeTrackColors.textMutedOnLight;

    final scheme = isDark
        ? ColorScheme.dark(
            primary: palette.accent,
            onPrimary: palette.onAccent,
            secondary: LifeTrackColors.mint,
            error: LifeTrackColors.coral,
            surface: surface,
            onSurface: onSurface,
          )
        : ColorScheme.light(
            primary: palette.accent,
            onPrimary: palette.onAccent,
            secondary: LifeTrackColors.mint,
            error: LifeTrackColors.coral,
            surface: surface,
            onSurface: onSurface,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: _textTheme(onSurface, muted),
      dividerColor:
          isDark ? LifeTrackColors.strokeDark : LifeTrackColors.strokeLight,
      cardColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarSurface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      splashFactory: InkRipple.splashFactory,
      extensions: [
        SeasonColors(
          name: palette.name,
          emoji: palette.emoji,
          accent: palette.accent,
          accentDeep: palette.accentDeep,
          accentText: isDark ? palette.accent : palette.accentDeep,
          onAccent: palette.onAccent,
        ),
      ],
    );
  }

  static ThemeData get light =>
      _build(Brightness.light, SeasonController.palette);

  static ThemeData get dark =>
      _build(Brightness.dark, SeasonController.palette);
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

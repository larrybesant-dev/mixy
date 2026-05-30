// Ember Dark Design System — MixVy After Dark
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/font_fallbacks.dart';

// ── Ember Dark colour tokens ──────────────────────────────────────────────────
class EmberDark {
  // Surfaces — velvet black with wine undertones
  static const Color surface = Color(0xFF060305);
  static const Color surfaceLow = Color(0xFF0C0508);
  static const Color surfaceContainer = Color(0xFF160A10);
  static const Color surfaceHigh = Color(0xFF201018);
  static const Color surfaceBright = Color(0xFF2C1621);
  static const Color surfaceHighest = Color(0xFF331924);

  // Brand — cabernet · blush rose
  static const Color primary = Color(0xFFB32245);
  static const Color primaryDim = Color(0xFF6C1028);
  static const Color secondary = Color(0xFFE2A7B7);

  // On-surface — warm ivory with rose tint
  static const Color onSurface = Color(0xFFF6E9EA);
  static const Color onSurfaceVariant = Color(0xFFC2A0A8);
  static const Color outlineVariant = Color(0xFF5C2A38);

  // Status
  static const Color error = Color(0xFFE96A80);
  static const Color live = Color(0xFFB32245);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDim],
  );

  static const LinearGradient bannerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C1028), Color(0xFF22030D)],
  );

  static const LinearGradient velvetGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3A0D19), Color(0xFF18070D), surface],
    stops: [0.0, 0.55, 1.0],
  );
}

TextStyle _afterDarkPlayfair(TextStyle style) => withMixvyFontFallback(style);
TextStyle _afterDarkRaleway(TextStyle style) => withMixvyFontFallback(style);

final ThemeData afterDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: EmberDark.surface,
  colorScheme: const ColorScheme.dark(
    primary: EmberDark.primary,
    secondary: EmberDark.secondary,
    surface: EmberDark.surface,
    error: EmberDark.error,
    onPrimary: EmberDark.onSurface,
    onSecondary: EmberDark.onSurface,
    onSurface: EmberDark.onSurface,
    onError: EmberDark.onSurface,
    surfaceContainerLow: EmberDark.surfaceLow,
    surfaceContainer: EmberDark.surfaceContainer,
    surfaceContainerHigh: EmberDark.surfaceHigh,
    surfaceContainerHighest: EmberDark.surfaceHighest,
    outline: EmberDark.outlineVariant,
  ),
  textTheme: TextTheme(
    displayLarge: _afterDarkPlayfair(
      GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.5,
        color: EmberDark.onSurface,
      ),
    ),
    displayMedium: _afterDarkPlayfair(
      GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w700,
        fontSize: 28,
        letterSpacing: -0.3,
        color: EmberDark.onSurface,
      ),
    ),
    headlineLarge: _afterDarkPlayfair(
      GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w700,
        fontSize: 26,
        color: EmberDark.onSurface,
      ),
    ),
    headlineMedium: _afterDarkPlayfair(
      GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: EmberDark.onSurface,
      ),
    ),
    headlineSmall: _afterDarkPlayfair(
      GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: EmberDark.onSurface,
      ),
    ),
    titleLarge: _afterDarkPlayfair(
      GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w600,
        fontSize: 20,
        color: EmberDark.onSurface,
      ),
    ),
    titleMedium: _afterDarkRaleway(
      GoogleFonts.raleway(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: EmberDark.onSurface,
      ),
    ),
    titleSmall: _afterDarkRaleway(
      GoogleFonts.raleway(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: EmberDark.onSurface,
      ),
    ),
    bodyLarge: _afterDarkRaleway(
      GoogleFonts.raleway(fontSize: 16, color: EmberDark.onSurface),
    ),
    bodyMedium: _afterDarkRaleway(
      GoogleFonts.raleway(fontSize: 14, color: EmberDark.onSurfaceVariant),
    ),
    bodySmall: _afterDarkRaleway(
      GoogleFonts.raleway(fontSize: 12, color: EmberDark.onSurfaceVariant),
    ),
    labelLarge: _afterDarkRaleway(
      GoogleFonts.raleway(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: EmberDark.onSurface,
      ),
    ),
    labelMedium: _afterDarkRaleway(
      GoogleFonts.raleway(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: EmberDark.onSurface,
      ),
    ),
    labelSmall: _afterDarkRaleway(
      GoogleFonts.raleway(
        fontWeight: FontWeight.w500,
        fontSize: 11,
        letterSpacing: 0.6,
        color: EmberDark.onSurfaceVariant,
      ),
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: EmberDark.surface,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    foregroundColor: EmberDark.onSurface,
    centerTitle: true,
    titleTextStyle: _afterDarkPlayfair(
      GoogleFonts.playfairDisplay(
        color: EmberDark.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: EmberDark.surfaceHigh,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: EmberDark.outlineVariant.withValues(alpha: 0.5),
        width: 1,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: EmberDark.surfaceHighest,
    hintStyle: _afterDarkRaleway(
      GoogleFonts.raleway(color: EmberDark.onSurfaceVariant),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: const BorderSide(color: EmberDark.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: EmberDark.primary,
      foregroundColor: EmberDark.onSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      textStyle: _afterDarkRaleway(
        GoogleFonts.raleway(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
      ),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: EmberDark.primary,
      foregroundColor: EmberDark.onSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      textStyle: _afterDarkRaleway(
        GoogleFonts.raleway(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: EmberDark.onSurface,
      side: const BorderSide(color: EmberDark.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: EmberDark.outlineVariant,
    thickness: 1,
    space: 1,
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return EmberDark.primary;
      return EmberDark.onSurfaceVariant;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return EmberDark.primary.withValues(alpha: 0.4);
      }
      return EmberDark.surfaceBright;
    }),
  ),
  iconTheme: const IconThemeData(color: EmberDark.onSurface, size: 24),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.selected)) return EmberDark.primary;
      return Colors.transparent;
    }),
    side: const BorderSide(color: EmberDark.outlineVariant),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
);




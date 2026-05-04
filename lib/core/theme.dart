// Neon Pulse Design System — MixVy v3
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/font_fallbacks.dart';

// ── MIXVY Brand Design Tokens — Locked ──────────────────────────────────────
// Jet Black · Deep Wine Red · Gold · Soft Cream
// COLOR SYSTEM — DO NOT DEVIATE FROM THESE VALUES
class VelvetNoir {
  // Surfaces — jet black base (#0B0B0B) with subtle warm-dark elevation layers
  static const Color surface = Color(0xFF0B0B0B); // Jet Black
  static const Color surfaceLow = Color(0xFF0F0B0D);
  static const Color surfaceContainer = Color(0xFF161012);
  static const Color surfaceHigh = Color(0xFF1C1617); // from brand board
  static const Color surfaceBright = Color(0xFF241A1D);
  static const Color surfaceHighest = Color(0xFF2A1E22);

  // Brand — Gold · Deep Wine Red
  static const Color primary = Color(
    0xFFD4AF37,
  ); // Gold (#D4AF37) — buttons, logo, premium
  static const Color primaryDim = Color(0xFF9A7B1A); // deep gold shadow
  static const Color secondary = Color(
    0xFF781E2B,
  ); // Deep Wine Red (#781E2B) — rooms, passion
  static const Color secondaryBright = Color(
    0xFF9B2535,
  ); // lighter wine for highlights

  // On-surface — soft cream tones (#F7EDE2)
  static const Color onSurface = Color(0xFFF7EDE2); // Soft Cream
  static const Color onSurfaceVariant = Color(0xFFAD9585);
  static const Color outlineVariant = Color(0xFF4A2E35);

  // Status — live indicator uses wine red glow
  static const Color error = Color(0xFFE03450); // error / destructive
  static const Color liveGlow = Color(0xFF9B2535); // wine red live glow

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDim],
  );
  static const LinearGradient wineGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryBright, secondary],
  );
}

TextStyle _playfair(TextStyle style) => withMixvyFontFallback(style);
TextStyle _raleway(TextStyle style) => withMixvyFontFallback(style);

final ThemeData midnightCreativeTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: VelvetNoir.surface,
  colorScheme: const ColorScheme.dark(
    primary: VelvetNoir.primary,
    secondary: VelvetNoir.secondary,
    surface: VelvetNoir.surface,
    error: VelvetNoir.error,
    onPrimary: VelvetNoir.surface,
    onSecondary: VelvetNoir.surface,
    onSurface: VelvetNoir.onSurface,
    onError: VelvetNoir.surface,
    surfaceContainerLow: VelvetNoir.surfaceLow,
    surfaceContainer: VelvetNoir.surfaceContainer,
    surfaceContainerHigh: VelvetNoir.surfaceHigh,
    surfaceContainerHighest: VelvetNoir.surfaceHighest,
    outline: VelvetNoir.outlineVariant,
  ),
  textTheme: TextTheme(
    // Display & Headline — Playfair Display (elegant serif)
    displayLarge: _playfair(
      GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.5,
        color: VelvetNoir.onSurface,
      ),
    ),
    displayMedium: _playfair(
      GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w700,
        fontSize: 28,
        letterSpacing: -0.3,
        color: VelvetNoir.onSurface,
      ),
    ),
    headlineLarge: _playfair(
      GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w700,
        fontSize: 26,
        color: VelvetNoir.onSurface,
      ),
    ),
    headlineMedium: _playfair(
      GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: VelvetNoir.onSurface,
      ),
    ),
    headlineSmall: _playfair(
      GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: VelvetNoir.onSurface,
      ),
    ),
    titleLarge: _playfair(
      GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w600,
        fontSize: 20,
        color: VelvetNoir.onSurface,
      ),
    ),
    // Body & Labels — Raleway (clean modern — brand-spec)
    titleMedium: _raleway(
      GoogleFonts.raleway(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: VelvetNoir.onSurface,
      ),
    ),
    titleSmall: _raleway(
      GoogleFonts.raleway(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: VelvetNoir.onSurface,
      ),
    ),
    bodyLarge: _raleway(
      GoogleFonts.raleway(fontSize: 16, color: VelvetNoir.onSurface),
    ),
    bodyMedium: _raleway(
      GoogleFonts.raleway(fontSize: 14, color: VelvetNoir.onSurfaceVariant),
    ),
    bodySmall: _raleway(
      GoogleFonts.raleway(fontSize: 12, color: VelvetNoir.onSurfaceVariant),
    ),
    labelLarge: _raleway(
      GoogleFonts.raleway(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.8,
        color: VelvetNoir.onSurface,
      ),
    ),
    labelMedium: _raleway(
      GoogleFonts.raleway(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        letterSpacing: 0.6,
        color: VelvetNoir.onSurface,
      ),
    ),
    labelSmall: _raleway(
      GoogleFonts.raleway(
        fontWeight: FontWeight.w500,
        fontSize: 11,
        letterSpacing: 1.0,
        color: VelvetNoir.onSurfaceVariant,
      ),
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: VelvetNoir.surface,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    foregroundColor: VelvetNoir.onSurface,
    centerTitle: true,
    titleTextStyle: _playfair(
      GoogleFonts.playfairDisplay(
        color: VelvetNoir.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    toolbarTextStyle: _raleway(
      GoogleFonts.raleway(color: VelvetNoir.onSurface, fontSize: 14),
    ),
  ),
  tabBarTheme: TabBarThemeData(
    labelColor: VelvetNoir.primary,
    unselectedLabelColor: VelvetNoir.onSurfaceVariant,
    indicatorColor: VelvetNoir.primary,
    dividerColor: VelvetNoir.outlineVariant.withValues(alpha: 0.26),
    labelStyle: _raleway(
      GoogleFonts.raleway(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),
    unselectedLabelStyle: _raleway(
      GoogleFonts.raleway(fontSize: 13, fontWeight: FontWeight.w500),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: VelvetNoir.surfaceHigh,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0x1A73757D)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: VelvetNoir.surfaceHighest,
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
      borderSide: const BorderSide(color: VelvetNoir.primary, width: 1.5),
    ),
    hintStyle: _raleway(
      GoogleFonts.raleway(color: VelvetNoir.onSurfaceVariant, fontSize: 14),
    ),
    labelStyle: _raleway(
      GoogleFonts.raleway(color: VelvetNoir.onSurfaceVariant, fontSize: 14),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: VelvetNoir.primary,
      foregroundColor: VelvetNoir.surface,
      minimumSize: const Size(88, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      textStyle: _raleway(
        GoogleFonts.raleway(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 0.6,
        ),
      ),
      elevation: 0,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: VelvetNoir.primary,
      foregroundColor: VelvetNoir.surface,
      minimumSize: const Size(88, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      textStyle: _raleway(
        GoogleFonts.raleway(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.6,
        ),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: VelvetNoir.primary,
      side: const BorderSide(color: VelvetNoir.primary, width: 1.5),
      minimumSize: const Size(88, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      textStyle: _raleway(
        GoogleFonts.raleway(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 0.6,
        ),
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: VelvetNoir.primary),
  ),
  listTileTheme: ListTileThemeData(
    iconColor: VelvetNoir.onSurfaceVariant,
    textColor: VelvetNoir.onSurface,
    tileColor: Colors.transparent,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: VelvetNoir.surfaceLow,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: VelvetNoir.surfaceLow,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: VelvetNoir.surfaceHigh,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    titleTextStyle: _playfair(
      GoogleFonts.playfairDisplay(
        color: VelvetNoir.onSurface,
        fontWeight: FontWeight.w700,
        fontSize: 22,
      ),
    ),
    contentTextStyle: _raleway(
      GoogleFonts.raleway(
        color: VelvetNoir.onSurfaceVariant,
        fontSize: 14,
        height: 1.45,
      ),
    ),
  ),
  iconTheme: const IconThemeData(color: VelvetNoir.onSurfaceVariant),
  dividerTheme: const DividerThemeData(
    color: Color(0x1A73757D),
    thickness: 1,
    space: 24,
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: VelvetNoir.surfaceHigh,
    contentTextStyle: _raleway(
      GoogleFonts.raleway(
        color: VelvetNoir.onSurface,
        fontSize: 14,
        height: 1.4,
      ),
    ),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: VelvetNoir.surfaceLow,
    selectedItemColor: VelvetNoir.primary,
    unselectedItemColor: VelvetNoir.onSurfaceVariant,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
);

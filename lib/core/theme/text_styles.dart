import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Mix & Mingle Typography System
/// Modern, bold, and energetic fonts for nightclub aesthetic
class ClubTextStyles {
  // Font families
  static String get displayFont => GoogleFonts.poppins().fontFamily!;
  static String get bodyFont => GoogleFonts.inter().fontFamily!;
  static String get accentFont => GoogleFonts.oswald().fontFamily!;

  static TextTheme get textTheme => ThemeData.dark().textTheme.copyWith(
        // Display - Extra large headers (Hero sections)
        displayLarge: GoogleFonts.poppins(
          fontSize: 57,
          fontWeight: FontWeight.w800,
          color: ClubColors.textPrimary,
          height: 1.2,
          shadows: _neonGlow(ClubColors.primary),
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 45,
          fontWeight: FontWeight.w700,
          color: ClubColors.textPrimary,
          height: 1.2,
          shadows: _neonGlow(ClubColors.primary),
        ),
        displaySmall: GoogleFonts.poppins(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: ClubColors.textPrimary,
          height: 1.2,
          shadows: _neonGlow(ClubColors.secondary),
        ),

        // Headlines - Major sections
        headlineLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: ClubColors.textPrimary,
          height: 1.25,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: ClubColors.textPrimary,
          height: 1.3,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: ClubColors.textPrimary,
          height: 1.3,
        ),

        // Titles - Cards, dialogs, sections
        titleLarge: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ClubColors.textPrimary,
          height: 1.35,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ClubColors.textPrimary,
          height: 1.35,
          letterSpacing: 0.15,
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ClubColors.textPrimary,
          height: 1.4,
          letterSpacing: 0.1,
        ),

        // Body - Primary content text
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: ClubColors.textPrimary,
          height: 1.5,
          letterSpacing: 0.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: ClubColors.textPrimary,
          height: 1.5,
          letterSpacing: 0.25,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: ClubColors.textSecondary,
          height: 1.5,
          letterSpacing: 0.4,
        ),

        // Labels - Buttons, form labels, captions
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ClubColors.textPrimary,
          height: 1.4,
          letterSpacing: 0.1,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ClubColors.textPrimary,
          height: 1.4,
          letterSpacing: 0.5,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ClubColors.textSecondary,
          height: 1.4,
          letterSpacing: 0.5,
        ),
      );

  // Light theme variant (same as dark for club aesthetic)
  static TextTheme get lightTextTheme => textTheme;

  /// Neon glow effect for special text
  static List<Shadow> _neonGlow(Color color, {double intensity = 1.0}) {
    return [
      Shadow(
        color: color.withValues(alpha: 0.8 * intensity),
        blurRadius: 4,
        offset: Offset.zero,
      ),
      Shadow(
        color: color.withValues(alpha: 0.5 * intensity),
        blurRadius: 8,
        offset: Offset.zero,
      ),
      Shadow(
        color: color.withValues(alpha: 0.3 * intensity),
        blurRadius: 16,
        offset: Offset.zero,
      ),
    ];
  }

  /// Special text styles for specific use cases

  // Button text (all caps, bold)
  static TextStyle get buttonText => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: ClubColors.onPrimary,
        letterSpacing: 1.25,
      );

  // Event title (energetic, bold)
  static TextStyle get eventTitle => GoogleFonts.oswald(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: ClubColors.textPrimary,
        letterSpacing: 0.5,
      );

  // Username (medium weight, readable)
  static TextStyle get username => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ClubColors.textPrimary,
      );

  // Timestamp (small, secondary)
  static TextStyle get timestamp => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: ClubColors.textSecondary,
      );

  // Badge text (compact, bold, uppercase)
  static TextStyle get badge => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: ClubColors.onPrimary,
        letterSpacing: 0.5,
      );

  // Neon headline (glowing effect)
  static TextStyle get neonHeadline => GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: ClubColors.primary,
        shadows: _neonGlow(ClubColors.primary, intensity: 1.5),
      );
}

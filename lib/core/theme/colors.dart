import 'package:flutter/material.dart';

/// Mix & Mingle Brand Colors
/// Nightclub/social vibe with vibrant energy
class ClubColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFFFF4C4C); // Vibrant Red (Main brand)
  static const Color primaryDark =
      Color(0xFFCC0000); // Darker red for interactions
  static const Color primaryLight =
      Color(0xFFFF7A7A); // Lighter red for accents

  static const Color secondary = Color(0xFF24E8FF); // Electric Blue (Mingle)
  static const Color secondaryDark = Color(0xFF00B8D4);
  static const Color secondaryLight = Color(0xFF69F0FF);

  static const Color accent = Color(0xFFFFD700); // Golden Yellow (Premium/VIP)
  static const Color accentPurple = Color(0xFFFF2BD7); // Neon Pink/Purple

  // Backgrounds
  static const Color deepNavy = Color(0xFF1E1E2F); // Main background
  static const Color darkBackground = Color(0xFF0B0B12); // Darker areas
  static const Color cardBackground = Color(0xFF2A2A3D); // Card surfaces
  static const Color surface = Color(0xFF1E1E2F);

  // Functional Colors
  static const Color success = Color(0xFF4CAF50); // Green for success states
  static const Color warning = Color(0xFFFFD700); // Yellow for warnings
  static const Color error = Color(0xFFFF4C4C); // Red for errors
  static const Color info = Color(0xFF24E8FF); // Blue for info

  // Text Colors
  static const Color onPrimary = Colors.white;
  static const Color onSurface = Colors.white;
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textHint = Color(0xFF707070);

  // Interactive States
  static const Color hover = Color(0xFF3A3A4D);
  static const Color pressed = Color(0xFF4A4A5D);
  static const Color disabled = Color(0xFF5A5A6D);

  // Gradients
  static const List<Color> primaryGradient = [
    Color(0xFFFF4C4C),
    Color(0xFFFF2BD7),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFF24E8FF),
    Color(0xFF7B2BFF),
  ];

  static const List<Color> premiumGradient = [
    Color(0xFFFFD700),
    Color(0xFFFF7A3C),
  ];

  // Legacy aliases (for backward compatibility)
  static const Color glowingRed = primary;
  static const Color goldenYellow = accent;
  static const Color mixOrange = Color(0xFFFF7A3C);
  static const Color mingleBlue = secondary;
  static const Color purpleAccent = accentPurple;
}

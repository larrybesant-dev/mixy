// Removed invalid library directive and broken imports
// import 'dart:js_util' as js_util;
// import 'package:mixvy/helpers/helpers.dart';
/// DESIGN SYSTEM CONSTANTS
///
/// Hard-coded enforcement of DESIGN_BIBLE.md
/// All UI/UX decisions must reference and use these constants.
///
/// Reference: DESIGN_BIBLE.md Section A, B, C, D
/// Last Updated: February 2026
/// Theme: Dark DJ Streaming Vibe - Navy/Orange/Blue neon aesthetic
library;

// Removed invalid library directive

import 'package:flutter/material.dart';

// ==============================================================================
// A. COLOR PALETTE (DESIGN_BIBLE.md Section A)
// ==============================================================================

class DesignColors {
  // Primary accent - BRIGHT BLUE (MINGLE color) - neon blue
  static const Color accent = Color(0xFF4A90FF); // Brighter blue
  static const Color accentLight = Color(0xFF6BA8FF);
  static const Color accentDark = Color(0xFF2563EB);

  // Secondary accent - ORANGE/CORAL (MIX color) - warm orange-red
  static const Color secondary = Color(0xFFFF6B35); // Coral orange
  static const Color secondaryLight = Color(0xFFFF8A5C);
  static const Color secondaryDark = Color(0xFFE85A2A);

  // Tertiary accent - PURPLE (for gradients and accents)
  static const Color tertiary = Color(0xFF8B5CF6);
  static const Color tertiaryLight = Color(0xFFA78BFA);
  static const Color tertiaryDark = Color(0xFF7C3AED);

  // Accent opacity variants (based on blue accent 0xFF4A90FF)
  static const Color accent5 = Color(0x0D4A90FF);
  static const Color accent10 = Color(0x194A90FF);
  static const Color accent15 = Color(0x264A90FF);
  static const Color accent20 = Color(0x334A90FF);
  static const Color accent30 = Color(0x4D4A90FF);
  static const Color accent40 = Color(0x664A90FF);
  static const Color accent50 = Color(0x804A90FF);
  static const Color accent60 = Color(0x994A90FF);
  static const Color accent90 = Color(0xE64A90FF);
  static const Color accent2 = Color(0x054A90FF);
  static const Color accent12 = Color(0x1F4A90FF);
  static const Color accent24 = Color(0x3D4A90FF);
  static const Color accent26 = Color(0x424A90FF);
  static const Color accent70 = Color(0xB24A90FF);

  // Neutral palette
  static const Color white = Color(0xFFFFFFFF);

  // Dark navy background palette (DJ streaming vibe)
  static const Color background = Color(0xFF080C14); // Deep navy black
  static const Color surfaceLight = Color(0xFF1A1F2E); // Lighter navy
  static const Color surfaceDefault = Color(0xFF0D1117); // Default dark navy
  static const Color surfaceAlt = Color(0xFF151A26); // Alt navy surface
  static const Color surfaceDark = Color(0xFF060A10); // Darkest navy
  static const Color divider = Color(0xFF2D3748); // Subtle navy divider
  static const Color textGray = Color(0xFF9CA3AF); // Muted gray
  static const Color textLightGray = Color(0xFFD1D5DB); // Light gray
  static const Color textDark = Color(0xFF1F2937);

  // Status colors
  static const Color roomEnergyCalm = Color(0xFF4A90FF); // Blue
  static const Color roomEnergyActive = Color(0xFFFF6B35); // Orange
  static const Color roomEnergyBuzzing = Color(0xFFEF4444); // Red

  // Semantic colors
  static const Color success = Color(0xFF22C55E); // Bright green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red (not accent!)

  // Transparency
  static const Color overlay = Color(0x99080C14); // Navy overlay
  static const Color shadowColor = Color(0x40000000);

  // Text colors
  static const Color textPrimary = white;
  static const Color textSecondary = textGray;
  static const Color surface = surfaceDefault;

  // Dialog/card backgrounds (with purple tint for that DJ vibe)
  static const Color dialogBackground = Color(0xFF1A1A2E);
  static const Color cardBackground = Color(0xFF16162A);

  // Gold (for favorites, premium features)
  static const Color gold = Color(0xFFFFD700);
  static const Color goldLight = Color(0xFFFFE680);
  static const Color goldDark = Color(0xFFCCA300);

  // Neon glow effects
  static const List<Shadow> primaryGlow = [
    Shadow(color: Color(0xFF4A90FF), blurRadius: 20, offset: Offset(0, 0)),
    Shadow(color: Color(0xFF4A90FF), blurRadius: 40, offset: Offset(0, 0)),
  ];

  static const List<Shadow> secondaryGlow = [
    Shadow(color: Color(0xFFFF6B35), blurRadius: 20, offset: Offset(0, 0)),
    Shadow(color: Color(0xFFFF6B35), blurRadius: 40, offset: Offset(0, 0)),
  ];

  // New: Purple glow for special elements
  static const List<Shadow> tertiaryGlow = [
    Shadow(color: Color(0xFF8B5CF6), blurRadius: 20, offset: Offset(0, 0)),
    Shadow(color: Color(0xFF8B5CF6), blurRadius: 40, offset: Offset(0, 0)),
  ];
}

// ==============================================================================
// B. TYPOGRAPHY (DESIGN_BIBLE.md Section B)
// ==============================================================================

class DesignTypography {
  // Display / Page Title — page headers, splash, profile name
  static const TextStyle display = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    color: DesignColors.white,
    height: 1.1,
    shadows: DesignColors.primaryGlow,
  );

  // Display large (32 px)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: DesignColors.white,
    height: 1.1,
  );

  // Section Title (20–22 px, SemiBold) — "About", "Rooms", "Vibes"
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: DesignColors.white,
    height: 1.3,
    letterSpacing: 0.2,
  );

  // Heading - Room name, prominent text
  static const TextStyle heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: DesignColors.white,
    height: 1.25,
  );

  // Subheading - Participant name, secondary content
  static const TextStyle subheading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: DesignColors.white,
    height: 1.3,
  );

  // Body - Standard text (14–16 px, Regular)
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: DesignColors.white,
    height: 1.5,
    letterSpacing: 0.15,
  );

  // Body small
  static const TextStyle bodySm = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: DesignColors.textGray,
    height: 1.4,
    letterSpacing: 0.25,
  );

  // Caption - Helper text, timestamps (12–13 px, Medium weight)
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: DesignColors.textGray,
    height: 1.3,
    letterSpacing: 0.4,
  );

  // Label - Button text, badges
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: DesignColors.white,
    height: 1.2,
  );

  // Button - Control text
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: DesignColors.white,
    height: 1.2,
    letterSpacing: 0.3,
  );
}

// ==============================================================================
// C. SPACING & LAYOUT (DESIGN_BIBLE.md Section B)
// ==============================================================================

class DesignSpacing {
  // ── Core tokens (Layout Guide §1) ──────────────────────────────────────
  /// 4 px — tiny gaps, icon padding
  static const double xs = 4;
  static const double spaceXS = 4;

  /// 8 px — small gaps, label spacing
  static const double sm = 8;
  static const double spaceSM = 8;

  /// 12 px — standard padding inside cards
  static const double md = 12;
  static const double spaceMD = 12;

  /// 16 px — default page padding
  static const double lg = 16;
  static const double spaceLG = 16;

  /// 24 px — section spacing
  static const double xl = 24;
  static const double spaceXL = 24;

  /// 32 px — large headers, top spacing
  static const double xxl = 32;
  static const double spaceXXL = 32;

  // ── Card spacing ────────────────────────────────────────────────────────
  static const double cardPadding = lg; // 16 px inside cards
  static const double cardSpacing = lg; // 16 px between cards
  static const double cardBorderRadius = 18.0; // 16–20 px range

  // ── Button sizing (Layout Guide §3) ─────────────────────────────────────
  static const double buttonMinHeight = 52; // 48–56 px
  static const double buttonMinWidth = 120;
  static const double buttonPadding = lg;
  static const double buttonBorderRadius = 14.0; // 12–16 px range

  // ── Input sizing ────────────────────────────────────────────────────────
  static const double inputHeight = 48;
  static const double inputPadding = md; // 12 px
  static const double inputBorderRadius = 12.0;

  // ── Avatar sizes (radii) ─────────────────────────────────────────────────
  /// Profile hero — 108 px diameter, radius 54
  static const double avatarHeroRadius = 54;
  static const double avatarLarge = 32; // 64 px diameter
  static const double avatarMedium = 24; // 48 px diameter
  static const double avatarSmall = 20; // 40 px diameter

  // ── Page structure ────────────────────────────────────────────────────────
  static const double headerHeight = 64; // 56–72 px
  static const double headerHeightLg = 72;

  // ── Control bar (rooms) ──────────────────────────────────────────────────
  static const double controlBarHeight = 72; // Layout Guide §6
  static const double controlSpacing = lg;
}

// ==============================================================================
// D. ANIMATION DURATIONS (DESIGN_BIBLE.md Section C)
// ==============================================================================

class DesignAnimations {
  // Join flow timing (CRITICAL - non-negotiable)
  // Stage 1: "Entering roomâ€¦"
  static const Duration joinStage1Duration = Duration(milliseconds: 150);

  // Stage 2: "Connecting audio & videoâ€¦" (variable, but user sees spinner after 150ms)
  static const Duration joinStage2MinDuration = Duration(milliseconds: 400);
  static const Duration joinStage2MaxDuration = Duration(milliseconds: 1000);

  // Stage 3: "You're live" (fade in + notification)
  static const Duration joinStage3Duration = Duration(milliseconds: 400);

  // Total minimum join time
  static const Duration joinTotalMinimum = Duration(milliseconds: 700);

  // Presence animations
  static const Duration presenceSlideInDuration = Duration(milliseconds: 250);
  static const Duration presenceFadeOutDuration = Duration(milliseconds: 200);
  static const Duration presenceSlideDownDuration = Duration(milliseconds: 200);

  // Speaking pulse
  static const Duration speakingPulseDuration = Duration(milliseconds: 200);
  static const Duration speakingPulseRepeatDelay = Duration(milliseconds: 300);

  // Button feedback
  static const Duration buttonFeedbackDuration = Duration(milliseconds: 100);
  static const Duration buttonPressDuration = Duration(milliseconds: 100);

  // Micro interactions
  static const Duration cardHoverDuration = Duration(milliseconds: 150);
  static const Duration notificationFadeInDuration =
      Duration(milliseconds: 150);
  static const Duration notificationVisibleDuration = Duration(seconds: 3);
  static const Duration notificationFadeOutDuration =
      Duration(milliseconds: 200);

  // Curves (DESIGN_BIBLE.md specifies easeOutCubic, easeInOut, easeInCubic)
  static const Curve easeOutCubic = Cubic(0.215, 0.61, 0.355, 1.0);
  static const Curve easeInCubic = Cubic(0.55, 0.055, 0.675, 0.19);
  static const Curve easeInOut = Cubic(0.42, 0.0, 0.58, 1.0);
}

// ==============================================================================
// E. SHADOWS & ELEVATION (DESIGN_BIBLE.md Section B - Avoid Material defaults)
// ==============================================================================

class DesignShadows {
  // Subtle elevation (cards, buttons)
  static const BoxShadow subtle = BoxShadow(
    color: DesignColors.accent,
    blurRadius: 4,
    offset: Offset(0, 2),
  );

  // Medium elevation (hovered cards)
  static const BoxShadow medium = BoxShadow(
    color: DesignColors.accent,
    blurRadius: 8,
    offset: Offset(0, 4),
  );

  // Speaking glow (when someone is talking)
  static const BoxShadow speakingGlow = BoxShadow(
    color: Color.fromARGB(200, 255, 76, 76), // Accent with 80% opacity
    blurRadius: 12,
    spreadRadius: 0,
  );

  // Error state
  static const BoxShadow error = BoxShadow(
    color: Color.fromARGB(150, 255, 76, 76), // Accent with 60% opacity
    blurRadius: 6,
    offset: Offset(0, 2),
  );
}

// ==============================================================================
// F. BORDERS (DESIGN_BIBLE.md - No Material defaults)
// ==============================================================================

class DesignBorders {
  // Card default
  static const Border cardDefault = Border(
    left: BorderSide(
      color: DesignColors.accent,
      width: 3,
    ),
    top: BorderSide(color: DesignColors.accent, width: 1),
    right: BorderSide(color: DesignColors.accent, width: 1),
    bottom: BorderSide(color: DesignColors.accent, width: 1),
  );

  // Card hover
  static const Border cardHovered = Border(
    left: BorderSide(
      color: DesignColors.accent,
      width: 3,
    ),
    top: BorderSide(color: DesignColors.accent, width: 1),
    right: BorderSide(color: DesignColors.accent, width: 1),
    bottom: BorderSide(color: DesignColors.accent, width: 1),
  );

  // Input field (muted)
  static const Border inputDefault = Border(
    bottom: BorderSide(
      color: DesignColors.accent,
      width: 1,
    ),
  );

  // Input focused
  static const Border inputFocused = Border(
    bottom: BorderSide(
      color: DesignColors.accent,
      width: 2,
    ),
  );
}

// ==============================================================================
// G. ROOM ENERGY THRESHOLDS (DESIGN_BIBLE.md Section D)
// ==============================================================================

class RoomEnergyThresholds {
  // Energy is calculated from: (messageRate + participantBonus + audioBonus)
  // messageRate = messages in last 30s / 30
  // participantBonus = present count * 0.1
  // audioBonus = activeSpeakers > 0 ? 0.5 : 0

  static const double calmBelow = 0.5;
  static const double activeBelow = 2.0;
  static const double buzzingAbove = 2.0;

  static Color getEnergyColor(double energy) {
    if (energy < calmBelow) return DesignColors.accent;
    if (energy < activeBelow) return DesignColors.accent;
    return DesignColors.accent;
  }

  static String getEnergyLabel(double energy) {
    if (energy < calmBelow) return 'Calm';
    if (energy < activeBelow) return 'Active';
    return 'Buzzing';
  }
}

// ==============================================================================
// H. JOIN PHASE ENUM & TIMINGS (DESIGN_BIBLE.md Section 2.C)
// ==============================================================================

enum JoinPhase {
  initial, // Before join is clicked
  entering, // Stage 1: "Entering roomâ€¦" (150ms)
  connecting, // Stage 2: "Connecting audioâ€¦" (400â€“1000ms)
  live, // Stage 3: "You're live" (400ms fade-in)
  error, // Join failed
  left, // User left room
}

extension JoinPhaseExtension on JoinPhase {
  String get displayText {
    switch (this) {
      case JoinPhase.initial:
        return 'Ready to join';
      case JoinPhase.entering:
        return 'Entering roomâ€¦';
      case JoinPhase.connecting:
        return 'Connecting audio & videoâ€¦';
      case JoinPhase.live:
        return 'You\'re live';
      case JoinPhase.error:
        return 'Something went wrong';
      case JoinPhase.left:
        return 'You left the room';
    }
  }

  Duration get expectedDuration {
    switch (this) {
      case JoinPhase.entering:
        return DesignAnimations.joinStage1Duration;
      case JoinPhase.connecting:
        return DesignAnimations.joinStage2MinDuration;
      case JoinPhase.live:
        return DesignAnimations.joinStage3Duration;
      default:
        return Duration.zero;
    }
  }
}

// ==============================================================================
// I. NOTIFICATION TYPES (DESIGN_BIBLE.md Section D - Social Proof)
// ==============================================================================

enum NotificationType {
  userArrived, // "Emma just joined"
  userLeft, // "Emma left the room"
  userSpeaking, // "Emma is speakingâ€¦"
  youAreLive, // "You're live with 5 others"
  error, // Error message
}

extension NotificationTypeExtension on NotificationType {
  Duration get visibleDuration {
    switch (this) {
      case NotificationType.userArrived:
      case NotificationType.userLeft:
        return const Duration(seconds: 3);
      case NotificationType.youAreLive:
        return const Duration(seconds: 2);
      case NotificationType.error:
        return const Duration(seconds: 4);
      default:
        return const Duration(seconds: 3);
    }
  }

  Color get backgroundColor {
    switch (this) {
      case NotificationType.error:
        return DesignColors.accent;
      default:
        return DesignColors.accent;
    }
  }
}

// ==============================================================================
// ENFORCEMENT NOTE
// ==============================================================================
//
// ALL Flutter widgets must import and use these constants.
// Deviations require documented approval with reference to DESIGN_BIBLE.md.
//
// Example:
//   âœ… Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(DesignSpacing.cardBorderRadius),
//         color: DesignColors.accent,
//         boxShadow: [DesignShadows.subtle],
//       ),
//     )
//
//   âŒ Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(8),
//         color: DesignColors.accent,
//         boxShadow: [BoxShadow(...)],  // Magic number
//       ),
//     )
//
// THIS IS BINDING. Questions? Reference DESIGN_BIBLE.md.

// ==============================================================================
// BACKWARD COMPATIBILITY - DesignConstants alias
// ==============================================================================

/// Legacy DesignConstants class for backward compatibility
/// Use DesignColors, DesignSpacing, etc. directly in new code
class DesignConstants {
  static const Color accentPurple = DesignColors.tertiary;
  static const Color accent = DesignColors.accent;
  static const Color primary = DesignColors.accent;
  static const Color secondary = DesignColors.secondary;
  static const double padding = DesignSpacing.lg;
  static const double radius = DesignSpacing.cardBorderRadius;
}

// (flutter/material.dart imported at top of file)


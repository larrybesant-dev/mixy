// lib/core/design_system/app_layout.dart
//
// ══════════════════════════════════════════════════════════════════════════════
//  MIX & MINGLE — FULL LAYOUT & SPACING GUIDE
//  Single source of truth for spacing, typography, component sizing,
//  responsive rules, and page structure.
//
//  Token names match the founder-grade spec exactly:
//    spaceXS / spaceSM / spaceMD / spaceLG / spaceXL / spaceXXL
//
//  Import this file in any Flutter widget:
//    import 'package:mixvy/core/design_system/app_layout.dart';
// ══════════════════════════════════════════════════════════════════════════════

library;

import 'package:flutter/material.dart';
import 'design_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. GLOBAL SPACING SYSTEM
//    Never use arbitrary numbers. Every spacing value must come from here.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppSpacing {
  /// 4 px — tiny gaps, icon padding
  static const double spaceXS = 4;

  /// 8 px — small gaps, label spacing
  static const double spaceSM = 8;

  /// 12 px — standard padding inside cards
  static const double spaceMD = 12;

  /// 16 px — default page padding
  static const double spaceLG = 16;

  /// 24 px — section spacing
  static const double spaceXL = 24;

  /// 32 px — large headers, top spacing
  static const double spaceXXL = 32;

  // ── Convenience EdgeInsets ──────────────────────────────────────────────
  static const EdgeInsets paddingXS = EdgeInsets.all(spaceXS);
  static const EdgeInsets paddingSM = EdgeInsets.all(spaceSM);
  static const EdgeInsets paddingMD = EdgeInsets.all(spaceMD);
  static const EdgeInsets paddingLG = EdgeInsets.all(spaceLG);
  static const EdgeInsets paddingXL = EdgeInsets.all(spaceXL);
  static const EdgeInsets paddingXXL = EdgeInsets.all(spaceXXL);

  /// Standard horizontal page gutter (spaceLG on each side)
  static const EdgeInsets pagePaddingH =
      EdgeInsets.symmetric(horizontal: spaceLG);

  /// Full page padding — horizontal spaceLG, vertical spaceXL
  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: spaceLG, vertical: spaceXL);

  /// Chip horizontal padding (spaceSM each side) + vertical spaceXS
  static const EdgeInsets chipPadding =
      EdgeInsets.symmetric(horizontal: spaceSM, vertical: spaceXS);
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. GLOBAL TYPOGRAPHY SYSTEM
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppTypography {
  // Display / Page Title
  // Use on: page headers, splash, profile name
  static const TextStyle display = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    color: DesignColors.white,
    height: 1.1,
    shadows: DesignColors.primaryGlow,
  );

  /// Smaller variant (28 px)
  static const TextStyle displaySm = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: DesignColors.white,
    height: 1.15,
  );

  // Section Title
  // Use on: "About", "Photos", "Rooms", "Vibes"
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: DesignColors.white,
    height: 1.3,
    letterSpacing: 0.2,
  );

  static const TextStyle sectionTitleLg = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: DesignColors.white,
    height: 1.3,
  );

  // Body Text
  // Use on: descriptions, bios, labels
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: DesignColors.white,
    height: 1.5,
    letterSpacing: 0.15,
  );

  static const TextStyle bodySm = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: DesignColors.textGray,
    height: 1.4,
    letterSpacing: 0.25,
  );

  // Caption
  // Use on: timestamps, small labels
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: DesignColors.textGray,
    height: 1.3,
    letterSpacing: 0.4,
  );

  static const TextStyle captionSm = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: DesignColors.textGray,
    height: 1.2,
    letterSpacing: 0.2,
  );

  // Button label
  static const TextStyle buttonLabel = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: DesignColors.white,
    letterSpacing: 0.5,
    height: 1.2,
  );

  // Vibe chip label
  static const TextStyle chipLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: DesignColors.white,
    letterSpacing: 0.3,
  );

  // App bar / nav label
  static const TextStyle navLabel = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  // Greeting sub-line (muted)
  static const TextStyle greeting = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: DesignColors.textGray,
    height: 1.3,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. GLOBAL COMPONENT SIZING
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppSizes {
  // ── Buttons ───────────────────────────────────────────────────────────────
  static const double buttonHeight = 52; // 48–56 px
  static const double buttonHeightSm = 44;
  static const double buttonBorderRadius = 14; // 12–16
  static const double buttonPaddingH = AppSpacing.spaceLG;

  // ── Cards ─────────────────────────────────────────────────────────────────
  static const double cardPadding = AppSpacing.spaceLG; // 16
  static const double cardBorderRadius = 18; // 16–20
  static const double cardSpacing = AppSpacing.spaceLG; // between cards

  // ── Inputs ────────────────────────────────────────────────────────────────
  static const double inputHeight = 48;
  static const double inputPadding = AppSpacing.spaceMD; // 12
  static const double inputBorderRadius = 12;

  // ── Icons ─────────────────────────────────────────────────────────────────
  static const double iconStandard = 24;
  static const double iconLarge = 28;
  static const double iconXl = 32;
  static const double iconNav = 22; // slightly smaller in nav bar

  // ── Avatars ───────────────────────────────────────────────────────────────
  /// Profile hero avatar diameter: 108 px (mid of 96–120 range)
  static const double avatarHero = 108;
  static const double avatarLg = 64;
  static const double avatarMd = 48;
  static const double avatarSm = 40;
  static const double avatarXs = 32;

  // Radius shortcuts (diameter / 2)
  static const double avatarHeroRadius = avatarHero / 2; // 54
  static const double avatarLgRadius = avatarLg / 2; // 32
  static const double avatarMdRadius = avatarMd / 2; // 24
  static const double avatarSmRadius = avatarSm / 2; // 20

  // ── Chips ─────────────────────────────────────────────────────────────────
  static const double chipHeight = 34; // 32–36 px
  static const double chipBorderRadius = 17;

  // ── Page structure ────────────────────────────────────────────────────────
  static const double headerHeight = 64; // 56–72 px
  static const double headerHeightLg = 72;
  static const double controlBarHeight = 72; // room controls
  static const double bottomNavHeight = 64; // bottom navigation bar
  static const double bottomNavHeightCompact = 56;

  // ── Neon ring / glow ──────────────────────────────────────────────────────
  static const double neonRingWidth = 3;
  static const double speakingGlowWidth = 3.5;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. PAGE STRUCTURE HELPERS
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppLayout {
  /// Standard screen-edge horizontal padding
  static const double pagePaddingH = AppSpacing.spaceLG;

  /// Standard vertical gap between major page sections
  static const double sectionGap = AppSpacing.spaceXL;

  // ── Responsive breakpoints ────────────────────────────────────────────────
  static const double breakpointMobile = 480;
  static const double breakpointTablet = 768;
  static const double breakpointDesktop = 1024;
  static const double breakpointLargeDesktop = 1440;

  /// True when [width] is a mobile screen (<= 480)
  static bool isMobile(double width) => width <= breakpointMobile;

  /// True when [width] is a tablet screen
  static bool isTablet(double width) =>
      width > breakpointMobile && width <= breakpointDesktop;

  /// True when [width] is a desktop screen
  static bool isDesktop(double width) => width > breakpointDesktop;

  /// Returns responsive horizontal padding:
  ///   • mobile  → spaceLG (16)
  ///   • tablet  → spaceXL (24)
  ///   • desktop → spaceXXL (32)
  static double responsivePaddingH(double screenWidth) {
    if (isDesktop(screenWidth)) return AppSpacing.spaceXXL;
    if (isTablet(screenWidth)) return AppSpacing.spaceXL;
    return AppSpacing.spaceLG;
  }

  /// Returns responsive card grid column count:
  ///   • mobile  → 1
  ///   • tablet  → 2
  ///   • desktop → 3
  static int responsiveColumns(double screenWidth) {
    if (isDesktop(screenWidth)) return 3;
    if (isTablet(screenWidth)) return 2;
    return 1;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. REUSABLE LAYOUT WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps content in the standard page scaffold with SafeArea and
/// consistent horizontal / vertical padding.
///
/// ```dart
/// AppPageWrapper(
///   child: Column(children: [...]),
/// )
/// ```
class AppPageWrapper extends StatelessWidget {
  const AppPageWrapper({
    super.key,
    required this.child,
    this.scrollable = true,
    this.paddingH = AppSpacing.spaceLG,
    this.paddingV = AppSpacing.spaceXL,
  });

  final Widget child;
  final bool scrollable;
  final double paddingH;
  final double paddingV;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
      child: child,
    );
    return SafeArea(
      child: scrollable ? SingleChildScrollView(child: content) : content,
    );
  }
}

/// Section heading row with optional trailing widget.
///
/// ```dart
/// AppSectionHeader(title: 'Active Rooms', trailing: TextButton(...))
/// ```
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceLG,
        vertical: AppSpacing.spaceSM,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTypography.sectionTitle),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Vertical gap equal to [AppSpacing.spaceXL] — use between page sections.
class AppSectionGap extends StatelessWidget {
  const AppSectionGap({super.key});
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: AppSpacing.spaceXL);
}

/// Vibe chip — standard 32–36 px height pill with neon border.
class AppVibeChip extends StatelessWidget {
  const AppVibeChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: AppSizes.chipHeight,
        padding: AppSpacing.chipPadding,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.25)
              : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSizes.chipBorderRadius),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.8 : 0.45),
            width: 1.2,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: AppSpacing.spaceXS),
            ],
            Text(label, style: AppTypography.chipLabel.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

/// Standard neon-outlined card with consistent padding and border radius.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.glowColor,
    this.backgroundColor,
    this.onTap,
    this.elevation = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? glowColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool elevation;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? DesignColors.surfaceLight;
    final radius = borderRadius ?? AppSizes.cardBorderRadius;
    final glow = glowColor ?? DesignColors.accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(AppSizes.cardPadding),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: glow.withValues(alpha: 0.2), width: 1),
          boxShadow: elevation
              ? [
                  BoxShadow(
                      color: glow.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

/// Full-width primary action button, 48–56 px height, 12–16 border radius.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.icon,
    this.loading = false,
    this.height = AppSizes.buttonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? DesignColors.accent;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: DesignColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonBorderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLG),
          elevation: 0,
        ).copyWith(
          overlayColor: WidgetStateProperty.all(
              DesignColors.white.withValues(alpha: 0.12)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppSizes.iconStandard),
                    const SizedBox(width: AppSpacing.spaceSM),
                  ],
                  Text(label, style: AppTypography.buttonLabel),
                ],
              ),
      ),
    );
  }
}

/// Neon-bordered avatar with optional glow ring.
/// Sizes use [AppSizes.avatarHero] / [AppSizes.avatarLg] etc.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.radius = AppSizes.avatarMdRadius,
    this.glowColor,
    this.ringWidth = AppSizes.neonRingWidth,
    this.speaking = false,
    this.fallbackIcon = Icons.person,
  });

  final String? imageUrl;
  final double radius;
  final Color? glowColor;
  final double ringWidth;
  final bool speaking;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final glow = glowColor ?? DesignColors.accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: glow,
            width: speaking ? AppSizes.speakingGlowWidth : ringWidth),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: speaking ? 0.7 : 0.4),
            blurRadius: speaking ? 20 : 12,
            spreadRadius: speaking ? 2 : 0,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: DesignColors.surfaceLight,
        backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
            ? NetworkImage(imageUrl!)
            : null,
        child: imageUrl == null || imageUrl!.isEmpty
            ? Icon(fallbackIcon,
                size: radius * 0.65, color: DesignColors.textGray)
            : null,
      ),
    );
  }
}


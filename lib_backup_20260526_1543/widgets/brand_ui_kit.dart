// MIXVY Brand UI Kit
// Reusable components aligned to the locked brand system:
//   Jet Black (#0B0B0B) · Gold (#D4AF37) · Wine Red (#781E2B) · Soft Cream (#F7EDE2)
//   Headlines: Playfair Display · Body/UI: Raleway

// ignore_for_file: use_null_aware_elements

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/utils/network_image_url.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MixvyGoldButton — primary gold solid button (Sign In, CTA)
// ─────────────────────────────────────────────────────────────────────────────

class MixvyGoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final double? width;

  const MixvyGoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.height = 52,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: onPressed == null || loading
                  ? null
                  : const LinearGradient(
                      colors: [VelvetNoir.primary, VelvetNoir.primaryDim],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              color: (onPressed == null || loading)
                  ? VelvetNoir.surfaceHigh
                  : null,
              borderRadius: BorderRadius.circular(999),
              boxShadow: (onPressed == null || loading)
                  ? null
                  : [
                      BoxShadow(
                        color: VelvetNoir.primary.withAlpha(55),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: (loading || onPressed == null)
                  ? null
                  : () {
                      unawaited(HapticFeedback.lightImpact());
                      onPressed!();
                    },
              borderRadius: BorderRadius.circular(999),
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: VelvetNoir.surface,
                        ),
                      )
                    : Text(
                        label.toUpperCase(),
                        style: GoogleFonts.raleway(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: VelvetNoir.surface,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MixvyGoldOutlineButton — gold outline button (Sign Up, secondary CTA)
// ─────────────────────────────────────────────────────────────────────────────

class MixvyGoldOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double? width;

  const MixvyGoldOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 52,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: OutlinedButton(
        onPressed: onPressed == null
            ? null
            : () {
                unawaited(HapticFeedback.lightImpact());
                onPressed!();
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: VelvetNoir.primary,
          side: const BorderSide(color: VelvetNoir.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          backgroundColor: Colors.transparent,
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.raleway(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: VelvetNoir.primary,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MixvyLiveBadge — wine red LIVE indicator with pulsing dot
// ─────────────────────────────────────────────────────────────────────────────

class MixvyLiveBadge extends StatefulWidget {
  final String label;
  const MixvyLiveBadge({super.key, this.label = 'LIVE'});

  @override
  State<MixvyLiveBadge> createState() => _MixvyLiveBadgeState();
}

class _MixvyLiveBadgeState extends State<MixvyLiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final opacity = 0.6 + (Curves.easeInOut.transform(_pulse.value) * 0.4);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: VelvetNoir.secondary.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: VelvetNoir.liveGlow.withValues(alpha: 0.4 * opacity),
                blurRadius: 10 * _pulse.value,
                spreadRadius: 1 * _pulse.value,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: GoogleFonts.raleway(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MixvyVipBadge — gold VIP crown badge for premium users
// ─────────────────────────────────────────────────────────────────────────────

class MixvyVipBadge extends StatelessWidget {
  const MixvyVipBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [VelvetNoir.primary, VelvetNoir.primaryDim],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: VelvetNoir.primary.withAlpha(60), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            size: 11,
            color: VelvetNoir.surface,
          ),
          const SizedBox(width: 3),
          Text(
            'VIP',
            style: GoogleFonts.raleway(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: VelvetNoir.surface,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MixvyOnlineIndicator — gold dot for online status
// ─────────────────────────────────────────────────────────────────────────────

class MixvyOnlineIndicator extends StatelessWidget {
  final bool isOnline;
  const MixvyOnlineIndicator({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (!isOnline) return const SizedBox.shrink();
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: VelvetNoir.primary,
        shape: BoxShape.circle,
        border: Border.all(color: VelvetNoir.surface, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: VelvetNoir.primary.withAlpha(80),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MixvyGoldAvatar — circular avatar with gold gradient ring
// ─────────────────────────────────────────────────────────────────────────────

class MixvyGoldAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackInitial;
  final double radius;
  final bool isVip;
  final bool isOnline;

  const MixvyGoldAvatar({
    super.key,
    this.imageUrl,
    required this.fallbackInitial,
    this.radius = 28,
    this.isVip = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final safeImageUrl = sanitizeNetworkImageUrl(imageUrl);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: radius * 2 + 4,
          height: radius * 2 + 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isVip
                ? VelvetNoir.primaryGradient
                : const LinearGradient(
                    colors: [Color(0x60D4AF37), Color(0x30D4AF37)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          padding: const EdgeInsets.all(2),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: VelvetNoir.surfaceHigh,
            backgroundImage:
                safeImageUrl != null ? NetworkImage(safeImageUrl) : null,
            child: safeImageUrl == null
                ? Text(
                    fallbackInitial.isNotEmpty
                        ? fallbackInitial[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.playfairDisplay(
                      color: VelvetNoir.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: radius * 0.7,
                    ),
                  )
                : null,
          ),
        ),
        if (isOnline)
          Positioned(
            bottom: 2,
            right: 2,
            child: MixvyOnlineIndicator(isOnline: isOnline),
          ),
        if (isVip) Positioned(top: -4, right: -4, child: const MixvyVipBadge()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MixvySectionHeader — branded Playfair Display section headers
// ─────────────────────────────────────────────────────────────────────────────

class MixvySectionHeader extends StatelessWidget {
  final String title;
  final Color accentColor;
  final Widget? trailing;
  final EdgeInsets padding;

  const MixvySectionHeader({
    super.key,
    required this.title,
    this.accentColor = VelvetNoir.primary,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: VelvetNoir.onSurface,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MixvyMonogram — the M circle mark (inline / compact)
// ─────────────────────────────────────────────────────────────────────────────

class MixvyMonogram extends StatelessWidget {
  final double size;
  final bool glow;

  const MixvyMonogram({super.key, this.size = 56, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final Widget circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: VelvetNoir.primary, width: size * 0.026),
        color: VelvetNoir.primary.withAlpha(12),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: VelvetNoir.primary.withAlpha(70),
                  blurRadius: size * 0.7,
                  spreadRadius: size * 0.07,
                ),
                BoxShadow(
                  color: VelvetNoir.secondary.withAlpha(50),
                  blurRadius: size * 1.2,
                  spreadRadius: size * 0.14,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          'M',
          style: GoogleFonts.playfairDisplay(
            fontSize: size * 0.65,
            fontWeight: FontWeight.w700,
            color: VelvetNoir.primary,
            height: 1.0,
          ),
        ),
      ),
    );
    return circle;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MixvyLogoFull — stacked monogram + wordmark + tagline (splash / auth pages)
// ─────────────────────────────────────────────────────────────────────────────

class MixvyLogoFull extends StatelessWidget {
  final double size;

  /// [size] scales the full branded logo asset consistently across auth pages.
  const MixvyLogoFull({super.key, this.size = 88});

  @override
  Widget build(BuildContext context) {
    final double logoWidth = size * 3.2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/branding/mixvy_logo.png',
          width: logoWidth,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 8),
        Text(
          'Luxury live connection',
          style: GoogleFonts.raleway(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: VelvetNoir.onSurfaceVariant,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MixvyAppBarLogo — compact wordmark for AppBar / top nav
// ─────────────────────────────────────────────────────────────────────────────

class MixvyAppBarLogo extends StatelessWidget {
  final double fontSize;

  const MixvyAppBarLogo({super.key, this.fontSize = 22});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(fontSize * 0.22),
          child: Image.asset(
            'assets/images/branding/mixvy_logo.png',
            height: fontSize * 1.55,
            width: fontSize * 1.55,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(width: fontSize * 0.35),
        Text(
          'MIXVY',
          style: GoogleFonts.playfairDisplay(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: VelvetNoir.primary,
            letterSpacing: fontSize * 0.10,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MixvyRoomCard — dark premium card for live rooms
// ─────────────────────────────────────────────────────────────────────────────

class MixvyRoomCard extends StatelessWidget {
  final String title;
  final String hostName;
  final int participantCount;
  final bool isLive;
  final VoidCallback onTap;
  final String? coverImageUrl;

  const MixvyRoomCard({
    super.key,
    required this.title,
    required this.hostName,
    required this.participantCount,
    required this.isLive,
    required this.onTap,
    this.coverImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLive
                ? VelvetNoir.liveGlow.withAlpha(80)
                : VelvetNoir.primary.withAlpha(25),
            width: isLive ? 1.5 : 1,
          ),
          boxShadow: isLive
              ? [
                  BoxShadow(
                    color: VelvetNoir.liveGlow.withAlpha(50),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image area
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: VelvetNoir.surfaceContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                image: (coverImageUrl ?? '').isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(coverImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (isLive)
                    Positioned(top: 8, left: 8, child: MixvyLiveBadge()),
                  // Gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            VelvetNoir.surfaceHigh.withAlpha(200),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Room info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: VelvetNoir.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 12,
                        color: VelvetNoir.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hostName,
                        style: GoogleFonts.raleway(
                          fontSize: 11,
                          color: VelvetNoir.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.people_outline_rounded,
                        size: 11,
                        color: VelvetNoir.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$participantCount',
                        style: GoogleFonts.raleway(
                          fontSize: 11,
                          color: VelvetNoir.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

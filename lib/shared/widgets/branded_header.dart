import 'package:flutter/material.dart';
import '../../core/theme/neon_colors.dart';

/// ============================================================================
/// BRANDED HEADER COMPONENT - Mix & Mingle Official Branding
/// Used across the app for consistent top-level branding with logo
/// ============================================================================

class BrandedHeader extends StatefulWidget {
  final String title;
  final bool showLogo;
  final bool enableAnimation;
  final VoidCallback? onLogoTap;
  final double logoSize;
  final double elevation;
  final Color backgroundColor;
  final List<Widget>? actions;

  const BrandedHeader({
    super.key,
    required this.title,
    this.showLogo = true,
    this.enableAnimation = true,
    this.onLogoTap,
    this.logoSize = 48,
    this.elevation = 8,
    this.backgroundColor = const Color(0xFF1A1F3A),
    this.actions,
  });

  @override
  State<BrandedHeader> createState() => _BrandedHeaderState();
}

class _BrandedHeaderState extends State<BrandedHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.enableAnimation) {
      _glowController = AnimationController(
        duration: const Duration(milliseconds: 2000),
        vsync: this,
      )..repeat(reverse: true);

      _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    if (widget.enableAnimation) {
      _glowController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: NeonColors.neonOrange.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo on the left
              if (widget.showLogo)
                GestureDetector(
                  onTap: widget.onLogoTap,
                  child: widget.enableAnimation
                      ? AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, child) {
                            return Container(
                              width: widget.logoSize,
                              height: widget.logoSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: NeonColors.neonOrange.withValues(
                                      alpha: _glowAnimation.value * 0.6,
                                    ),
                                    blurRadius: 16 * _glowAnimation.value,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: NeonColors.neonBlue.withValues(
                                      alpha: _glowAnimation.value * 0.3,
                                    ),
                                    blurRadius: 12 * _glowAnimation.value,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        NeonColors.neonOrange
                                            .withValues(alpha: 0.1),
                                        NeonColors.neonBlue
                                            .withValues(alpha: 0.1),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: NeonColors.neonOrange
                                          .withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: Image.asset(
                                    'assets/images/app_logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              NeonColors.neonOrange,
                                              NeonColors.neonPurple,
                                            ],
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.music_note,
                                          size: 24,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          width: widget.logoSize,
                          height: widget.logoSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: NeonColors.neonOrange
                                    .withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color:
                                    NeonColors.neonBlue.withValues(alpha: 0.15),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    NeonColors.neonOrange
                                        .withValues(alpha: 0.1),
                                    NeonColors.neonBlue.withValues(alpha: 0.1),
                                  ],
                                ),
                                border: Border.all(
                                  color: NeonColors.neonOrange
                                      .withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          NeonColors.neonOrange,
                                          NeonColors.neonPurple,
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.music_note,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                ),
              const SizedBox(width: 12),

              // Title in the middle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: NeonColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: 2,
                      width: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            NeonColors.neonOrange.withValues(alpha: 0.8),
                            NeonColors.neonBlue.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions on the right
              if (widget.actions != null && widget.actions!.isNotEmpty)
                Row(
                  children: widget.actions!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact branded header for modals and secondary screens
class CompactBrandedHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  const CompactBrandedHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NeonColors.darkBg2,
        border: Border(
          bottom: BorderSide(
            color: NeonColors.neonOrange.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: NeonColors.neonBlue,
                    size: 20,
                  ),
                ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: NeonColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actions != null && actions!.isNotEmpty)
                Row(children: actions!),
            ],
          ),
        ),
      ),
    );
  }
}

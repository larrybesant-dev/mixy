import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/animations/custom_animations.dart';

/// Mix & Mingle Branded Loading Indicators
/// Consistent loading states with nightclub aesthetic

/// Primary branded loading indicator
class BrandedLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const BrandedLoadingIndicator({
    super.key,
    this.size = 40.0,
    this.color,
    this.strokeWidth = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? ClubColors.primary,
        ),
      ),
    );
  }
}

/// Full-screen loading overlay
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool showLogo;

  const LoadingOverlay({
    super.key,
    this.message,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ClubColors.deepNavy.withValues(alpha: 0.95),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showLogo) ...const [
              PulseAnimation(
                child: Icon(
                  Icons.music_note,
                  size: 80,
                  color: ClubColors.primary,
                ),
              ),
              SizedBox(height: 32),
            ],
            const BrandedLoadingIndicator(size: 50),
            if (message != null) ...[
              const SizedBox(height: 24),
              Text(
                message!,
                style: ClubTextStyles.textTheme.bodyLarge?.copyWith(
                  color: ClubColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline loading indicator with text
class InlineLoader extends StatelessWidget {
  final String? message;
  final double size;

  const InlineLoader({
    super.key,
    this.message,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BrandedLoadingIndicator(size: size, strokeWidth: 3.0),
          if (message != null) ...[
            const SizedBox(width: 16),
            Text(
              message!,
              style: ClubTextStyles.textTheme.bodyMedium?.copyWith(
                color: ClubColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shimmer loading card
class ShimmerLoadingCard extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const ShimmerLoadingCard({
    super.key,
    this.height = 200,
    this.width,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: ClubColors.cardBackground,
          borderRadius: borderRadius ?? BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// Shimmer loading list item
class ShimmerLoadingListItem extends StatelessWidget {
  final bool hasAvatar;
  final int lineCount;

  const ShimmerLoadingListItem({
    super.key,
    this.hasAvatar = true,
    this.lineCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (hasAvatar) ...[
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: ClubColors.cardBackground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  lineCount,
                  (index) => Padding(
                    padding: EdgeInsets.only(
                      bottom: index < lineCount - 1 ? 8 : 0,
                    ),
                    child: Container(
                      height: 12,
                      width: index == 0 ? double.infinity : 150,
                      decoration: BoxDecoration(
                        color: ClubColors.cardBackground,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing dots loader
class PulsingDotsLoader extends StatefulWidget {
  final Color color;
  final double size;
  final int dotCount;

  const PulsingDotsLoader({
    super.key,
    this.color = ClubColors.primary,
    this.size = 12.0,
    this.dotCount = 3,
  });

  @override
  State<PulsingDotsLoader> createState() => _PulsingDotsLoaderState();
}

class _PulsingDotsLoaderState extends State<PulsingDotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        widget.dotCount,
        (index) => AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final progress = (_controller.value - delay).clamp(0.0, 1.0);
            final scale = 0.5 + (0.5 * (1 - (progress - 0.5).abs() * 2));

            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            width: widget.size,
            height: widget.size,
            margin: EdgeInsets.symmetric(horizontal: widget.size / 4),
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Spinning loader with icon
class SpinningIconLoader extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;

  const SpinningIconLoader({
    super.key,
    this.icon = Icons.refresh,
    this.size = 40.0,
    this.color = ClubColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return RotateAnimation(
      child: Icon(
        icon,
        size: size,
        color: color,
      ),
    );
  }
}

/// Linear progress bar with label
class LabeledProgressBar extends StatelessWidget {
  final double? progress;
  final String? label;
  final Color? color;

  const LabeledProgressBar({
    super.key,
    this.progress,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: ClubTextStyles.textTheme.bodySmall?.copyWith(
              color: ClubColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: ClubColors.cardBackground,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? ClubColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Glow loader with neon effect
class NeonGlowLoader extends StatelessWidget {
  final double size;

  const NeonGlowLoader({
    super.key,
    this.size = 60.0,
  });

  @override
  Widget build(BuildContext context) {
    return GlowAnimation(
      glowColor: ClubColors.primary,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: ClubColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.music_note,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Skeleton grid loader
class SkeletonGridLoader extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double itemHeight;

  const SkeletonGridLoader({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.itemHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: itemHeight,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return const ShimmerLoadingCard();
      },
    );
  }
}

/// Skeleton list loader
class SkeletonListLoader extends StatelessWidget {
  final int itemCount;
  final bool hasAvatar;

  const SkeletonListLoader({
    super.key,
    this.itemCount = 5,
    this.hasAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return ShimmerLoadingListItem(hasAvatar: hasAvatar);
      },
    );
  }
}

/// Button loading state
class LoadingButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color? backgroundColor;

  const LoadingButton({
    super.key,
    required this.label,
    required this.isLoading,
    this.onPressed,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: backgroundColor != null
          ? ElevatedButton.styleFrom(backgroundColor: backgroundColor)
          : null,
      child: isLoading
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Loading...'),
              ],
            )
          : Text(label),
    );
  }
}

/// Loading card placeholder
class LoadingCardPlaceholder extends StatelessWidget {
  final double height;
  final bool showShimmer;

  const LoadingCardPlaceholder({
    super.key,
    this.height = 200,
    this.showShimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Container(
        height: height,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrandedLoadingIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );

    return showShimmer ? ShimmerEffect(child: card) : card;
  }
}

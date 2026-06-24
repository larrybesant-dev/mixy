import 'package:flutter/material.dart';
import 'club_background.dart';
import 'glow_text.dart';

/// Loading overlay widget that can be shown over any content
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? loadingMessage;
  final Color? loadingColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.loadingMessage,
    this.loadingColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2F).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFF4C4C).withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: loadingColor ?? const Color(0xFFFF4C4C),
              ),
              const SizedBox(height: 16),
              GlowText(
                text: loadingMessage ?? 'Loading...',
                fontSize: 16,
                color: Colors.white,
                glowColor: loadingColor ?? const Color(0xFFFF4C4C),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full screen loading widget for initial app loading
class FullScreenLoader extends StatelessWidget {
  final String? message;

  const FullScreenLoader({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo or icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4C4C), Color(0xFFFFD700)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4C4C).withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const GlowText(
                text: 'MIX & MINGLE',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFD700),
                glowColor: Color(0xFFFF4C4C),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(
                color: Color(0xFFFF4C4C),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              GlowText(
                text: message ?? 'Initializing...',
                fontSize: 16,
                color: Colors.white70,
                glowColor: const Color(0xFFFF4C4C),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loading widget for content placeholders
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _animation.value),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}

/// Skeleton loader for room cards
class RoomCardSkeleton extends StatelessWidget {
  const RoomCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3D).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0x4DFFFFFF),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room name skeleton
          SkeletonLoader(
            width: 150,
            height: 24,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          // DJ name skeleton
          SkeletonLoader(
            width: 100,
            height: 16,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          // Viewer count skeleton
          SkeletonLoader(
            width: 80,
            height: 14,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
          // Join button skeleton
          Align(
            alignment: Alignment.centerRight,
            child: SkeletonLoader(
              width: 80,
              height: 36,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid of skeleton room cards for loading state
class RoomGridSkeleton extends StatelessWidget {
  final int itemCount;

  const RoomGridSkeleton({
    super.key,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const RoomCardSkeleton(),
    );
  }
}

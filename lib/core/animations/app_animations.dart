import 'package:flutter/material.dart';
import 'package:mixvy/core/theme/enhanced_theme.dart';

/// Enhanced animation utilities for smooth transitions and micro-interactions
class AppAnimations {
  // Page transitions
  static const PageTransitionsTheme pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
    },
  );

  // Fade animations
  static Widget fadeIn({
    required Widget child,
    Duration duration = EnhancedTheme.normalAnimation,
    Curve curve = Curves.easeOut,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: child,
    );
  }

  // Scale animations
  static Widget scaleIn({
    required Widget child,
    Duration duration = EnhancedTheme.normalAnimation,
    Curve curve = Curves.elasticOut,
    double beginScale = 0.8,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: beginScale, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }

  // Slide animations
  static Widget slideInFromBottom({
    required Widget child,
    Duration duration = EnhancedTheme.normalAnimation,
    Curve curve = Curves.easeOut,
    double beginOffset = 50.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: beginOffset, end: 0.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, value),
          child: child,
        );
      },
      child: child,
    );
  }

  static Widget slideInFromRight({
    required Widget child,
    Duration duration = EnhancedTheme.normalAnimation,
    Curve curve = Curves.easeOut,
    double beginOffset = 50.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: -beginOffset, end: 0.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(value, 0),
          child: child,
        );
      },
      child: child,
    );
  }

  // Bounce animation for buttons
  static Widget bounceOnTap({
    required Widget child,
    required VoidCallback onTap,
    Duration duration = EnhancedTheme.fastAnimation,
  }) {
    return _BounceOnTap(
      duration: duration,
      onTap: onTap,
      child: child,
    );
  }

  // Pulse animation for loading states
  static Widget pulse({
    required Widget child,
    Duration duration = const Duration(milliseconds: 1500),
    double beginScale = 1.0,
    double endScale = 1.05,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: beginScale, end: endScale),
      duration: duration,
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }

  // Shimmer effect for loading
  static Widget shimmer({
    required Widget child,
    Duration duration = const Duration(milliseconds: 1500),
    Gradient? gradient,
  }) {
    return _Shimmer(
      duration: duration,
      gradient: gradient ??
          const LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white24,
              Colors.transparent,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
      child: child,
    );
  }

  // Staggered animation for lists
  static Widget staggeredList({
    required List<Widget> children,
    Duration staggerDelay = const Duration(milliseconds: 100),
    Duration itemDuration = EnhancedTheme.normalAnimation,
  }) {
    return Column(
      children: List.generate(children.length, (index) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: itemDuration,
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 20),
                child: child,
              ),
            );
          },
          child: children[index],
        );
      }),
    );
  }
}

/// Bounce on tap widget
class _BounceOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Duration duration;

  const _BounceOnTap({
    required this.child,
    required this.onTap,
    required this.duration,
  });

  @override
  State<_BounceOnTap> createState() => _BounceOnTapState();
}

class _BounceOnTapState extends State<_BounceOnTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// Shimmer effect widget
class _Shimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Gradient gradient;

  const _Shimmer({
    required this.child,
    required this.duration,
    required this.gradient,
  });

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return widget.gradient.createShader(
          Rect.fromLTWH(
            bounds.width * _animation.value,
            0,
            bounds.width,
            bounds.height,
          ),
        );
      },
      child: widget.child,
    );
  }
}


import 'package:flutter/material.dart';

/// Animates a gift emoji floating upward with fade-out.
/// Usage:
/// ```dart
/// FloatingGiftAnimation.show(context, emoji: '🌹', duration: Duration(seconds: 3));
/// ```
class FloatingGiftAnimation extends StatefulWidget {
  final String emoji;
  final Duration duration;
  final VoidCallback? onComplete;

  const FloatingGiftAnimation({
    Key? key,
    required this.emoji,
    this.duration = const Duration(milliseconds: 3000),
    this.onComplete,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required String emoji,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => FloatingGiftAnimation(
        emoji: emoji,
        duration: duration,
        onComplete: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  @override
  State<FloatingGiftAnimation> createState() => _FloatingGiftAnimationState();
}

class _FloatingGiftAnimationState extends State<FloatingGiftAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    // Float upward
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -3), // Move up by 3 * screen height
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Fade out
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInExpo),
    );

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100 + MediaQuery.of(context).size.height * 0.1,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Center(
            child: Text(
              widget.emoji,
              style: const TextStyle(fontSize: 64),
            ),
          ),
        ),
      ),
    );
  }
}

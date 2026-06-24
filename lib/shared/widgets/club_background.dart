import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/theme/colors.dart';

/// Club-style background matching the flyer design
/// Dark navy with subtle gradient and glow effects
class ClubBackground extends ConsumerWidget {
  final Widget child;
  final Color? backgroundColor;

  const ClubBackground({
    required this.child,
    this.backgroundColor,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always use dark mode for club/nightclub theme
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ClubColors.darkBackground,
            ClubColors.darkBackground.withBlue(40),
            ClubColors.darkBackground.withRed(30),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: child,
    );
  }
}


import 'package:flutter/material.dart';

class FeedLoadingShimmer extends StatelessWidget {
  const FeedLoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    // Simple shimmer placeholder using colored containers
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: List.generate(
            3,
            (index) => Container(
              margin: const EdgeInsets.only(right: 16),
              width: 160,
              height: 180,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: List.generate(
            5,
            (index) => Container(
              margin: const EdgeInsets.only(right: 16),
              width: 72,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}




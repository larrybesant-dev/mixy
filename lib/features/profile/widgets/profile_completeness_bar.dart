// lib/features/profile/widgets/profile_completeness_bar.dart
//
// Shows a thin progress bar + "X% complete" label for the current user's
// profile. Tapping navigates to the Edit Profile page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/providers/profile_completion_providers.dart';

class ProfileCompletenessBar extends ConsumerWidget {
  final String userId;

  const ProfileCompletenessBar({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(profileCompletenessScoreProvider(userId));

    return scoreAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (score) {
        final pct = (score / 100).clamp(0.0, 1.0);
        final isComplete = score >= 100;

        if (isComplete) return const SizedBox.shrink();

        return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DesignColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: DesignColors.accent.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Complete your profile',
                  style: TextStyle(
                    color: DesignColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$score%',
                  style: const TextStyle(
                    color: DesignColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: DesignColors.surfaceDefault,
                valueColor: const AlwaysStoppedAnimation<Color>(DesignColors.accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap to finish setting up your profile →',
              style: TextStyle(
                color: DesignColors.textGray.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}

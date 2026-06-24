// lib/features/profile/widgets/mutual_followers_row.dart
//
// Shows stacked avatar circles for up to 3 mutual followers, plus a count
// label. Hidden when there are no mutual followers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_constants.dart';
import '../../../shared/providers/providers.dart';

class MutualFollowersRow extends ConsumerWidget {
  final String currentUserId;
  final String profileUserId;

  const MutualFollowersRow({
    super.key,
    required this.currentUserId,
    required this.profileUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Skip when viewing own profile
    if (currentUserId == profileUserId) return const SizedBox.shrink();

    final asyncMutual = ref.watch(mutualFollowersProvider(
      (currentUserId: currentUserId, profileUserId: profileUserId),
    ));

    return asyncMutual.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (mutuals) {
        if (mutuals.isEmpty) return const SizedBox.shrink();

        final shown = mutuals.take(3).toList();
        final overflow = mutuals.length - shown.length;

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              // Stacked avatars
              SizedBox(
                width: shown.length * 22.0 + 8,
                height: 30,
                child: Stack(
                  children: [
                    for (int i = 0; i < shown.length; i++)
                      Positioned(
                        left: i * 22.0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: DesignColors.background, width: 2),
                          ),
                          child: ClipOval(
                            child: (shown[i].photoUrl ?? '').isNotEmpty
                                ? Image.network(
                                    shown[i].photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _initials(shown[i].displayName ?? ''),
                                  )
                                : _initials(shown[i].displayName ?? ''),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _buildLabel(mutuals.length, overflow, shown),
                  style: const TextStyle(
                    color: DesignColors.textGray,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildLabel(int total, int overflow, List<dynamic> shown) {
    if (total == 1) {
      return '${shown.first.displayName ?? 'Someone you follow'} follows this person';
    }
    if (total == 2) {
      return '${shown[0].displayName} and ${shown[1].displayName} follow this person';
    }
    final extra = overflow > 0 ? ' and $overflow others' : '';
    return '${shown[0].displayName}, ${shown[1].displayName}$extra follow this person';
  }

  Widget _initials(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: DesignColors.surfaceLight,
      child: Center(
        child: Text(initial,
            style: const TextStyle(
                color: DesignColors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

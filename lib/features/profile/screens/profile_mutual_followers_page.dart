// lib/features/profile/screens/profile_mutual_followers_page.dart
//
// Full list of people who follow profileUserId and are also followed
// by currentUserId ("people you follow who also follow this person").

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_constants.dart';
import '../../../shared/models/user.dart';
import '../../../shared/providers/providers.dart';
import 'user_profile_page.dart';

class ProfileMutualFollowersPage extends ConsumerWidget {
  final String currentUserId;
  final String profileUserId;
  final String? profileDisplayName;

  const ProfileMutualFollowersPage({
    super.key,
    required this.currentUserId,
    required this.profileUserId,
    this.profileDisplayName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMutual = ref.watch(mutualFollowersProvider(
      (currentUserId: currentUserId, profileUserId: profileUserId),
    ));

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: DesignColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: DesignColors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          profileDisplayName != null
              ? 'People you follow who follow ${profileDisplayName!}'
              : 'Mutual Followers',
          style: const TextStyle(
              color: DesignColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: asyncMutual.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: DesignColors.accent)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: DesignColors.error))),
        data: (mutuals) {
          if (mutuals.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline,
                      size: 48,
                      color: DesignColors.textGray.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  const Text(
                    'No mutual followers yet',
                    style: TextStyle(
                        color: DesignColors.textGray, fontSize: 15),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: mutuals.length,
            separatorBuilder: (_, __) => Divider(
              color: DesignColors.divider.withValues(alpha: 0.3),
              height: 1,
            ),
            itemBuilder: (ctx, i) =>
                _MutualTile(user: mutuals[i]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MutualTile extends StatelessWidget {
  final User user;

  const _MutualTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: DesignColors.surfaceLight,
        backgroundImage: (user.photoUrl ?? '').isNotEmpty
            ? NetworkImage(user.photoUrl!)
            : null,
        child: (user.photoUrl ?? '').isEmpty
            ? Text(
                (user.displayName ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                    color: DesignColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              )
            : null,
      ),
      title: Text(
        user.displayName ?? user.nickname ?? 'Anonymous',
        style: const TextStyle(
            color: DesignColors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600),
      ),
      subtitle: (user.bio ?? '').trim().isNotEmpty
          ? Text(
              user.bio ?? '',
              style: const TextStyle(
                  color: DesignColors.textGray, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: const Icon(Icons.arrow_forward_ios,
          size: 14, color: DesignColors.textGray),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfilePage(userId: user.id),
        ),
      ),
    );
  }
}

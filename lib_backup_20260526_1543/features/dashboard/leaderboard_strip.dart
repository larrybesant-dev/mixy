import 'package:flutter/material.dart';
import '../../../widgets/safe_network_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import 'leaderboard_provider.dart';

class LeaderboardStrip extends ConsumerWidget {
  const LeaderboardStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (__, _) => const SizedBox.shrink(),
      data: (users) {
        if (users.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    size: 18,
                    color: VelvetNoir.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hall of Fame',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: VelvetNoir.onSurface,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: users.length,
                separatorBuilder: (__, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) =>
                    _LeaderCard(rank: i + 1, user: users[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Single leaderboard card ──────────────────────────────────────────────────

class _LeaderCard extends StatelessWidget {
  const _LeaderCard({required this.rank, required this.user});

  final int rank;
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final rankColor = rank == 1
        ? const Color(0xFFFFD700) // gold
        : rank == 2
            ? const Color(0xFFCFD8DC) // silver
            : rank == 3
                ? const Color(0xFFBF8970) // bronze
                : VelvetNoir.onSurfaceVariant;

    return GestureDetector(
      onTap: () => context.push('/profile/${user.id}'),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                rank <= 3 ? rankColor.withAlpha(80) : VelvetNoir.outlineVariant,
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar with rank badge overlay
            Stack(
              alignment: Alignment.topLeft,
              children: [
                SafeNetworkAvatar(
                  radius: 22,
                  avatarUrl: user.avatarUrl,
                  backgroundColor: VelvetNoir.surfaceHighest,
                  fallbackText: user.username.isNotEmpty
                      ? user.username[0].toUpperCase()
                      : '?',
                  fallbackTextStyle: const TextStyle(
                    color: VelvetNoir.onSurfaceVariant,
                  ),
                ),
                if (rank <= 3)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: rankColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              user.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: VelvetNoir.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  size: 11,
                  color: rank <= 3 ? rankColor : VelvetNoir.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  _fmt(user.coinBalance),
                  style: TextStyle(
                    fontSize: 9,
                    color: rank <= 3 ? rankColor : VelvetNoir.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/widgets/club_background.dart';
import 'package:mixvy/shared/models/achievement.dart';
import 'package:mixvy/shared/providers/all_providers.dart';

class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamificationService = ref.read(gamificationServiceProvider);
    final authUser = ref.watch(authStateProvider).value;

    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view achievements')),
      );
    }

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('ðŸ† Achievements'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: FutureBuilder<List<Achievement>>(
          future: gamificationService.getUserAchievements(authUser.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final achievements = snapshot.data ?? [];
            if (achievements.isEmpty) {
              // Initialize with default achievements
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No achievements yet!'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await gamificationService
                            .initializeAchievements(authUser.uid);
                        // Trigger rebuild
                        (context as Element).markNeedsBuild();
                      },
                      child: const Text('Initialize Achievements'),
                    ),
                  ],
                ),
              );
            }

            final unlocked = achievements.where((a) => a.isUnlocked).toList();
            final locked = achievements.where((a) => !a.isUnlocked).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatsCard(unlocked.length, achievements.length),
                const SizedBox(height: 24),
                if (unlocked.isNotEmpty) ...[
                  const Text(
                    'âœ¨ Unlocked',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...unlocked.map((achievement) =>
                      _buildAchievementCard(achievement, true)),
                  const SizedBox(height: 24),
                ],
                if (locked.isNotEmpty) ...[
                  const Text(
                    'ðŸ”’ Locked',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...locked.map((achievement) =>
                      _buildAchievementCard(achievement, false)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsCard(int unlocked, int total) {
    final percentage = total > 0 ? (unlocked / total * 100).toInt() : 0;

    return Card(
      elevation: 4,
      color: Colors.purple.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Unlocked', unlocked.toString(), Colors.green),
                _buildStatItem('Total', total.toString(), Colors.blue),
                _buildStatItem('Progress', '$percentage%', Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: total > 0 ? unlocked / total : 0,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementCard(Achievement achievement, bool isUnlocked) {
    return Card(
      elevation: isUnlocked ? 3 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      color: isUnlocked
          ? Colors.purple.withValues(alpha: 0.15)
          : Colors.grey.withValues(alpha: 0.1),
      child: ListTile(
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isUnlocked
                ? _getCategoryColor(achievement.category)
                : Colors.grey[700],
          ),
          child: Center(
            child: Text(
              achievement.icon,
              style: TextStyle(
                fontSize: 28,
                color: isUnlocked ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ),
        title: Text(
          achievement.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isUnlocked ? Colors.white : Colors.white54,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              achievement.description,
              style: TextStyle(
                fontSize: 13,
                color: isUnlocked ? Colors.white70 : Colors.white38,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.stars, size: 14, color: Colors.yellow[700]),
                const SizedBox(width: 4),
                Text(
                  '${achievement.xpReward} XP',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.yellow,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.monetization_on,
                    size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  '${achievement.coinReward} coins',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            if (!isUnlocked) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: achievement.targetValue > 0
                    ? achievement.currentProgress / achievement.targetValue
                    : 0,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getCategoryColor(achievement.category)
                      .withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${achievement.currentProgress}/${achievement.targetValue}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white38,
                ),
              ),
            ],
            if (isUnlocked && achievement.unlockedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Unlocked: ${_formatDate(achievement.unlockedAt!)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: isUnlocked
            ? const Icon(Icons.check_circle, color: Colors.green, size: 32)
            : const Icon(Icons.lock, color: Colors.white38, size: 28),
      ),
    );
  }

  Color _getCategoryColor(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.social:
        return Colors.blue;
      case AchievementCategory.rooms:
        return Colors.purple;
      case AchievementCategory.events:
        return Colors.orange;
      case AchievementCategory.engagement:
        return Colors.pink;
      case AchievementCategory.milestone:
        return Colors.amber;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${(diff.inDays / 30).floor()} months ago';
  }
}


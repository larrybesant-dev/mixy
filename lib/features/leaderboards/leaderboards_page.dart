import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/shared/widgets/club_background.dart';
import 'package:mixvy/shared/providers/providers.dart';

class LeaderboardsPage extends ConsumerStatefulWidget {
  const LeaderboardsPage({super.key});

  @override
  ConsumerState<LeaderboardsPage> createState() => _LeaderboardsPageState();
}

class _LeaderboardsPageState extends ConsumerState<LeaderboardsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('ðŸ† Leaderboards'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Level', icon: Icon(Icons.emoji_events)),
              Tab(text: 'Streak', icon: Icon(Icons.local_fire_department)),
              Tab(text: 'Coins', icon: Icon(Icons.monetization_on)),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildLevelLeaderboard(currentUser?.uid),
            _buildStreakLeaderboard(currentUser?.uid),
            _buildCoinsLeaderboard(currentUser?.uid),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelLeaderboard(String? currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_levels')
          .orderBy('level', descending: true)
          .orderBy('xp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No data yet!\nBe the first to level up!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final userId = docs[index].id;
            final level = data['level'] ?? 1;
            final xp = data['xp'] ?? 0;
            final isCurrentUser = userId == currentUserId;

            return _buildLeaderboardItem(
              rank: index + 1,
              userId: userId,
              primaryStat: 'Level $level',
              secondaryStat: '$xp XP',
              icon: Icons.emoji_events,
              color: _getRankColor(index + 1),
              isCurrentUser: isCurrentUser,
            );
          },
        );
      },
    );
  }

  Widget _buildStreakLeaderboard(String? currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_streaks')
          .orderBy('currentStreak', descending: true)
          .orderBy('longestStreak', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No data yet!\nStart your streak today!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final userId = docs[index].id;
            final currentStreak = data['currentStreak'] ?? 0;
            final longestStreak = data['longestStreak'] ?? 0;
            final isCurrentUser = userId == currentUserId;

            return _buildLeaderboardItem(
              rank: index + 1,
              userId: userId,
              primaryStat: '$currentStreak ðŸ”¥',
              secondaryStat: 'Best: $longestStreak days',
              icon: Icons.local_fire_department,
              color: _getRankColor(index + 1),
              isCurrentUser: isCurrentUser,
            );
          },
        );
      },
    );
  }

  Widget _buildCoinsLeaderboard(String? currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('coinBalance', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No data yet!\nEarn coins by being active!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final userId = docs[index].id;
            final coins = data['coinBalance'] ?? 0;
            final username = data['username'] ?? 'Unknown';
            final isCurrentUser = userId == currentUserId;

            return _buildLeaderboardItem(
              rank: index + 1,
              userId: userId,
              primaryStat: '$coins coins',
              secondaryStat: '@$username',
              icon: Icons.monetization_on,
              color: _getRankColor(index + 1),
              isCurrentUser: isCurrentUser,
            );
          },
        );
      },
    );
  }

  Widget _buildLeaderboardItem({
    required int rank,
    required String userId,
    required String primaryStat,
    required String secondaryStat,
    required IconData icon,
    required Color color,
    required bool isCurrentUser,
  }) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final username = snapshot.hasData && snapshot.data!.exists
            ? (snapshot.data!.data() as Map<String, dynamic>)['username'] ??
                'Unknown'
            : 'Loading...';
        final profilePhoto = snapshot.hasData && snapshot.data!.exists
            ? (snapshot.data!.data() as Map<String, dynamic>)['profilePhotoUrl']
            : null;

        return Card(
          elevation: isCurrentUser ? 6 : 2,
          margin: const EdgeInsets.only(bottom: 12),
          color: isCurrentUser
              ? Colors.blue.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isCurrentUser
                ? const BorderSide(color: Colors.blue, width: 2)
                : BorderSide.none,
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rank badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getRankDisplay(rank),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Profile picture
                CircleAvatar(
                  radius: 24,
                  backgroundImage:
                      profilePhoto != null ? NetworkImage(profilePhoto) : null,
                  child: profilePhoto == null
                      ? Text(
                          username[0].toUpperCase(),
                          style: const TextStyle(fontSize: 20),
                        )
                      : null,
                ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '@$username',
                    style: TextStyle(
                      fontWeight:
                          isCurrentUser ? FontWeight.bold : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (isCurrentUser)
                  const Chip(
                    label: Text(
                      'YOU',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            subtitle: Text(
              secondaryStat,
              style: const TextStyle(color: Colors.white60),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 4),
                Text(
                  primaryStat,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber; // Gold
    if (rank == 2) return Colors.grey[400]!; // Silver
    if (rank == 3) return const Color(0xFFCD7F32); // Bronze
    if (rank <= 10) return Colors.purple[300]!;
    if (rank <= 25) return Colors.blue[300]!;
    return Colors.grey[600]!;
  }

  String _getRankDisplay(int rank) {
    if (rank == 1) return 'ðŸ¥‡';
    if (rank == 2) return 'ðŸ¥ˆ';
    if (rank == 3) return 'ðŸ¥‰';
    return '#$rank';
  }
}


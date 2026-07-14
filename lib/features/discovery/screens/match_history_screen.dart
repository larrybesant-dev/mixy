import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_history_provider.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../widgets/safe_network_avatar.dart';
import '../../../core/theme.dart';

class MatchHistoryScreen extends ConsumerStatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  ConsumerState<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends ConsumerState<MatchHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(userProvider);
    final userId = currentUser?.id ?? '';

    if (userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('History')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Who Liked You'),
            Tab(text: 'Swipe History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _WhoLikedYouTab(userId: userId),
          _SwipeHistoryTab(userId: userId),
        ],
      ),
    );
  }
}

class _WhoLikedYouTab extends ConsumerWidget {
  final String userId;

  const _WhoLikedYouTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likeCountAsync = ref.watch(likeCountProvider(userId));
    final profileViewsAsync = ref.watch(profileViewsProvider(userId));

    return likeCountAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (likeCount) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(likeCountProvider(userId));
            ref.invalidate(profileViewsProvider(userId));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Header with count
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      Text(
                        '$likeCount',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: VelvetNoir.primary,
                            ),
                      ),
                      Text(
                        '${likeCount == 1 ? 'person' : 'people'} liked you',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),

                // Profile views
                profileViewsAsync.when(
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const Center(child: Text('Error loading views')),
                  data: (profileViews) {
                    if (profileViews.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No one has viewed your profile yet',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: profileViews.length,
                      itemBuilder: (context, index) {
                        final view = profileViews[index];
                        return _ProfileViewCard(viewId: view.viewerId);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileViewCard extends ConsumerWidget {
  final String viewId;

  const _ProfileViewCard({required this.viewId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SafeNetworkAvatar(
              radius: 32,
              fallbackText: viewId.isNotEmpty ? viewId[0].toUpperCase() : '?',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viewId,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Viewed your profile',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.visibility),
              label: const Text('View'),
              onPressed: () {
                // Navigate to user profile
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeHistoryTab extends ConsumerWidget {
  final String userId;

  const _SwipeHistoryTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final swipeHistoryAsync = ref.watch(swipeHistoryProvider(userId));

    return swipeHistoryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (history) {
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No swipes yet',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: history.length,
          itemBuilder: (context, index) {
            final swipe = history[index];
            return _SwipeCard(swipe: swipe);
          },
        );
      },
    );
  }
}

class _SwipeCard extends ConsumerWidget {
  final dynamic swipe;

  const _SwipeCard({required this.swipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLike = swipe.isLike;
    final isMutual = swipe.isMutual;
    final createdAt = swipe.createdAt;
    final candidateId = swipe.candidateId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SafeNetworkAvatar(
              radius: 32,
              fallbackText: candidateId.isNotEmpty ? candidateId[0].toUpperCase() : '?',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        candidateId,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (isMutual)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: VelvetNoir.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Mutual',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLike ? '❤️ Liked' : '👋 Passed',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isLike ? Colors.red : Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              isLike ? Icons.favorite : Icons.close,
              color: isLike ? Colors.red : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.month}/${date.day}/${date.year}';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/core/responsive/responsive_utils.dart';
import 'package:mixmingle/core/animations/app_animations.dart';
import 'package:mixmingle/shared/providers/all_providers.dart';
import 'package:mixmingle/app/app_routes.dart';
import 'package:mixmingle/shared/widgets/club_background.dart';
import 'package:mixmingle/shared/widgets/async_value_view_enhanced.dart';
import 'package:mixmingle/shared/widgets/skeleton_loaders.dart';
import 'package:mixmingle/shared/models/match.dart';

class MatchesPage extends ConsumerStatefulWidget {
  const MatchesPage({super.key});

  @override
  ConsumerState<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends ConsumerState<MatchesPage>
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
    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Matches'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Matches'),
              Tab(text: 'Likes'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMatchesTab(),
            _buildLikesTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'discover_fab',
          onPressed: () {
            Navigator.of(context).pushNamed(AppRoutes.discoverUsers);
          },
          icon: const Icon(Icons.explore),
          label: const Text('Discover'),
        ),
      ),
    );
  }

  Widget _buildMatchesTab() {
    final matchesAsync = ref.watch(userMatchesProvider);

    return AsyncValueViewEnhanced(
      value: matchesAsync,
      maxRetries: 3,
      skeleton: const SkeletonGrid(itemCount: 6, crossAxisCount: 2),
      screenName: 'MatchesPage',
      providerName: 'userMatchesProvider',
      onRetry: () => ref.invalidate(userMatchesProvider),
      data: (matches) {
        if (matches.isEmpty) {
          return _buildEmptyState(
            context,
            'No matches yet',
            'Start swiping to find your perfect match!',
            Icons.favorite_border,
          );
        }

        return AppAnimations.fadeIn(
          child: GridView.builder(
            padding: Responsive.responsivePadding(context),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Responsive.responsiveValue(
                context: context,
                mobile: 2,
                tablet: 3,
                desktop: 4,
              ),
              crossAxisSpacing: Responsive.responsiveSpacing(context, 16),
              mainAxisSpacing: Responsive.responsiveSpacing(context, 16),
              childAspectRatio: 0.75,
            ),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              return AppAnimations.scaleIn(
                beginScale: 0.8,
                child: _buildMatchCard(context, match),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLikesTab() {
    final likesAsync = ref.watch(pendingMatchRequestsProvider);

    return AsyncValueViewEnhanced(
      value: likesAsync,
      maxRetries: 3,
      skeleton: const SkeletonList(itemCount: 5, showAvatar: true),
      screenName: 'MatchesPage',
      providerName: 'pendingMatchRequestsProvider',
      onRetry: () => ref.invalidate(pendingMatchRequestsProvider),
      data: (likes) {
        if (likes.isEmpty) {
          return _buildEmptyState(
            context,
            'No pending likes',
            'People who like you will appear here',
            Icons.thumb_up_outlined,
          );
        }

        return ListView.builder(
          padding: Responsive.responsivePadding(context),
          itemCount: likes.length,
          itemBuilder: (context, index) {
            final like = likes[index];
            return _buildLikeCard(context, like);
          },
        );
      },
    );
  }

  Widget _buildMatchCard(BuildContext context, Match match) {
    final otherUserId = match.user1Id == ref.read(currentUserProvider).value?.id
        ? match.user2Id
        : match.user1Id;
    final userProfileAsync = ref.watch(userProfileProvider(otherUserId));

    return userProfileAsync.when(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.of(context).pushNamed(
                AppRoutes.chat,
                arguments: {
                  'userId': otherUserId,
                  'username': profile.username,
                },
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      profile.profileImageUrl != null
                          ? Image.network(
                              profile.profileImageUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              child: Icon(
                                Icons.person,
                                size:
                                    Responsive.responsiveIconSize(context, 60),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                      if (profile.isOnline)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Online',
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
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.username ?? 'User',
                        style: TextStyle(
                          fontSize: Responsive.responsiveFontSize(context, 16),
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (profile.age != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${profile.age} years old',
                          style: TextStyle(
                            fontSize:
                                Responsive.responsiveFontSize(context, 12),
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildLikeCard(BuildContext context, Match like) {
    final otherUserId = like.user1Id == ref.read(currentUserProvider).value?.id
        ? like.user2Id
        : like.user1Id;
    final userProfileAsync = ref.watch(userProfileProvider(otherUserId));

    return userProfileAsync.when(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();

        return Card(
          margin: EdgeInsets.only(
            bottom: Responsive.responsiveSpacing(context, 12),
          ),
          child: Padding(
            padding: Responsive.responsivePadding(context),
            child: Row(
              children: [
                CircleAvatar(
                  radius: Responsive.responsiveValue(
                    context: context,
                    mobile: 30.0,
                    tablet: 35.0,
                    desktop: 40.0,
                  ),
                  backgroundImage: profile.profileImageUrl != null
                      ? NetworkImage(profile.profileImageUrl!)
                      : null,
                  child: profile.profileImageUrl == null
                      ? Icon(
                          Icons.person,
                          size: Responsive.responsiveIconSize(context, 30),
                        )
                      : null,
                ),
                SizedBox(width: Responsive.responsiveSpacing(context, 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.username ?? 'User',
                        style: TextStyle(
                          fontSize: Responsive.responsiveFontSize(context, 16),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (profile.bio != null)
                        Text(
                          profile.bio!,
                          style: TextStyle(
                            fontSize:
                                Responsive.responsiveFontSize(context, 14),
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                SizedBox(width: Responsive.responsiveSpacing(context, 16)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () async {
                        await ref
                            .read(matchControllerProvider.notifier)
                            .reject(otherUserId);
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.favorite,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () async {
                        await ref
                            .read(matchControllerProvider.notifier)
                            .accept(otherUserId);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(Icons.person)),
          title: Text('Loading...'),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    String title,
    String message,
    IconData icon,
  ) {
    return Center(
      child: Padding(
        padding: Responsive.responsivePadding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: Responsive.responsiveIconSize(context, 80),
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            SizedBox(height: Responsive.responsiveSpacing(context, 24)),
            Text(
              title,
              style: TextStyle(
                fontSize: Responsive.responsiveFontSize(context, 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: Responsive.responsiveSpacing(context, 12)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Responsive.responsiveFontSize(context, 16),
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: Responsive.responsiveSpacing(context, 32)),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.discoverUsers);
              },
              icon: const Icon(Icons.explore),
              label: const Text('Start Discovering'),
            ),
          ],
        ),
      ),
    );
  }
}

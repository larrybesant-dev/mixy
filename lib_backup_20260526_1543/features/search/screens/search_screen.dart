import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/layout/app_layout.dart';
import '../../../widgets/safe_network_avatar.dart';
import '../providers/search_provider.dart';
import '../../feed/models/post_model.dart';
import '../../feed/widgets/post_card.dart';
import '../../follow/providers/follow_provider.dart';
import '../../../presentation/providers/friend_provider.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  int _selectedTab = 0; // 0: People, 1: Posts, 2: Hashtags

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(context.pageHorizontalPadding),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search people, posts, #hashtags...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 3,
              initialIndex: _selectedTab,
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                    tabs: const [
                      Tab(text: 'People'),
                      Tab(text: 'Posts'),
                      Tab(text: 'Hashtags'),
                    ],
                    onTap: (index) {
                      setState(() => _selectedTab = index);
                    },
                  ),
                  Expanded(
                    child: _searchQuery.isEmpty && _selectedTab != 0
                        ? _buildTrendingContent()
                        : _buildSearchResults(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingContent() {
    final trendingAsync = ref.watch(trendingHashtagsProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.pageHorizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trending Now', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          AppAsyncValueView<List<SearchHashtag>>(
            value: trendingAsync,
            fallbackContext: 'trending results',
            isEmpty: (hashtags) => hashtags.isEmpty,
            empty: const AppEmptyView(
              icon: Icons.tag_outlined,
              title: 'No trending hashtags yet',
            ),
            data: (hashtags) {
              return Column(
                children: hashtags.map((tag) {
                  return ListTile(
                    leading: const Icon(Icons.tag),
                    title: Text('#${tag.hashtag}'),
                    subtitle: Text('${tag.postCount} posts'),
                    onTap: () {
                      _searchController.text = '#${tag.hashtag}';
                      setState(() => _searchQuery = '#${tag.hashtag}');
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_selectedTab == 0) {
      final usersAsync = _searchQuery.isEmpty
          ? ref.watch(browseAllUsersProvider)
          : ref.watch(searchUsersProvider(_searchQuery));
      return AppAsyncValueView<List<SearchUser>>(
        value: usersAsync,
        fallbackContext: 'users',
        isEmpty: (users) => users.isEmpty,
        empty: const AppEmptyView(
          title: 'No people found',
          message: 'Try a name, username, or explore the latest members.',
        ),
        data: (users) => ListView.separated(
          itemCount: users.length,
          separatorBuilder: (__, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: SafeNetworkAvatar(
                radius: 20,
                avatarUrl: user.avatarUrl,
                fallbackText: user.username.isNotEmpty
                    ? user.username[0].toUpperCase()
                    : '?',
              ),
              title: Row(
                children: [
                  Text(user.username),
                  if (user.isVerified)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.verified, size: 16, color: Colors.blue),
                    ),
                ],
              ),
              subtitle: Text('${user.followerCount} followers'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FriendRequestButton(targetUserId: user.id),
                  _FollowButton(targetUserId: user.id),
                ],
              ),
              onTap: () => context.push('/profile/${user.id}'),
            );
          },
        ),
      );
    } else if (_selectedTab == 1) {
      final postsAsync = ref.watch(searchPostsProvider(_searchQuery));
      return AppAsyncValueView<List<SearchPost>>(
        value: postsAsync,
        fallbackContext: 'posts',
        isEmpty: (posts) => posts.isEmpty,
        empty: const AppEmptyView(
          title: 'No posts found',
          message: 'Try a broader keyword or switch tabs.',
        ),
        data: (posts) => ListView.separated(
          itemCount: posts.length,
          separatorBuilder: (__, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final post = posts[index];
            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
            return PostCard(
              post: PostModel(
                id: post.id,
                userId: post.authorId,
                text: post.content,
                authorName: post.authorName,
                authorAvatarUrl: post.authorAvatarUrl,
                likeCount: post.likeCount,
                createdAt: post.createdAt,
              ),
              currentUserId: uid,
            );
          },
        ),
      );
    } else {
      final hashtagsAsync = ref.watch(searchHashtagsProvider(_searchQuery));
      return AppAsyncValueView<List<SearchHashtag>>(
        value: hashtagsAsync,
        fallbackContext: 'hashtags',
        isEmpty: (hashtags) => hashtags.isEmpty,
        empty: const AppEmptyView(
          title: 'No hashtags found',
          message: 'Try a different hashtag or phrase.',
        ),
        data: (hashtags) => ListView.separated(
          itemCount: hashtags.length,
          separatorBuilder: (__, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final tag = hashtags[index];
            return ListTile(
              leading: const Icon(Icons.tag),
              title: Text('#${tag.hashtag}'),
              subtitle: Text('${tag.postCount} posts'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navigate to hashtag feed
              },
            );
          },
        ),
      );
    }
  }
}

class _FriendRequestButton extends ConsumerStatefulWidget {
  final String targetUserId;
  const _FriendRequestButton({required this.targetUserId});

  @override
  ConsumerState<_FriendRequestButton> createState() =>
      _FriendRequestButtonState();
}

class _FriendRequestButtonState extends ConsumerState<_FriendRequestButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isEmpty || currentUid == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    final friendIds =
        ref.watch(currentFriendIdsProvider).valueOrNull ?? const [];
    final pendingIds =
        ref.watch(pendingOutgoingFriendRequestIdsProvider).valueOrNull ??
            const <String>{};

    if (friendIds.contains(widget.targetUserId)) {
      return const SizedBox.shrink(); // already friends
    }

    final isPending = pendingIds.contains(widget.targetUserId);

    return IconButton(
      tooltip: isPending ? 'Friend request sent' : 'Add friend',
      icon: Icon(
        isPending ? Icons.schedule_rounded : Icons.person_add_alt_1_rounded,
        size: 20,
        color: isPending ? Colors.grey : Theme.of(context).colorScheme.primary,
      ),
      onPressed: isPending || _busy
          ? null
          : () async {
              setState(() => _busy = true);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(friendServiceProvider)
                    .sendFriendRequest(currentUid, widget.targetUserId);
                ref.invalidate(pendingOutgoingFriendRequestIdsProvider);
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Friend request sent!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Could not send request: $e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  final String targetUserId;
  const _FollowButton({required this.targetUserId});

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool? _optimisticFollowing;

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isEmpty || currentUid == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    final isFollowingAsync = ref.watch(
      isFollowingProvider((
        currentUserId: currentUid,
        targetUserId: widget.targetUserId,
      )),
    );

    final isFollowing =
        _optimisticFollowing ?? isFollowingAsync.valueOrNull ?? false;

    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(72, 32),
      ),
      onPressed: () async {
        setState(() => _optimisticFollowing = !isFollowing);
        final controller = ref.read(followControllerProvider);
        try {
          if (isFollowing) {
            await controller.unfollowUser(
              currentUserId: currentUid,
              targetUserId: widget.targetUserId,
            );
          } else {
            await controller.followUser(
              currentUserId: currentUid,
              targetUserId: widget.targetUserId,
              targetUsername: '',
            );
          }
        } catch (_) {
          if (mounted) setState(() => _optimisticFollowing = isFollowing);
        }
      },
      child: Text(isFollowing ? 'Following' : 'Follow'),
    );
  }
}

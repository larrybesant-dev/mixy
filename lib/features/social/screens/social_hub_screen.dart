import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../models/user_model.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../widgets/safe_network_avatar.dart';
import '../../connections/pending_requests_screen.dart';
import '../../friends/panes/friends_pane_view.dart';
import '../../friends/providers/friends_providers.dart';

enum _SocialList { followers, following, topEight }

class SocialHubScreen extends ConsumerWidget {
  const SocialHubScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(userProvider)?.id ?? '';
    final incomingCount =
        ref.watch(incomingFriendRequestsProvider).valueOrNull?.length ?? 0;

    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: AppPageScaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Social',
                style: GoogleFonts.playfairDisplay(
                  color: VelvetNoir.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Friends, requests, and new people',
                style: GoogleFonts.raleway(
                  color: VelvetNoir.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Find people',
              onPressed: () => context.push('/home/people'),
              icon: const Icon(Icons.person_search_rounded),
            ),
            PopupMenuButton<_SocialList>(
              tooltip: 'More social lists',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (selection) {
                switch (selection) {
                  case _SocialList.followers:
                    context.push('/profile/followers/$userId');
                  case _SocialList.following:
                    context.push('/profile/following/$userId');
                  case _SocialList.topEight:
                    context.push('/profile/manage-top-8');
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _SocialList.followers,
                  child: ListTile(
                    leading: Icon(Icons.groups_2_outlined),
                    title: Text('Followers'),
                  ),
                ),
                PopupMenuItem(
                  value: _SocialList.following,
                  child: ListTile(
                    leading: Icon(Icons.person_add_alt_rounded),
                    title: Text('Following'),
                  ),
                ),
                PopupMenuItem(
                  value: _SocialList.topEight,
                  child: ListTile(
                    leading: Icon(Icons.star_outline_rounded),
                    title: Text('Top 8'),
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.people_outline), text: 'Friends'),
              Tab(
                icon: Badge(
                  isLabelVisible: incomingCount > 0,
                  label: Text('$incomingCount'),
                  child: const Icon(Icons.mark_email_unread_outlined),
                ),
                text: 'Requests',
              ),
              const Tab(
                icon: Icon(Icons.travel_explore_rounded),
                text: 'Discover',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FriendsPaneView(showHeader: false),
            FriendRequestsView(),
            _PeopleDiscoveryView(),
          ],
        ),
      ),
    );
  }
}

class _PeopleDiscoveryView extends ConsumerStatefulWidget {
  const _PeopleDiscoveryView();

  @override
  ConsumerState<_PeopleDiscoveryView> createState() =>
      _PeopleDiscoveryViewState();
}

class _PeopleDiscoveryViewState extends ConsumerState<_PeopleDiscoveryView> {
  final Set<String> _sendingToUserIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final suggestions = ref.watch(friendSuggestionsProvider);
    return suggestions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _DiscoveryEmptyView(
        icon: Icons.cloud_off_outlined,
        title: 'Suggestions unavailable',
        message: 'Search for people while suggestions refresh.',
        actionLabel: 'Search people',
        onAction: () => context.push('/home/people'),
      ),
      data: (users) {
        if (users.isEmpty) {
          return _DiscoveryEmptyView(
            icon: Icons.person_search_outlined,
            title: 'Meet someone new',
            message: 'Search by name to find people you already know.',
            actionLabel: 'Search people',
            onAction: () => context.push('/home/people'),
          );
        }

        final batchKey = buildFriendPresenceBatchKey(
          users.map((user) => user.id),
        );
        final presenceAsync = ref.watch(
          friendPresenceBatchProvider(batchKey),
        );
        final presenceById = presenceAsync.valueOrNull;
        final onlineCount = presenceById == null
            ? 0
            : users
                .where((user) => presenceById[user.id]?.online == true)
                .length;

        return Column(
          children: [
            _DiscoveryPresenceSummary(
              isLoading: presenceAsync.isLoading,
              hasError: presenceAsync.hasError,
              onlineCount: onlineCount,
              offlineCount: users.length - onlineCount,
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: users.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isSending = _sendingToUserIds.contains(user.id);
                  final isOnline = presenceById?[user.id]?.online;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: VelvetNoir.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: VelvetNoir.outlineVariant),
                    ),
                    child: ListTile(
                      onTap: () => context.push('/profile/${user.id}'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      leading: SafeNetworkAvatar(
                        radius: 24,
                        avatarUrl: user.avatarUrl,
                        fallbackText:
                            user.username.characters.first.toUpperCase(),
                      ),
                      title: Text(
                        user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: VelvetNoir.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _suggestionSubtitle(user, isOnline: isOnline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isOnline == true
                              ? const Color(0xFF22C55E)
                              : VelvetNoir.onSurfaceVariant,
                        ),
                      ),
                      trailing: IconButton.filledTonal(
                        tooltip: isSending ? 'Sending request' : 'Add friend',
                        onPressed: isSending ? null : () => _sendRequest(user),
                        icon: isSending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.person_add_alt_1_rounded),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _suggestionSubtitle(UserModel user, {required bool? isOnline}) {
    final status = switch (isOnline) {
      true => 'Online',
      false => 'Offline',
      null => 'Checking activity',
    };
    final location = (user.location ?? '').trim();
    if (location.isNotEmpty) return '$status · $location';
    if (user.interests.isNotEmpty) {
      return '$status · ${user.interests.take(3).join(' · ')}';
    }
    return status;
  }

  Future<void> _sendRequest(UserModel user) async {
    final currentUserId = ref.read(currentFriendUserIdProvider);
    if (currentUserId == null || currentUserId.isEmpty) return;

    setState(() => _sendingToUserIds.add(user.id));
    try {
      await ref
          .read(friendServiceProvider)
          .sendFriendRequest(currentUserId, user.id);
      ref.invalidate(friendSuggestionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to ${user.username}.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send friend request.')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingToUserIds.remove(user.id));
      }
    }
  }
}

class _DiscoveryPresenceSummary extends StatelessWidget {
  const _DiscoveryPresenceSummary({
    required this.isLoading,
    required this.hasError,
    required this.onlineCount,
    required this.offlineCount,
  });

  final bool isLoading;
  final bool hasError;
  final int onlineCount;
  final int offlineCount;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (hasError) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Activity status unavailable',
            style: TextStyle(color: VelvetNoir.onSurfaceVariant),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _PresenceCount(
            color: const Color(0xFF22C55E),
            label: '$onlineCount online',
          ),
          const SizedBox(width: 18),
          _PresenceCount(
            color: VelvetNoir.onSurfaceVariant,
            label: '$offlineCount offline',
          ),
        ],
      ),
    );
  }
}

class _PresenceCount extends StatelessWidget {
  const _PresenceCount({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DiscoveryEmptyView extends StatelessWidget {
  const _DiscoveryEmptyView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: VelvetNoir.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: VelvetNoir.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: VelvetNoir.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.search_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

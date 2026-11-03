import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../models/user_model.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../utils/error_reporting.dart';
import '../../friends/providers/friends_providers.dart';
import '../../profile/widgets/profile_card.dart';
import '../../profile/widgets/social_user_card.dart';
import '../models/discovery_preferences.dart';
import '../providers/discovery_provider.dart';
import '../widgets/discovery_filter_sheet.dart';

bool matchesDiscoveryPreferences(
  UserModel candidate,
  DiscoveryPreferences preferences,
) {
  final age = candidate.age;
  if (age != null && (age < preferences.minAge || age > preferences.maxAge)) {
    return false;
  }
  if (preferences.interestTags.isEmpty) return true;
  final desired = preferences.interestTags
      .map((tag) => tag.trim().toLowerCase())
      .where((tag) => tag.isNotEmpty)
      .toSet();
  final candidateInterests =
      candidate.interests.map((tag) => tag.trim().toLowerCase()).toSet();
  return desired.intersection(candidateInterests).isNotEmpty;
}

class PersistentDiscoveryScreen extends ConsumerStatefulWidget {
  const PersistentDiscoveryScreen({super.key});

  @override
  ConsumerState<PersistentDiscoveryScreen> createState() =>
      _PersistentDiscoveryScreenState();
}

class _PersistentDiscoveryScreenState
    extends ConsumerState<PersistentDiscoveryScreen> {
  final Set<String> _busyUserIds = <String>{};
  final Set<String> _sentUserIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(userProvider);
    final userId = currentUser?.id ?? '';

    if (userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Discover')),
        body: const Center(child: Text('Please log in')),
      );
    }

    final preferencesAsync = ref.watch(discoveryPreferencesProvider(userId));
    final suggestionsAsync = ref.watch(friendSuggestionsProvider);
    final preferences =
        preferencesAsync.valueOrNull ?? DiscoveryPreferences(userId: userId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            onPressed: () => _showFilterSheet(context, userId),
            tooltip: 'Filter Preferences',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfo(context),
            tooltip: 'About Discovery',
          ),
        ],
      ),
      body: suggestionsAsync.when(
        loading: () => const AppLoadingView(label: 'Finding people'),
        error: (error, _) => AppErrorView(
          error: error,
          fallbackContext: 'Unable to load Discovery.',
          onRetry: _refresh,
        ),
        data: (suggestions) {
          final candidates = suggestions
              .where((user) => !_sentUserIds.contains(user.id))
              .where((user) => matchesDiscoveryPreferences(user, preferences))
              .toList(growable: false);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1050
                    ? 3
                    : constraints.maxWidth >= 680
                        ? 2
                        : 1;
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _DiscoverySummary(
                        preferences: preferences,
                        resultCount: candidates.length,
                        onEditFilters: () => _showFilterSheet(context, userId),
                      ),
                    ),
                    if (candidates.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppEmptyView(
                          title: 'No new people right now',
                          message:
                              'Try broader filters or pull down to refresh.',
                          icon: Icons.people_outline,
                          action: FilledButton.icon(
                            onPressed: () => _showFilterSheet(context, userId),
                            icon: const Icon(Icons.tune),
                            label: const Text('Adjust filters'),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        sliver: SliverGrid.builder(
                          itemCount: candidates.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 178,
                          ),
                          itemBuilder: (context, index) {
                            final candidate = candidates[index];
                            final busy = _busyUserIds.contains(candidate.id);
                            return SocialUserCard(
                              displayName: candidate.username,
                              username:
                                  '@${candidate.username.toLowerCase().replaceAll(' ', '')}',
                              avatarUrl: candidate.avatarUrl,
                              statusText:
                                  candidate.location?.trim().isNotEmpty == true
                                      ? candidate.location!
                                      : 'Open profile to learn more',
                              presenceState: ProfilePresenceState.offline,
                              primaryLabel: 'View profile',
                              onPrimaryPressed: () =>
                                  context.push('/profile/${candidate.id}'),
                              secondaryLabel: busy ? 'Sending...' : 'Connect',
                              onSecondaryPressed: busy
                                  ? () {}
                                  : () => _sendRequest(
                                        userId,
                                        candidate.id,
                                        candidate.username,
                                      ),
                              onTap: () =>
                                  context.push('/profile/${candidate.id}'),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendRequest(
    String currentUserId,
    String candidateId,
    String candidateName,
  ) async {
    setState(() => _busyUserIds.add(candidateId));
    try {
      await ref
          .read(friendServiceProvider)
          .sendFriendRequest(currentUserId, candidateId);
      if (!mounted) return;
      setState(() => _sentUserIds.add(candidateId));
      ref.invalidate(friendSuggestionsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to $candidateName.')),
      );
    } catch (error, stackTrace) {
      reportError(error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send this friend request. Try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyUserIds.remove(candidateId));
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(friendSuggestionsProvider);
    final userId = ref.read(userProvider)?.id;
    if (userId != null && userId.isNotEmpty) {
      ref.invalidate(discoveryPreferencesProvider(userId));
    }
    await ref.read(friendSuggestionsProvider.future);
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Discovery'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('👤 View profiles before deciding to connect'),
            SizedBox(height: 12),
            Text('🤝 Connect — Send a friend request'),
            SizedBox(height: 12),
            Text('Use filters to focus on people with shared interests.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, String userId) {
    final preferences =
        ref.read(discoveryPreferencesProvider(userId)).valueOrNull;
    if (preferences == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discovery filters are still loading.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DiscoveryFilterSheet(
        userId: userId,
        preferences: preferences,
        onApply: () {
          ref.invalidate(discoveryPreferencesProvider(userId));
          ref.invalidate(friendSuggestionsProvider);
        },
      ),
    );
  }
}

class _DiscoverySummary extends StatelessWidget {
  const _DiscoverySummary({
    required this.preferences,
    required this.resultCount,
    required this.onEditFilters,
  });

  final DiscoveryPreferences preferences;
  final int resultCount;
  final VoidCallback onEditFilters;

  @override
  Widget build(BuildContext context) {
    final interestText = preferences.interestTags.isEmpty
        ? 'all interests'
        : preferences.interestTags.take(3).join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: VelvetNoir.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: VelvetNoir.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$resultCount people to discover',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ages ${preferences.minAge}-${preferences.maxAge} · $interestText',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onEditFilters,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

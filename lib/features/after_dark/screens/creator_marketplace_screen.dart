import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_layout.dart';
import '../../../services/creator_subscription_service.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../providers/creator_subscription_provider.dart';
import '../theme/after_dark_theme.dart';

class CreatorMarketplaceScreen extends ConsumerStatefulWidget {
  const CreatorMarketplaceScreen({super.key});

  @override
  ConsumerState<CreatorMarketplaceScreen> createState() =>
      _CreatorMarketplaceScreenState();
}

class _CreatorMarketplaceScreenState
    extends ConsumerState<CreatorMarketplaceScreen> {
  final _searchController = TextEditingController();
  late Future<List<CreatorMarketplaceEntry>> _creatorsFuture;

  @override
  void initState() {
    super.initState();
    _creatorsFuture = _load();
  }

  Future<List<CreatorMarketplaceEntry>> _load() {
    return ref
        .read(creatorSubscriptionServiceProvider)
        .listCreatorSubscriptionMarketplace(
          query: _searchController.text.trim(),
        );
  }

  void _refresh() {
    setState(() => _creatorsFuture = _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      backgroundColor: EmberDark.surface,
      appBar: AppBar(
        backgroundColor: EmberDark.surface,
        foregroundColor: EmberDark.onSurface,
        title: const Text('Creator Memberships'),
        actions: [
          IconButton(
            tooltip: 'Manage my creator offer',
            onPressed: () => context.go('/after-dark/creator-subscriptions'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await _creatorsFuture;
        },
        child: ListView(
          padding: EdgeInsets.all(context.pageHorizontalPadding),
          children: [
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _refresh(),
              decoration: InputDecoration(
                hintText: 'Search creators',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _refresh,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<CreatorMarketplaceEntry>>(
              future: _creatorsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return _MarketplaceMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'Creators are unavailable',
                    message: 'Pull to refresh or try again shortly.',
                    actionLabel: 'Try again',
                    onAction: _refresh,
                  );
                }
                final creators =
                    snapshot.data ?? const <CreatorMarketplaceEntry>[];
                if (creators.isEmpty) {
                  return _MarketplaceMessage(
                    icon: Icons.workspace_premium_outlined,
                    title: 'No creators found',
                    message: _searchController.text.trim().isEmpty
                        ? 'Creators with active offers will appear here.'
                        : 'Try a different creator name.',
                    actionLabel: _searchController.text.trim().isEmpty
                        ? null
                        : 'Clear search',
                    onAction: _searchController.text.trim().isEmpty
                        ? null
                        : () {
                            _searchController.clear();
                            _refresh();
                          },
                  );
                }
                return Column(
                  children: [
                    for (final creator in creators) ...[
                      _CreatorCard(
                        creator: creator,
                        onOpen: () => context.go(
                          '/after-dark/creator-subscriptions/${creator.creatorId}',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatorCard extends StatelessWidget {
  const _CreatorCard({required this.creator, required this.onOpen});

  final CreatorMarketplaceEntry creator;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EmberDark.surfaceHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: EmberDark.primaryDim,
                backgroundImage: creator.avatarUrl.isEmpty
                    ? null
                    : NetworkImage(creator.avatarUrl),
                child: creator.avatarUrl.isEmpty
                    ? Text(
                        creator.displayName.isEmpty
                            ? 'M'
                            : creator.displayName.characters.first
                                .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            creator.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: EmberDark.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: EmberDark.secondary,
                          size: 17,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${(creator.offer.monthlyPriceCents / 100).toStringAsFixed(2)}/month - ${creator.subscriberCount} subscribers',
                      style: const TextStyle(
                        color: EmberDark.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    if (creator.offer.benefits.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        creator.offer.benefits.first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: EmberDark.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: EmberDark.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketplaceMessage extends StatelessWidget {
  const _MarketplaceMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, color: EmberDark.onSurfaceVariant, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: EmberDark.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: EmberDark.onSurfaceVariant),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

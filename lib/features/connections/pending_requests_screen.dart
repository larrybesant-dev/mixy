import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../widgets/safe_network_avatar.dart';
import '../friends/providers/friends_providers.dart';

class PendingRequestsScreen extends StatelessWidget {
  const PendingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(title: Text('Friend Requests')),
      body: const FriendRequestsView(),
    );
  }
}

class FriendRequestsView extends ConsumerStatefulWidget {
  const FriendRequestsView({super.key});

  @override
  ConsumerState<FriendRequestsView> createState() => _FriendRequestsViewState();
}

class _FriendRequestsViewState extends ConsumerState<FriendRequestsView> {
  final Set<String> _busyRequestIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final incoming = ref.watch(incomingFriendRequestsProvider);
    final outgoing = ref.watch(outgoingFriendRequestsProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: VelvetNoir.surfaceLow,
            child: TabBar(
              tabs: [
                Tab(text: 'Incoming (${incoming.valueOrNull?.length ?? 0})'),
                Tab(text: 'Sent (${outgoing.valueOrNull?.length ?? 0})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                incoming.when(
                  loading: () => const _RequestLoadingView(),
                  error: (error, stackTrace) => const _RequestErrorView(),
                  data: _buildIncomingRequests,
                ),
                outgoing.when(
                  loading: () => const _RequestLoadingView(),
                  error: (error, stackTrace) => const _RequestErrorView(),
                  data: _buildOutgoingRequests,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequests(List<IncomingFriendRequestEntry> requests) {
    if (requests.isEmpty) {
      return const _EmptyRequestsView(
        icon: Icons.mark_email_read_outlined,
        title: 'No incoming requests',
        message: 'New friend requests will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = requests[index];
        final user = entry.fromUser;
        final requestId = entry.request.id;
        return _FriendRequestTile(
          user: user,
          subtitle: 'Wants to connect with you',
          isBusy: _busyRequestIds.contains(requestId),
          onTap: () => context.push('/profile/${entry.request.fromUserId}'),
          actions: [
            IconButton.filled(
              tooltip: 'Accept request',
              onPressed: _busyRequestIds.contains(requestId)
                  ? null
                  : () => _respondToRequest(
                        requestId,
                        accept: true,
                        username: user?.username,
                      ),
              icon: const Icon(Icons.check_rounded),
            ),
            IconButton.outlined(
              tooltip: 'Decline request',
              onPressed: _busyRequestIds.contains(requestId)
                  ? null
                  : () => _respondToRequest(
                        requestId,
                        accept: false,
                        username: user?.username,
                      ),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOutgoingRequests(List<OutgoingFriendRequestEntry> requests) {
    if (requests.isEmpty) {
      return const _EmptyRequestsView(
        icon: Icons.outgoing_mail,
        title: 'No sent requests',
        message: 'Requests you send will stay here until accepted.',
      );
    }

    final currentUserId = ref.read(currentFriendUserIdProvider) ?? '';
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = requests[index];
        final user = entry.toUser;
        final requestId = entry.friendship.id;
        final recipientId = entry.friendship.otherUserId(currentUserId);
        return _FriendRequestTile(
          user: user,
          subtitle: 'Waiting for a response',
          isBusy: _busyRequestIds.contains(requestId),
          onTap: () => context.push('/profile/$recipientId'),
          actions: [
            IconButton.outlined(
              tooltip: 'Cancel request',
              onPressed: _busyRequestIds.contains(requestId)
                  ? null
                  : () => _cancelRequest(requestId),
              icon: const Icon(Icons.undo_rounded),
            ),
          ],
        );
      },
    );
  }

  Future<void> _respondToRequest(
    String requestId, {
    required bool accept,
    String? username,
  }) async {
    setState(() => _busyRequestIds.add(requestId));
    try {
      final service = ref.read(friendServiceProvider);
      if (accept) {
        await service.acceptFriendRequest(requestId);
      } else {
        await service.declineFriendRequest(requestId);
      }
      if (!mounted) return;
      final displayName = (username ?? '').trim();
      final action = accept ? 'accepted' : 'declined';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            displayName.isEmpty
                ? 'Friend request $action.'
                : 'Friend request from $displayName $action.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this request.')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyRequestIds.remove(requestId));
      }
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    setState(() => _busyRequestIds.add(requestId));
    try {
      await ref.read(friendServiceProvider).declineFriendRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request canceled.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not cancel this request.')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyRequestIds.remove(requestId));
      }
    }
  }
}

class _FriendRequestTile extends StatelessWidget {
  const _FriendRequestTile({
    required this.user,
    required this.subtitle,
    required this.isBusy,
    required this.onTap,
    required this.actions,
  });

  final UserModel? user;
  final String subtitle;
  final bool isBusy;
  final VoidCallback onTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final username = (user?.username ?? '').trim();
    final displayName = username.isEmpty ? 'MixVy member' : username;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VelvetNoir.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: SafeNetworkAvatar(
          radius: 24,
          avatarUrl: user?.avatarUrl,
          fallbackText: displayName.characters.first.toUpperCase(),
        ),
        title: Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: VelvetNoir.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: VelvetNoir.onSurfaceVariant),
        ),
        trailing: isBusy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(mainAxisSize: MainAxisSize.min, children: actions),
      ),
    );
  }
}

class _RequestLoadingView extends StatelessWidget {
  const _RequestLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _RequestErrorView extends StatelessWidget {
  const _RequestErrorView();

  @override
  Widget build(BuildContext context) {
    return const _EmptyRequestsView(
      icon: Icons.cloud_off_outlined,
      title: 'Requests unavailable',
      message: 'Check your connection and try again.',
    );
  }
}

class _EmptyRequestsView extends StatelessWidget {
  const _EmptyRequestsView({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
          ],
        ),
      ),
    );
  }
}

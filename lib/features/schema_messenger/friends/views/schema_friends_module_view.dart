import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme.dart';
import '../models/schema_friend_identity.dart';
import '../models/schema_friend_link.dart';
import '../models/schema_friend_presence.dart';
import '../providers/schema_friend_focus_anchor_provider.dart';
import '../providers/schema_friend_links_providers.dart';
import '../providers/schema_friend_presence_stability_provider.dart';
import '../providers/schema_friend_roster_provider.dart';
import '../providers/schema_friend_selection_provider.dart';
import '../widgets/schema_friend_tile.dart';

/// Component Name: SchemaFriendsModuleView
/// Firestore Read Paths: friend_links, users/{uid}, users/{uid}/profile_public/*, rooms/*/participants/*
/// Firestore Write Paths: friend_links/{uid_pair}
/// Allowed Fields: users, status, requestedBy, createdAt, updatedAt, username, email, avatarUrl, profileAccentColor, userId, userStatus, lastActiveAt, camOn, micOn
/// Forbidden Fields: users/{uid}.friends, users/{uid}.wallet*, users/{uid}.verification*, participants.role
class SchemaFriendsModuleView extends ConsumerStatefulWidget {
  const SchemaFriendsModuleView({
    super.key,
    this.onStartChat,
    this.onOpenProfile,
    this.onOpenRoom,
  });

  final void Function(
    String friendUserId,
    String friendUsername,
    String? friendAvatarUrl,
  )?
  onStartChat;
  final void Function(String friendUserId)? onOpenProfile;
  final void Function(String roomId)? onOpenRoom;

  @override
  ConsumerState<SchemaFriendsModuleView> createState() =>
      _SchemaFriendsModuleViewState();
}

class _SchemaFriendsModuleViewState
    extends ConsumerState<SchemaFriendsModuleView> {
  static const Duration _scrollLockDuration = Duration(milliseconds: 320);

  late final ScrollController _scrollController;
  final Map<String, GlobalKey> _friendRowKeys = <String, GlobalKey>{};
  bool _restoredInitialOffset = false;
  bool _bootSequenceCompleted = false;
  bool _systemScrollInFlight = false;
  DateTime _scrollLockUntil = DateTime.fromMillisecondsSinceEpoch(0);
  String? _queuedAnchorFriendId;
  String? _lastViewportAnchoredFriendId;

  @override
  void initState() {
    super.initState();
    final initialOffset = ref
        .read(schemaFriendFocusAnchorProvider)
        .scrollOffset;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
    _scrollController.addListener(_persistScrollOffset);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_persistScrollOffset);
    _scrollController.dispose();
    super.dispose();
  }

  void _persistScrollOffset() {
    if (_isScrollLocked) {
      return;
    }

    ref
        .read(schemaFriendFocusAnchorProvider.notifier)
        .rememberScrollOffset(_scrollController.offset);
  }

  bool get _isScrollLocked {
    if (_systemScrollInFlight) {
      return true;
    }
    return DateTime.now().isBefore(_scrollLockUntil);
  }

  void _lockScrollTemporarily([Duration duration = _scrollLockDuration]) {
    _scrollLockUntil = DateTime.now().add(duration);
  }

  GlobalKey _rowKeyFor(String friendId) {
    return _friendRowKeys.putIfAbsent(friendId, GlobalKey.new);
  }

  void _updateSelection(String friendId) {
    ref.read(selectedSchemaFriendIdProvider.notifier).state = friendId;
    ref
        .read(schemaFriendFocusAnchorProvider.notifier)
        .setFocusedFriend(friendId);
  }

  void _queueAnchorSync(String? friendId) {
    if (friendId == null || friendId.isEmpty) {
      return;
    }
    _queuedAnchorFriendId = friendId;
  }

  void _flushQueuedAnchorSync() {
    final friendId = _queuedAnchorFriendId;
    if (friendId == null || friendId.isEmpty) {
      return;
    }
    _queuedAnchorFriendId = null;
    _syncViewportAnchor(friendId);
  }

  Future<void> _runSystemScroll(Future<void> Function() action) async {
    if (!mounted || _systemScrollInFlight) {
      return;
    }

    _systemScrollInFlight = true;
    _lockScrollTemporarily();
    try {
      await action();
    } finally {
      Future<void>.delayed(_scrollLockDuration, () {
        if (!mounted) {
          return;
        }
        _systemScrollInFlight = false;
        _flushQueuedAnchorSync();
      });
    }
  }

  void _runBootSequence({
    required String? selectedFriendId,
    required SchemaGroupedFriendRoster groupedRoster,
  }) {
    if (_bootSequenceCompleted || !mounted) {
      return;
    }

    if (groupedRoster.totalAcceptedCount == 0) {
      return;
    }

    _bootSequenceCompleted = true;
    final bootFriendId = selectedFriendId;
    if (bootFriendId != null && bootFriendId.isNotEmpty) {
      ref
          .read(schemaFriendFocusAnchorProvider.notifier)
          .setFocusedFriend(bootFriendId, updateInteractionTime: false);
      _syncViewportAnchor(bootFriendId);
      return;
    }

    if (_restoredInitialOffset) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final savedOffset = ref
          .read(schemaFriendFocusAnchorProvider)
          .scrollOffset;
      final maxExtent = _scrollController.position.maxScrollExtent;
      _runSystemScroll(() async {
        _scrollController.jumpTo(savedOffset.clamp(0, maxExtent));
      });
      _restoredInitialOffset = true;
    });
  }

  void _syncViewportAnchor(String? friendId) {
    if (!mounted) {
      return;
    }

    if (_isScrollLocked) {
      _queueAnchorSync(friendId);
      return;
    }

    if (friendId == null || friendId.isEmpty) {
      if (_restoredInitialOffset) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }
        final savedOffset = ref
            .read(schemaFriendFocusAnchorProvider)
            .scrollOffset;
        final maxExtent = _scrollController.position.maxScrollExtent;
        _runSystemScroll(() async {
          _scrollController.jumpTo(savedOffset.clamp(0, maxExtent));
        });
        _restoredInitialOffset = true;
      });
      return;
    }

    if (_lastViewportAnchoredFriendId == friendId && _restoredInitialOffset) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final targetContext = _friendRowKeys[friendId]?.currentContext;
      if (targetContext == null) {
        return;
      }
      _runSystemScroll(() async {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.16,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
        _lastViewportAnchoredFriendId = friendId;
        _restoredInitialOffset = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(effectiveSelectedSchemaFriendIdProvider, (_, next) {
      if (next != null && next.isNotEmpty) {
        ref
            .read(schemaFriendFocusAnchorProvider.notifier)
            .setFocusedFriend(next, updateInteractionTime: false);
      }
      _syncViewportAnchor(next);
    });

    final authUserId = ref.watch(schemaAuthUserIdProvider).valueOrNull;
    final linksAsync = ref.watch(schemaFriendLinksProvider);
    final selectedFriendId = ref.watch(effectiveSelectedSchemaFriendIdProvider);
    final groupedRosterAsync = ref.watch(
      schemaStickyGroupedFriendRosterProvider,
    );

    if (authUserId == null || authUserId.isEmpty) {
      return const Center(
        child: Text(
          'Sign in to load your friend graph.',
          style: TextStyle(color: VelvetNoir.onSurfaceVariant),
        ),
      );
    }

    return linksAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: VelvetNoir.primary),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Could not load friend links: $error',
            style: const TextStyle(color: VelvetNoir.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (links) {
        final incoming = links
            .where((l) => l.isPending && l.requestedBy != authUserId)
            .toList(growable: false);
        final outgoing = links
            .where((l) => l.isPending && l.requestedBy == authUserId)
            .toList(growable: false);
        final accepted = links
            .where((l) => l.isAccepted)
            .toList(growable: false);
        final groupedRoster =
            groupedRosterAsync.valueOrNull ??
            SchemaGroupedFriendRoster(
              inRooms: const <SchemaResolvedFriendEntry>[],
              online: const <SchemaResolvedFriendEntry>[],
              offline: const <SchemaResolvedFriendEntry>[],
              loadingCount: accepted.length,
              totalAcceptedCount: accepted.length,
            );

        _runBootSequence(
          selectedFriendId: selectedFriendId,
          groupedRoster: groupedRoster,
        );

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          children: [
            _CompactSummaryBar(
              totalFriends: groupedRoster.totalAcceptedCount,
              liveFriends: groupedRoster.liveCount,
              inRoomsFriends: groupedRoster.inRooms.length,
              pendingIncoming: incoming.length,
            ),
            if (incoming.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _RosterHeader(
                label: 'REQUESTS',
                color: VelvetNoir.primary,
                icon: Icons.mark_chat_unread_rounded,
              ),
              ...incoming.map(
                (link) => _FriendLinkRow(
                  key: ValueKey('incoming-${link.id}'),
                  link: link,
                  currentUserId: authUserId,
                  density: FriendRowDensity.compact,
                  actionBuilder: (identity, presence) => TextButton(
                    onPressed: () => ref
                        .read(schemaFriendLinksControllerProvider)
                        .acceptRequest(linkId: link.id),
                    style: TextButton.styleFrom(
                      foregroundColor: VelvetNoir.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Accept'),
                  ),
                  onOpenProfile: widget.onOpenProfile,
                  onOpenRoom: widget.onOpenRoom,
                ),
              ),
            ],
            if (outgoing.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _RosterHeader(
                label: 'SENT',
                color: VelvetNoir.onSurfaceVariant,
                icon: Icons.schedule_send_rounded,
              ),
              ...outgoing.map(
                (link) => _FriendLinkRow(
                  key: ValueKey('outgoing-${link.id}'),
                  link: link,
                  currentUserId: authUserId,
                  density: FriendRowDensity.compact,
                  actionBuilder: (identity, presence) => const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text(
                      'Pending',
                      style: TextStyle(
                        color: VelvetNoir.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  onOpenProfile: widget.onOpenProfile,
                  onOpenRoom: widget.onOpenRoom,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (groupedRoster.totalAcceptedCount == 0)
              const _EmptyRosterState()
            else ...[
              _RosterHeader(
                label: 'IN ROOMS',
                count: groupedRoster.inRooms.length,
                color: VelvetNoir.primary,
                icon: Icons.headset_mic_rounded,
              ),
              ...groupedRoster.inRooms.map(
                (entry) => _ResolvedFriendRow(
                  key: _rowKeyFor(entry.identity.userId),
                  entry: entry,
                  density: FriendRowDensity.dense,
                  isSelected: selectedFriendId == entry.identity.userId,
                  onSelected: () => _updateSelection(entry.identity.userId),
                  onStartChat: widget.onStartChat,
                  onOpenProfile: widget.onOpenProfile,
                  onOpenRoom: widget.onOpenRoom,
                ),
              ),
              _RosterHeader(
                label: 'ONLINE',
                count: groupedRoster.online.length,
                color: const Color(0xFF34D399),
                icon: Icons.circle,
              ),
              ...groupedRoster.online.map(
                (entry) => _ResolvedFriendRow(
                  key: _rowKeyFor(entry.identity.userId),
                  entry: entry,
                  density: FriendRowDensity.dense,
                  isSelected: selectedFriendId == entry.identity.userId,
                  onSelected: () => _updateSelection(entry.identity.userId),
                  onStartChat: widget.onStartChat,
                  onOpenProfile: widget.onOpenProfile,
                  onOpenRoom: widget.onOpenRoom,
                ),
              ),
              _RosterHeader(
                label: 'OFFLINE',
                count: groupedRoster.offline.length,
                color: VelvetNoir.onSurfaceVariant,
                icon: Icons.circle_outlined,
              ),
              ...groupedRoster.offline.map(
                (entry) => _ResolvedFriendRow(
                  key: _rowKeyFor(entry.identity.userId),
                  entry: entry,
                  density: FriendRowDensity.dense,
                  isSelected: selectedFriendId == entry.identity.userId,
                  onSelected: () => _updateSelection(entry.identity.userId),
                  onStartChat: widget.onStartChat,
                  onOpenProfile: widget.onOpenProfile,
                  onOpenRoom: widget.onOpenRoom,
                ),
              ),
              if (groupedRoster.loadingCount > 0)
                _RosterSyncingRow(loadingCount: groupedRoster.loadingCount),
            ],
          ],
        );
      },
    );
  }
}

class _ResolvedFriendRow extends StatelessWidget {
  const _ResolvedFriendRow({
    super.key,
    required this.entry,
    required this.density,
    required this.isSelected,
    required this.onSelected,
    this.onStartChat,
    this.onOpenProfile,
    this.onOpenRoom,
  });

  final SchemaResolvedFriendEntry entry;
  final FriendRowDensity density;
  final bool isSelected;
  final VoidCallback onSelected;
  final void Function(
    String friendUserId,
    String friendUsername,
    String? friendAvatarUrl,
  )?
  onStartChat;
  final void Function(String friendUserId)? onOpenProfile;
  final void Function(String roomId)? onOpenRoom;

  @override
  Widget build(BuildContext context) {
    final roomId = entry.presence.roomId;
    final friendUserId = entry.identity.userId;
    final friendUsername = entry.identity.username;
    final friendAvatarUrl = entry.identity.avatarUrl;

    return Padding(
      padding: EdgeInsets.only(
        bottom: density == FriendRowDensity.dense ? 2 : 4,
      ),
      child: SchemaFriendTile(
        identity: entry.identity,
        presence: entry.presence,
        density: density,
        isSelected: isSelected,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (roomId != null && roomId.isNotEmpty && onOpenRoom != null)
              IconButton(
                tooltip: 'Join room',
                onPressed: () {
                  onSelected();
                  onOpenRoom!(roomId);
                },
                icon: const Icon(Icons.headset_mic_rounded, size: 18),
                color: VelvetNoir.primary,
                visualDensity: VisualDensity.compact,
              ),
            IconButton(
              tooltip: 'message',
              onPressed: onStartChat == null
                  ? null
                  : () {
                      onSelected();
                      onStartChat!(
                        friendUserId,
                        friendUsername,
                        friendAvatarUrl,
                      );
                    },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              color: VelvetNoir.onSurface,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        onTap: () {
          onSelected();
          if (onStartChat != null) {
            onStartChat!(friendUserId, friendUsername, friendAvatarUrl);
            return;
          }
          if (roomId != null && roomId.isNotEmpty && onOpenRoom != null) {
            onOpenRoom!(roomId);
            return;
          }
          if (onOpenProfile != null) {
            onOpenProfile!(friendUserId);
          }
        },
      ),
    );
  }
}

class _FriendLinkRow extends ConsumerWidget {
  const _FriendLinkRow({
    super.key,
    required this.link,
    required this.currentUserId,
    required this.actionBuilder,
    this.density = FriendRowDensity.dense,
    this.onOpenProfile,
    this.onOpenRoom,
  });

  final SchemaFriendLink link;
  final String currentUserId;
  final Widget Function(
    SchemaFriendIdentity identity,
    SchemaFriendPresence presence,
  )
  actionBuilder;
  final FriendRowDensity density;
  final void Function(String friendUserId)? onOpenProfile;
  final void Function(String roomId)? onOpenRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendUserId = link.otherUserId(currentUserId);
    final identityAsync = ref.watch(schemaFriendIdentityProvider(friendUserId));
    final presenceAsync = ref.watch(
      schemaStableFriendPresenceProvider(friendUserId),
    );

    final identity = identityAsync.valueOrNull;
    final presence = presenceAsync.valueOrNull;

    if (friendUserId.isEmpty) return const SizedBox.shrink();

    if (identity == null || presence == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Loading friend profile...',
          style: TextStyle(color: VelvetNoir.onSurfaceVariant, fontSize: 12),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: density == FriendRowDensity.dense ? 6 : 8,
      ),
      child: SchemaFriendTile(
        identity: identity,
        presence: presence,
        density: density,
        trailing: actionBuilder(identity, presence),
        onTap: () {
          final roomId = presence.roomId;
          if (roomId != null && roomId.isNotEmpty && onOpenRoom != null) {
            onOpenRoom!(roomId);
            return;
          }
          if (onOpenProfile != null) {
            onOpenProfile!(friendUserId);
          }
        },
      ),
    );
  }
}

class _CompactSummaryBar extends StatelessWidget {
  const _CompactSummaryBar({
    required this.totalFriends,
    required this.liveFriends,
    required this.inRoomsFriends,
    required this.pendingIncoming,
  });

  final int totalFriends;
  final int liveFriends;
  final int inRoomsFriends;
  final int pendingIncoming;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: VelvetNoir.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _SummaryChip(
            label: 'Friends',
            value: totalFriends.toString(),
            color: VelvetNoir.primary,
          ),
          _SummaryChip(
            label: 'Live',
            value: liveFriends.toString(),
            color: const Color(0xFF34D399),
          ),
          _SummaryChip(
            label: 'Rooms',
            value: inRoomsFriends.toString(),
            color: VelvetNoir.secondary,
          ),
          _SummaryChip(
            label: 'Requests',
            value: pendingIncoming.toString(),
            color: VelvetNoir.secondary,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$value ',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            TextSpan(
              text: label,
              style: const TextStyle(
                color: VelvetNoir.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterHeader extends StatelessWidget {
  const _RosterHeader({
    required this.label,
    required this.color,
    required this.icon,
    this.count,
  });

  final String label;
  final int? count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            count == null ? label : '$label  $count',
            style: TextStyle(
              color: color,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRosterState extends StatelessWidget {
  const _EmptyRosterState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
      child: Text(
        'No accepted friends yet.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: VelvetNoir.onSurfaceVariant),
      ),
    );
  }
}

class _RosterSyncingRow extends StatelessWidget {
  const _RosterSyncingRow({required this.loadingCount});

  final int loadingCount;

  @override
  Widget build(BuildContext context) {
    final label = loadingCount == 1 ? 'friend' : 'friends';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(
        'Syncing $loadingCount $label...',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: VelvetNoir.onSurfaceVariant),
      ),
    );
  }
}

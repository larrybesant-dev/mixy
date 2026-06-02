import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_layout.dart';
import '../../../core/theme.dart';
import '../../../models/user_model.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../services/notification_service.dart';
import '../../messaging/providers/messaging_provider.dart';
import '../models/friend_roster_entry.dart';
import '../providers/friends_providers.dart';
import '../widgets/friend_tile.dart';
import '../../../utils/presence_classifier.dart';

class FriendsPaneView extends ConsumerStatefulWidget {
  const FriendsPaneView({super.key, this.showHeader = true});

  final bool showHeader;

  @override
  ConsumerState<FriendsPaneView> createState() => _FriendsPaneViewState();
}

class _FriendsPaneViewState extends ConsumerState<FriendsPaneView> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _onlineExpanded = true;
  bool _inRoomsExpanded = true;
  bool _recentlyActiveExpanded = true;
  bool _offlineExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(friendRosterProvider);
    final currentUser = ref.watch(userProvider);
    final myPresence = ref.watch(currentUserPresenceProvider).valueOrNull;
    final myRoomId = myPresence?.inRoom;

    return rosterAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: VelvetNoir.primary),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Could not load friends right now. Please try again shortly.',
            style: const TextStyle(color: VelvetNoir.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No friends yet.',
                style: TextStyle(color: VelvetNoir.onSurfaceVariant),
              ),
            ),
          );
        }

        final q = _query.toLowerCase();
        final filtered = q.isEmpty
            ? entries
            : entries
                .where((e) => e.user.username.toLowerCase().contains(q))
                .toList(growable: false);

        final inRoomEntries = filtered
            .where((e) => (e.roomId ?? '').isNotEmpty)
            .toList(growable: false);
        final onlineEntries = filtered
            .where((e) => e.isOnline && (e.roomId ?? '').isEmpty)
            .toList(growable: false);
        final recentlyActiveEntries =
            filtered.where((e) => e.isRecentlyActive).toList(growable: false);
        final offlineEntries = filtered
            .where((e) => !e.isOnline && !e.isRecentlyActive)
            .toList(growable: false);
        final activeCount = onlineEntries.length + inRoomEntries.length;

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // ── Optional header ───────────────────────────────────────────
            if (widget.showHeader) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.pageHorizontalPadding,
                  24,
                  context.pageHorizontalPadding,
                  0,
                ),
                child: Text(
                  'Friends',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: VelvetNoir.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Search bar ────────────────────────────────────────────────
            _FriendSearchBar(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
            ),
            _PresenceOverviewCard(
              activeCount: activeCount,
              inRoomCount: inRoomEntries.length,
              offlineCount: offlineEntries.length,
              currentRoomId: myRoomId,
            ),

            if (filtered.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Text(
                  'No matches.',
                  style: TextStyle(
                    color: VelvetNoir.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ] else ...[
              // ── ONLINE ────────────────────────────────────────────────
              _RichSectionHeader(
                label: 'ONLINE',
                count: onlineEntries.length,
                accentColor: const Color(0xFF22C55E),
                isExpanded: _onlineExpanded,
                onToggle: () =>
                    setState(() => _onlineExpanded = !_onlineExpanded),
              ),
              if (_onlineExpanded) ...[
                if (onlineEntries.isEmpty)
                  const _EmptySectionLabel(
                    label: 'No friends online right now.',
                  )
                else
                  for (var i = 0; i < onlineEntries.length; i++) ...[
                    FriendTile(
                      key: ValueKey('online-${onlineEntries[i].friendId}'),
                      user: onlineEntries[i].user,
                      statusLabel: 'Online',
                      statusColor: const Color(0xFF22C55E),
                      actions: [
                        FriendTileAction(
                          label: 'message',
                          icon: Icons.chat_bubble_outline_rounded,
                          onPressed: () => _openConversation(
                            context,
                            currentUser,
                            onlineEntries[i].user,
                          ),
                        ),
                        if ((myRoomId ?? '').isNotEmpty)
                          FriendTileAction(
                            label: 'Invite',
                            icon: Icons.mail_outline_rounded,
                            onPressed: () => _inviteFriend(
                              context,
                              currentUser: currentUser,
                              friend: onlineEntries[i].user,
                              roomId: myRoomId!,
                            ),
                          ),
                      ],
                      onTap: () => _openConversation(
                        context,
                        currentUser,
                        onlineEntries[i].user,
                      ),
                    ),
                    if (i < onlineEntries.length - 1)
                      const Divider(
                        indent: 72,
                        height: 1,
                        color: Color(0x18F7EDE2),
                      ),
                  ],
              ],

              const SizedBox(height: 4),

              // ── IN ROOMS ──────────────────────────────────────────────
              _RichSectionHeader(
                label: 'IN ROOMS',
                count: inRoomEntries.length,
                accentColor: VelvetNoir.secondaryBright,
                isExpanded: _inRoomsExpanded,
                onToggle: () =>
                    setState(() => _inRoomsExpanded = !_inRoomsExpanded),
              ),
              if (_inRoomsExpanded) ...[
                if (inRoomEntries.isEmpty)
                  const _EmptySectionLabel(
                    label: 'No friends in rooms right now.',
                  )
                else
                  for (var i = 0; i < inRoomEntries.length; i++) ...[
                    FriendTile(
                      key: ValueKey('room-${inRoomEntries[i].friendId}'),
                      user: inRoomEntries[i].user,
                      statusLabel: 'In room ${inRoomEntries[i].roomId}',
                      statusColor: VelvetNoir.secondaryBright,
                      statusIcon: Icons.mic_rounded,
                      actions: [
                        FriendTileAction(
                          label: 'Join Room',
                          icon: Icons.meeting_room_rounded,
                          onPressed: () =>
                              context.go('/room/${inRoomEntries[i].roomId}'),
                        ),
                        FriendTileAction(
                          label: 'message',
                          icon: Icons.chat_bubble_outline_rounded,
                          onPressed: () => _openConversation(
                            context,
                            currentUser,
                            inRoomEntries[i].user,
                          ),
                        ),
                      ],
                      onTap: () =>
                          context.go('/room/${inRoomEntries[i].roomId}'),
                    ),
                    if (i < inRoomEntries.length - 1)
                      const Divider(
                        indent: 72,
                        height: 1,
                        color: Color(0x18F7EDE2),
                      ),
                  ],
              ],

              const SizedBox(height: 4),

              // ── RECENTLY ACTIVE ───────────────────────────────────────
              if (recentlyActiveEntries.isNotEmpty) ...[
                _RichSectionHeader(
                  label: 'RECENTLY ACTIVE',
                  count: recentlyActiveEntries.length,
                  accentColor: const Color(0xFFF59E0B),
                  isExpanded: _recentlyActiveExpanded,
                  onToggle: () => setState(
                    () => _recentlyActiveExpanded = !_recentlyActiveExpanded,
                  ),
                ),
                if (_recentlyActiveExpanded)
                  for (var i = 0; i < recentlyActiveEntries.length; i++) ...[
                    FriendTile(
                      key: ValueKey(
                        'recent-${recentlyActiveEntries[i].friendId}',
                      ),
                      user: recentlyActiveEntries[i].user,
                      statusLabel: _lastSeenLabel(recentlyActiveEntries[i]),
                      statusColor: const Color(0xFFF59E0B),
                      actions: [
                        FriendTileAction(
                          label: 'message',
                          icon: Icons.chat_bubble_outline_rounded,
                          onPressed: () => _openConversation(
                            context,
                            currentUser,
                            recentlyActiveEntries[i].user,
                          ),
                        ),
                      ],
                      onTap: () => _openConversation(
                        context,
                        currentUser,
                        recentlyActiveEntries[i].user,
                      ),
                    ),
                    if (i < recentlyActiveEntries.length - 1)
                      const Divider(
                        indent: 72,
                        height: 1,
                        color: Color(0x18F7EDE2),
                      ),
                  ],
                const SizedBox(height: 4),
              ],

              // ── OFFLINE ───────────────────────────────────────────────
              _RichSectionHeader(
                label: 'OFFLINE',
                count: offlineEntries.length,
                accentColor: VelvetNoir.onSurfaceVariant,
                isExpanded: _offlineExpanded,
                onToggle: () =>
                    setState(() => _offlineExpanded = !_offlineExpanded),
              ),
              if (_offlineExpanded) ...[
                if (offlineEntries.isEmpty)
                  const _EmptySectionLabel(label: 'No friends are offline.')
                else
                  for (var i = 0; i < offlineEntries.length; i++) ...[
                    FriendTile(
                      key: ValueKey('offline-${offlineEntries[i].friendId}'),
                      user: offlineEntries[i].user,
                      statusLabel: _lastSeenLabel(offlineEntries[i]),
                      statusColor: VelvetNoir.onSurfaceVariant,
                      actions: const [],
                      onTap: () => _openConversation(
                        context,
                        currentUser,
                        offlineEntries[i].user,
                      ),
                    ),
                    if (i < offlineEntries.length - 1)
                      const Divider(
                        indent: 72,
                        height: 1,
                        color: Color(0x18F7EDE2),
                      ),
                  ],
              ],
            ],
          ],
        );
      },
    );
  }

  Future<void> _openConversation(
    BuildContext context,
    UserModel? currentUser,
    UserModel friend,
  ) async {
    if (currentUser == null) return;

    try {
      final conversationId =
          await ref.read(messagingControllerProvider).createDirectConversation(
                userId1: currentUser.id,
                user1Name: currentUser.username,
                user1AvatarUrl: currentUser.avatarUrl,
                userId2: friend.id,
                user2Name: friend.username,
                user2AvatarUrl: friend.avatarUrl,
              );
      if (!context.mounted) return;
      context.go('/chat/$conversationId');
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open chat: $error')));
    }
  }

  Future<void> _inviteFriend(
    BuildContext context, {
    required UserModel? currentUser,
    required UserModel friend,
    required String roomId,
  }) async {
    if (currentUser == null) return;

    try {
      await NotificationService().sendRoomInviteToFriends(
        friendIds: [friend.id],
        inviterId: currentUser.id,
        inviterName: currentUser.username,
        roomId: roomId,
        roomName: "${currentUser.username}'s room",
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite sent to ${friend.username}.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send invite: $error')));
    }
  }

  String _lastSeenLabel(FriendRosterEntry entry) =>
      PresenceClassifier.lastSeenLabel(entry.lastSeen);
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _PresenceOverviewCard extends StatelessWidget {
  const _PresenceOverviewCard({
    required this.activeCount,
    required this.inRoomCount,
    required this.offlineCount,
    required this.currentRoomId,
  });

  final int activeCount;
  final int inRoomCount;
  final int offlineCount;
  final String? currentRoomId;

  @override
  Widget build(BuildContext context) {
    final hasCurrentRoom = (currentRoomId ?? '').trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: VelvetNoir.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Presence snapshot',
            style: TextStyle(
              color: VelvetNoir.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PresenceStatChip(
                label: '$activeCount active now',
                color: const Color(0xFF22C55E),
                icon: Icons.circle,
              ),
              _PresenceStatChip(
                label: '$inRoomCount in rooms',
                color: VelvetNoir.secondaryBright,
                icon: Icons.mic_rounded,
              ),
              _PresenceStatChip(
                label: '$offlineCount away',
                color: VelvetNoir.onSurfaceVariant,
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
          if (hasCurrentRoom) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/room/$currentRoomId'),
                icon: const Icon(Icons.meeting_room_rounded, size: 16),
                label: const Text('Back to my room'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: VelvetNoir.primary,
                  side: BorderSide(
                    color: VelvetNoir.primary.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PresenceStatChip extends StatelessWidget {
  const _PresenceStatChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendSearchBar extends StatelessWidget {
  const _FriendSearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: VelvetNoir.onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search friends...',
          hintStyle: const TextStyle(
            color: VelvetNoir.onSurfaceVariant,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: VelvetNoir.onSurfaceVariant,
            size: 20,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  color: VelvetNoir.onSurfaceVariant,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: VelvetNoir.surfaceHigh,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: VelvetNoir.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: VelvetNoir.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: VelvetNoir.primary.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header with count badge and expand/collapse chevron.
class _RichSectionHeader extends StatelessWidget {
  const _RichSectionHeader({
    required this.label,
    required this.count,
    required this.accentColor,
    required this.isExpanded,
    required this.onToggle,
  });

  final String label;
  final int count;
  final Color accentColor;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: VelvetNoir.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySectionLabel extends StatelessWidget {
  const _EmptySectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: VelvetNoir.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
    );
  }
}

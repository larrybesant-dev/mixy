import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/firebase_providers.dart';
import '../core/streams/stream_lifecycle_manager.dart';
import '../models/user_model.dart';
import '../features/messaging/providers/messaging_provider.dart';
import '../services/moderation_service.dart';
import '../features/friends/providers/friends_providers.dart';
import '../presentation/providers/user_provider.dart';
import '../shared/widgets/guest_auth_gate.dart';
import 'gift_picker_sheet.dart';

/// A bottom-sheet style profile popup usable anywhere in the app
/// (room participant tap, friend list tile, search results, etc.).
///
/// Usage:
/// ```dart
/// await UserProfilePopup.show(context, ref, userId: targetUserId);
/// ```
class UserProfilePopup {
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required String userId,

    /// Pre-loaded user — skips the Firestore fetch if you already have it.
    UserModel? preloadedUser,
  }) {
    final lifecycle = ref.read(streamLifecycleManagerProvider);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _UserProfilePopupSheet(
        userId: userId,
        preloadedUser: preloadedUser,
        streamLifecycleManager: lifecycle,
      ),
    );
  }
}

class _UserProfilePopupSheet extends ConsumerStatefulWidget {
  const _UserProfilePopupSheet({
    required this.userId,
    this.preloadedUser,
    required this.streamLifecycleManager,
  });

  final String userId;
  final UserModel? preloadedUser;
  final StreamLifecycleManager streamLifecycleManager;

  @override
  ConsumerState<_UserProfilePopupSheet> createState() =>
      _UserProfilePopupSheetState();
}

class _UserProfilePopupSheetState
    extends ConsumerState<_UserProfilePopupSheet> {
  UserModel? _profile;
  bool _loading = true;
  bool _isFriend = false;
  bool _isBlocked = false;
  bool _requestPending = false;

  final _moderationService = ModerationService();

  String get _normalizedUserId => widget.userId.trim();

  @override
  void initState() {
    super.initState();
    if (_normalizedUserId.isEmpty) {
      _loading = false;
      return;
    }
    if (widget.preloadedUser != null) {
      _profile = widget.preloadedUser;
      _loading = false;
      unawaited(_loadRelationship());
    } else {
      unawaited(_loadProfile());
    }
  }

  Future<void> _loadProfile() async {
    if (_normalizedUserId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final doc = await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(_normalizedUserId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _profile = UserModel.fromJson({'id': doc.id, ...doc.data()});
          _loading = false;
        });
        unawaited(_loadRelationship());
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRelationship() async {
    final currentUser = ref.read(userProvider);
    if (currentUser == null ||
        _normalizedUserId.isEmpty ||
        _normalizedUserId == currentUser.id) {
      return;
    }
    try {
      final friendIds =
          await ref.read(friendServiceProvider).getFriendIds(currentUser.id);
      final blocked = await _moderationService.isBlocked(_normalizedUserId);
      if (!mounted) return;
      setState(() {
        _isFriend = friendIds.contains(_normalizedUserId);
        _isBlocked = blocked;
      });
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[UserProfilePopup] _loadRelationship failed: $e\n$stack');
      }
    }
  }

  Color _vipColor(int level) {
    if (level >= 5) return const Color(0xFFFFD700);
    if (level >= 3) return const Color(0xFFC0C0C0);
    if (level >= 1) return const Color(0xFFCD7F32);
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(userProvider);
    final isSelf = currentUser?.id == _normalizedUserId;
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = _profile;
        if (profile == null) {
          return const Center(child: Text('User not found.'));
        }

        final initials = profile.username.trim().isEmpty
            ? '?'
            : profile.username.trim()[0].toUpperCase();

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Avatar + name
            Row(
              children: [
                ClipOval(
                  child: profile.avatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: profile.avatarUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => CircleAvatar(
                            radius: 36,
                            child: Text(
                              initials,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        )
                      : CircleAvatar(
                          radius: 36,
                          child: Text(
                            initials,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.username.trim().isEmpty
                            ? 'MixVy user'
                            : profile.username,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (profile.vipLevel > 0)
                        Row(
                          children: [
                            Icon(
                              Icons.workspace_premium,
                              size: 16,
                              color: _vipColor(profile.vipLevel),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'VIP ${profile.vipLevel}',
                              style: TextStyle(
                                color: _vipColor(profile.vipLevel),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      if (profile.location?.isNotEmpty == true)
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              profile.location!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Badges
            if (profile.badges.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: profile.badges
                    .map(
                      (badge) => Chip(
                        label: Text(
                          badge,
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            // Bio
            if (profile.bio?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(profile.bio!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 20),
            // Actions
            if (!isSelf) ...[
              _ActionButton(
                icon: Icons.person_outline,
                label: 'View full profile',
                onTap: () {
                  if (_normalizedUserId.isEmpty) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This profile is unavailable right now.'),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop();
                  context.go('/profile/$_normalizedUserId');
                },
              ),
              if (!_isBlocked)
                _ActionButton(
                  icon: _isFriend
                      ? Icons.check_circle_outline
                      : Icons.person_add_alt_1_outlined,
                  label: _isFriend
                      ? 'Already friends'
                      : (_requestPending ? 'Request sent' : 'Add friend'),
                  onTap: (_isFriend || _requestPending)
                      ? null
                      : () async {
                          final me = ref.read(userProvider);
                          if (me == null || _normalizedUserId.isEmpty) return;
                          await ref
                              .read(friendServiceProvider)
                              .sendFriendRequest(
                                me.id,
                                _normalizedUserId,
                              );
                          if (mounted) setState(() => _requestPending = true);
                        },
                ),
              if (!_isBlocked)
                _ActionButton(
                  icon: Icons.message_outlined,
                  label: 'Send message',
                  onTap: () async {
                    final allowed =
                        await GuestAuthGate.requireConversationStart(
                      context,
                      ref,
                    );
                    if (!allowed) return;

                    final currentUser = ref.read(userProvider);
                    final profile = _profile;
                    if (currentUser == null ||
                        profile == null ||
                        _normalizedUserId.isEmpty) {
                      return;
                    }
                    final conversationId = await ref
                        .read(messagingControllerProvider)
                        .createDirectConversation(
                          userId1: currentUser.id,
                          user1Name: currentUser.username,
                          user1AvatarUrl: currentUser.avatarUrl,
                          userId2: _normalizedUserId,
                          user2Name: profile.username.isEmpty
                              ? _normalizedUserId
                              : profile.username,
                          user2AvatarUrl: profile.avatarUrl,
                        );
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    context.go('/chat/$conversationId');
                  },
                ),
              if (!_isBlocked)
                _ActionButton(
                  icon: Icons.videocam_outlined,
                  label: 'Video call',
                  onTap: () {
                    if (_normalizedUserId.isEmpty) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This profile is unavailable right now.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    context.go(
                        '/camif (userId != null) userId=$_normalizedUserId');
                  },
                ),
              if (!_isBlocked)
                _ActionButton(
                  icon: Icons.card_giftcard,
                  label: 'Send gift',
                  onTap: () {
                    if (_normalizedUserId.isEmpty) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This profile is unavailable right now.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    GiftPickerSheet.show(
                      context,
                      ref,
                      recipientId: _normalizedUserId,
                      recipientName:
                          profile.username.isEmpty ? 'user' : profile.username,
                    );
                  },
                ),
              _ActionButton(
                icon: _isBlocked
                    ? Icons.lock_open_outlined
                    : Icons.block_outlined,
                label: _isBlocked ? 'Unblock user' : 'Block user',
                destructive: !_isBlocked,
                onTap: () async {
                  if (_normalizedUserId.isEmpty) return;
                  if (_isBlocked) {
                    await _moderationService.unblockUser(_normalizedUserId);
                  } else {
                    await _moderationService.blockUser(_normalizedUserId);
                  }
                  if (mounted) setState(() => _isBlocked = !_isBlocked);
                },
              ),
            ] else ...[
              _ActionButton(
                icon: Icons.edit_outlined,
                label: 'Edit my profile',
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/profile/edit');
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : (onTap == null ? Theme.of(context).disabledColor : null);
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
      dense: true,
    );
  }
}

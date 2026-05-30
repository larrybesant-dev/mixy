import 'package:flutter/material.dart';

import '../../../models/room_participant_model.dart';
import '../../../features/room/controllers/room_state.dart';
import '../../../features/room/providers/presence_provider.dart';
import '../../../presentation/providers/user_provider.dart';
import 'room_user_tile.dart';

/// A Paltalk-style always-visible user list panel for the room.
/// Shows role icons (crown/star/shield), online status, mic/cam indicators.
class UserListPanel extends StatelessWidget {
  const UserListPanel({
    super.key,
    required this.participants,
    required this.currentUserId,
    required this.presenceList,
    required this.displayNameById,
    required this.avatarUrlById,
    this.onTapUser,
    this.onWhisper,
    this.onKick,
    this.onMute,
    this.onBan,
    this.onBuzz,
    this.onDropFromMic,
    this.isCurrentUserHost = false,
  });

  final List<RoomParticipantModel> participants;
  final String currentUserId;
  final List<RoomPresenceModel> presenceList;
  final Map<String, String> displayNameById;
  final Map<String, String?> avatarUrlById;

  /// Called when a user row is tapped (e.g. to open a profile popup).
  final void Function(RoomParticipantModel participant)? onTapUser;

  /// Called when the whisper button is tapped for a user.
  final void Function(RoomParticipantModel participant)? onWhisper;

  /// Host-only moderation actions.
  final void Function(RoomParticipantModel participant)? onKick;
  final void Function(RoomParticipantModel participant)? onMute;
  final void Function(RoomParticipantModel participant)? onBan;
  final void Function(RoomParticipantModel participant)? onBuzz;
  final void Function(RoomParticipantModel participant)? onDropFromMic;

  /// Whether the current user is a host/cohost/moderator (shows mod menu).
  final bool isCurrentUserHost;

  @override
  Widget build(BuildContext context) {
    const npSurfaceContainer = Color(0xFF161A21);
    const npOnVariant = Color(0xFFB09080);

    final onlineIds = {
      for (final p in presenceList)
        if (p.isOnline &&
            (p.lastHeartbeatAt == null ||
                DateTime.now().difference(p.lastHeartbeatAt!).inSeconds < 60))
          p.userId,
    };

    // ── Role groups (Exclusive) ──────────────────────────────────────────
    final hosts = participants.where((p) => isHostLikeRole(p.role)).toList();
    
    final onStage = participants.where((p) {
      final role = normalizeRoomRole(p.role, fallbackRole: '');
      final isSpeaker = canManageStageRole(role) || role == roomRoleStage;
      // Exclude users already in hosts list
      return isSpeaker && !isHostLikeRole(role);
    }).toList()..sort((a, b) => _roleOrder(a.role).compareTo(_roleOrder(b.role)));
    
    final audience = participants.where((p) {
      final role = normalizeRoomRole(p.role, fallbackRole: '');
      final isSpeaker = isHostLikeRole(role) || canManageStageRole(role) || role == roomRoleStage;
      // Exclude anyone in Host or On Mic sections
      return !isSpeaker;
    }).toList()..sort((a, b) => _roleOrder(a.role).compareTo(_roleOrder(b.role)));

    if (hosts.isEmpty && onStage.isEmpty && audience.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No one here yet.',
            style: TextStyle(color: npOnVariant, fontSize: 13),
          ),
        ),
      );
    }

    return ColoredBox(
      color: npSurfaceContainer,
      child: CustomScrollView(
        slivers: [
          // ── HOST FEATURED SLOT ─────────────────────────────────────────
          if (hosts.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                'HOST',
                hosts.length,
                const Color(0xFFD4AF37),
              ),
            ),
            SliverToBoxAdapter(child: _buildHostFeaturedSlot(hosts.first)),
          ],

          // ── ON MIC — speakers grid ─────────────────────────────────────
          if (onStage.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                'ON MIC',
                onStage.length,
                const Color(0xFF9B2535),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final p = onStage[index];
                  return RoomUserTile(
                    displayName:
                        displayNameById[p.userId] ??
                        resolvePublicUsername(uid: p.userId),
                    avatarUrl: avatarUrlById[p.userId],
                    role: p.role,
                    isMicOn: p.micOn,
                    isMuted: p.isMuted,
                    isMe: p.userId == currentUserId,
                    micExpiresAt: p.micExpiresAt,
                    layout: RoomUserTileLayout.grid,
                    onTap: onTapUser == null ? null : () => onTapUser!(p),
                  );
                }, childCount: onStage.length),
              ),
            ),
          ],

          // ── AUDIENCE ──────────────────────────────────────────────────
          if (audience.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                'AUDIENCE',
                audience.length,
                npOnVariant,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final p = audience[index];
                final isOnline = onlineIds.contains(p.userId);
                final displayName =
                    displayNameById[p.userId] ??
                    resolvePublicUsername(uid: p.userId);
                final avatarUrl = avatarUrlById[p.userId];
                final isMe = p.userId == currentUserId;
                final customStatus = presenceList
                    .firstWhere(
                      (pr) => pr.userId == p.userId,
                      orElse: () => RoomPresenceModel(
                        userId: p.userId,
                        isOnline: false,
                        lastHeartbeatAt: null,
                        lastSeenAt: null,
                      ),
                    )
                    .customStatus;
                return _UserListTile(
                  participant: p,
                  displayName: displayName,
                  avatarUrl: avatarUrl,
                  isOnline: isOnline,
                  isMe: isMe,
                  customStatus: customStatus,
                  onTap: onTapUser == null ? null : () => onTapUser!(p),
                  onWhisper: (onWhisper == null || isMe)
                      ? null
                      : () => onWhisper!(p),
                  onKick: (onKick == null || isMe) ? null : () => onKick!(p),
                  onMute: (onMute == null || isMe) ? null : () => onMute!(p),
                  onBan: (onBan == null || isMe) ? null : () => onBan!(p),
                  onBuzz: (onBuzz == null || isMe) ? null : () => onBuzz!(p),
                  onDropFromMic: (onDropFromMic == null || isMe)
                      ? null
                      : () => onDropFromMic!(p),
                  showModMenu: isCurrentUserHost && !isMe,
                );
              }, childCount: audience.length),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String label, int count, Color color) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111519),
        border: Border(
          top: BorderSide(color: color.withValues(alpha: 0.18)),
          bottom: BorderSide(color: color.withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Host featured slot ────────────────────────────────────────────────────
  Widget _buildHostFeaturedSlot(RoomParticipantModel host) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFD4AF37).withValues(alpha: 0.06),
            const Color(0xFF161A21).withValues(alpha: 0),
          ],
        ),
      ),
      child: Center(
        child: RoomUserTile(
          displayName:
              displayNameById[host.userId] ??
              resolvePublicUsername(uid: host.userId),
          avatarUrl: avatarUrlById[host.userId],
          role: host.role,
          isMicOn: host.micOn,
          isMuted: host.isMuted,
          isMe: host.userId == currentUserId,
          micExpiresAt: host.micExpiresAt,
          layout: RoomUserTileLayout.grid,
          onTap: onTapUser == null ? null : () => onTapUser!(host),
        ),
      ),
    );
  }

  static int _roleOrder(String role) {
    switch (role) {
      case 'host':
      case 'owner':
        return 0;
      case 'cohost':
        return 1;
      case 'moderator':
        return 2;
      default:
        return 3;
    }
  }
}

class _UserListTile extends StatelessWidget {
  const _UserListTile({
    required this.participant,
    required this.displayName,
    required this.isOnline,
    required this.isMe,
    this.avatarUrl,
    this.customStatus,
    this.onTap,
    this.onWhisper,
    this.onKick,
    this.onMute,
    this.onBan,
    this.onBuzz,
    this.onDropFromMic,
    this.showModMenu = false,
  });

  final RoomParticipantModel participant;
  final String displayName;
  final String? avatarUrl;
  final String? customStatus;
  final bool isOnline;
  final bool isMe;
  final VoidCallback? onTap;
  final VoidCallback? onWhisper;
  final VoidCallback? onKick;
  final VoidCallback? onMute;
  final VoidCallback? onBan;
  final VoidCallback? onBuzz;
  final VoidCallback? onDropFromMic;
  final bool showModMenu;

  void _showContextMenu(BuildContext context, Offset globalPosition) async {
    const npSurfaceHigh = Color(0xFF241820);
    const npPrimary = Color(0xFFD4A853);

    final selected = await showMenu<String>(
      context: context,
      color: npSurfaceHigh,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.person_outline, color: npPrimary, size: 16),
              const SizedBox(width: 8),
              Text(
                'View Profile',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (onWhisper != null)
          PopupMenuItem(
            value: 'whisper',
            child: Row(
              children: [
                const Icon(
                  Icons.message_outlined,
                  color: Color(0xFFC45E7A),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Whisper',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        if (onBuzz != null)
          PopupMenuItem(
            value: 'buzz',
            child: Row(
              children: [
                const Icon(
                  Icons.electric_bolt,
                  color: Color(0xFFFF6E84),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Buzz ⚡',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        if (showModMenu && onMute != null)
          PopupMenuItem(
            value: 'mute',
            child: Row(
              children: [
                Icon(
                  participant.isMuted ? Icons.mic_none : Icons.mic_off_outlined,
                  color: const Color(0xFFFFA040),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  participant.isMuted ? 'Unmute' : 'Mute',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        if (showModMenu && onDropFromMic != null && participant.micOn)
          PopupMenuItem(
            value: 'drop',
            child: Row(
              children: [
                const Icon(
                  Icons.arrow_downward,
                  color: Color(0xFFC45E7A),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Drop from Mic',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        if (showModMenu && onKick != null)
          PopupMenuItem(
            value: 'kick',
            child: Row(
              children: [
                const Icon(Icons.logout, color: Color(0xFFFF6E84), size: 16),
                const SizedBox(width: 8),
                Text(
                  'Kick',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        if (showModMenu && onBan != null)
          PopupMenuItem(
            value: 'ban',
            child: Row(
              children: [
                const Icon(Icons.block, color: Color(0xFFFF3355), size: 16),
                const SizedBox(width: 8),
                Text(
                  'Ban',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case 'profile':
        onTap?.call();
      case 'whisper':
        onWhisper?.call();
      case 'buzz':
        onBuzz?.call();
      case 'mute':
        onMute?.call();
      case 'drop':
        onDropFromMic?.call();
      case 'kick':
        onKick?.call();
      case 'ban':
        onBan?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    const npSurfaceHigh = Color(0xFF241820);
    const npOnVariant = Color(0xFFB09080);
    const npPrimary = Color(0xFFD4A853);
    const npSecondary = Color(0xFFC45E7A);

    final roleIcon = _roleIcon(participant.role);

    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: (customStatus != null && customStatus!.isNotEmpty) ? 56 : 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withAlpha(10)),
            ),
          ),
          child: Row(
            children: [
              // Avatar + online dot
              SizedBox(
                width: 28,
                height: 28,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: npSurfaceHigh,
                      backgroundImage:
                          avatarUrl != null && avatarUrl!.isNotEmpty
                          ? NetworkImage(avatarUrl!)
                          : null,
                      child: avatarUrl == null || avatarUrl!.isEmpty
                          ? Text(
                              displayName.isEmpty
                                  ? '?'
                                  : displayName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? const Color(0xFF4CAF50)
                              : npOnVariant,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF161A21),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Name + role
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (roleIcon != null) ...[
                          Text(roleIcon, style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 3),
                        ],
                        Flexible(
                          child: Text(
                            isMe ? '$displayName (you)' : displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isMe ? npPrimary : Colors.white,
                              fontSize: 12,
                              fontWeight: isMe
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (customStatus != null && customStatus!.isNotEmpty)
                      Text(
                        customStatus!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              // Mic / cam indicators
              if (participant.micOn)
                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Icon(Icons.mic, color: npSecondary, size: 13),
                ),
              if (participant.camOn)
                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Icon(Icons.videocam, color: npSecondary, size: 13),
                ),
              if (participant.isMuted)
                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Icon(
                    Icons.mic_off,
                    color: Color(0xFFFF6E84),
                    size: 13,
                  ),
                ),
              // Whisper button (PM)
              if (onWhisper != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: onWhisper,
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(
                        Icons.message_outlined,
                        color: npOnVariant,
                        size: 14,
                        semanticLabel: 'Whisper',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ); // InkWell + GestureDetector
  }

  static String? _roleIcon(String role) {
    switch (role) {
      case 'host':
      case 'owner':
        return '👑';
      case 'cohost':
        return '⭐';
      case 'moderator':
        return '🛡️';
      default:
        return null;
    }
  }
}




import 'package:flutter/material.dart';

import '../../../features/room/controllers/room_state.dart';
import '../../../features/room/providers/presence_provider.dart';
import '../../../models/room_participant_model.dart';
import 'room_user_tile.dart';

/// Sidebar roster grouped into three distinct buckets:
/// - On Cam
/// - Mic Queue
/// - Chatting
class UserListPanel extends StatelessWidget {
  const UserListPanel({
    super.key,
    required this.participants,
    required this.currentUserId,
    required this.presenceList,
    required this.displayNameById,
    required this.avatarUrlById,
    this.micQueueUserIds = const <String>{},
    this.onTapUser,
  });

  final List<RoomParticipantModel> participants;
  final String currentUserId;
  final List<RoomPresenceModel> presenceList;
  final Map<String, String> displayNameById;
  final Map<String, String?> avatarUrlById;
  final Set<String> micQueueUserIds;
  final void Function(RoomParticipantModel participant)? onTapUser;

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF161A21);

    final onlineIds = {
      for (final p in presenceList)
        if (p.isOnline &&
            (p.lastHeartbeatAt == null ||
                DateTime.now().difference(p.lastHeartbeatAt!).inSeconds < 60))
          p.userId,
    };

    final normalizedQueueIds = micQueueUserIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final sortedParticipants = [...participants]
      ..sort((left, right) {
        final leftRole = _roleRank(left.role);
        final rightRole = _roleRank(right.role);
        if (leftRole != rightRole) return leftRole.compareTo(rightRole);
        return right.lastActiveAt.compareTo(left.lastActiveAt);
      });

    final onCam = <RoomParticipantModel>[];
    final micQueue = <RoomParticipantModel>[];
    final chatting = <RoomParticipantModel>[];

    final onCamIds = <String>{};

    for (final p in sortedParticipants) {
      if (p.camOn) {
        onCam.add(p);
        onCamIds.add(p.userId);
      }
    }

    for (final p in sortedParticipants) {
      if (onCamIds.contains(p.userId)) continue;
      if (normalizedQueueIds.contains(p.userId)) {
        micQueue.add(p);
      }
    }

    final queuedIds = micQueue.map((p) => p.userId).toSet();
    for (final p in sortedParticipants) {
      if (onCamIds.contains(p.userId) || queuedIds.contains(p.userId)) continue;
      chatting.add(p);
    }

    return ColoredBox(
      color: surface,
      child: CustomScrollView(
        slivers: [
          _sectionHeader('ON CAM', onCam.length, const Color(0xFF9B2535)),
          _sectionList(onCam, onlineIds),
          _sectionHeader('MIC QUEUE', micQueue.length, const Color(0xFFD4AF37)),
          _sectionList(micQueue, onlineIds),
          _sectionHeader('CHATTING', chatting.length, const Color(0xFFB09080)),
          _sectionList(chatting, onlineIds),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
      ),
    );
  }

  SliverToBoxAdapter _sectionHeader(String label, int count, Color color) {
    return SliverToBoxAdapter(
      child: Container(
        height: 28,
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
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverList _sectionList(List<RoomParticipantModel> entries, Set<String> onlineIds) {
    if (entries.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate.fixed([
          const SizedBox(
            height: 38,
            child: Center(
              child: Text(
                'No users',
                style: TextStyle(color: Color(0xFF7D6D63), fontSize: 11),
              ),
            ),
          ),
        ]),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final p = entries[index];
        final displayName = displayNameById[p.userId] ??
          (p.displayName?.trim().isNotEmpty == true
            ? p.displayName!.trim()
            : p.userId);
        final avatarUrl = avatarUrlById[p.userId] ?? p.photoUrl;
        final isMe = p.userId == currentUserId;
        final isOnline = onlineIds.contains(p.userId);

        return Stack(
          children: [
            RoomUserTile(
              displayName: displayName,
              avatarUrl: avatarUrl,
              role: p.role,
              isMicOn: p.micOn,
              isMuted: p.isMuted,
              isMe: isMe,
              rankTier: p.rankTier,
              diamondLevel: p.diamondLevel,
              layout: RoomUserTileLayout.list,
              onTap: onTapUser == null ? null : () => onTapUser!(p),
            ),
            Positioned(
              left: 34,
              top: 25,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF6B7280),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      }, childCount: entries.length),
    );
  }

  static int _roleRank(String role) {
    final normalized = normalizeRoomRole(role, fallbackRole: '');
    switch (normalized) {
      case roomRoleHost:
      case roomRoleOwner:
        return 0;
      case roomRoleCohost:
        return 1;
      case roomRoleModerator:
        return 2;
      case roomRoleStage:
        return 3;
      default:
        return 4;
    }
  }
}

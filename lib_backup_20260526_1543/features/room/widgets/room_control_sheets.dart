import 'package:flutter/material.dart';

import '../../../models/room_participant_model.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../widgets/safe_network_avatar.dart';
import '../controllers/room_state.dart';

class RoomUserPresentation {
  const RoomUserPresentation({required this.displayName, this.avatarUrl});

  final String displayName;
  final String? avatarUrl;
}

class RoomActionItem {
  const RoomActionItem({
    required this.label,
    required this.icon,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final bool destructive;
}

class RoomParticipantActionSheet extends StatelessWidget {
  const RoomParticipantActionSheet({
    super.key,
    required this.participant,
    required this.userPresentation,
    required this.currentUserId,
    required this.hostUserId,
    required this.actions,
  });

  final RoomParticipantModel participant;
  final RoomUserPresentation userPresentation;
  final String currentUserId;
  final String hostUserId;
  final List<RoomActionItem> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedRole = normalizeRoomRole(
      participant.role,
      fallbackRole: roomRoleAudience,
    );
    final chips = <Widget>[
      _RoleChip(label: normalizedRole.toUpperCase()),
      if (participant.userId == currentUserId) const _RoleChip(label: 'YOU'),
      if (participant.userId == hostUserId && !isHostLikeRole(normalizedRole))
        const _RoleChip(label: 'ROOM HOST'),
      if (normalizedRole == roomRoleModerator)
        const _RoleChip(label: 'MODERATOR'),
      if (participant.isMuted) const _RoleChip(label: 'MUTED'),
      if (participant.isBanned)
        const _RoleChip(label: 'BANNED', destructive: true),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SafeNetworkAvatar(
                radius: 20,
                avatarUrl: userPresentation.avatarUrl,
              ),
              title: Text(
                userPresentation.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: const Text('Room member'),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
            const SizedBox(height: 16),
            ...actions.map((action) {
              final foregroundColor =
                  action.destructive ? colorScheme.error : null;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: action.enabled,
                leading: Icon(action.icon, color: foregroundColor),
                title: Text(
                  action.label,
                  style: foregroundColor == null
                      ? null
                      : TextStyle(color: foregroundColor),
                ),
                onTap: action.enabled ? action.onTap : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class RoomRosterSheet extends StatelessWidget {
  const RoomRosterSheet({
    super.key,
    required this.participants,
    required this.presentationByUserId,
    required this.currentUserId,
    required this.hostUserId,
    required this.onParticipantTap,
    this.onlineStatusByUserId = const {},
  });

  final List<RoomParticipantModel> participants;
  final Map<String, RoomUserPresentation> presentationByUserId;
  final String currentUserId;
  final String hostUserId;
  final ValueChanged<RoomParticipantModel> onParticipantTap;

  /// userId → true if the user is currently online (heartbeat fresh)
  final Map<String, bool> onlineStatusByUserId;

  @override
  Widget build(BuildContext context) {
    final sortedParticipants = [...participants]..sort((left, right) {
        final leftRank = _roleRank(left, hostUserId);
        final rightRank = _roleRank(right, hostUserId);
        if (leftRank != rightRank) {
          return leftRank.compareTo(rightRank);
        }
        return left.userId.compareTo(right.userId);
      });

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'People in room',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('${sortedParticipants.length} connected'),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sortedParticipants.length,
                separatorBuilder: (__, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final participant = sortedParticipants[index];
                  final presentation =
                      presentationByUserId[participant.userId] ??
                          RoomUserPresentation(
                            displayName: resolvePublicUsername(
                              uid: participant.userId,
                            ),
                          );
                  final role = normalizeRoomRole(
                    participant.role,
                    fallbackRole: roomRoleAudience,
                  );
                  final chips = <String>[
                    if (participant.userId == currentUserId) 'You',
                    if (participant.userId == hostUserId ||
                        isHostLikeRole(role))
                      'Host',
                    if (role == roomRoleModerator) 'Moderator',
                    if (role == roomRoleCohost) 'Cohost',
                    if (role == roomRoleStage) 'Stage',
                    if (role == roomRoleAudience) 'Audience',
                    if (participant.isMuted) 'Muted',
                    if (participant.isBanned) 'Banned',
                  ];

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SafeNetworkAvatar(
                          radius: 20,
                          avatarUrl: presentation.avatarUrl,
                          fallbackText: null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color:
                                  (onlineStatusByUserId[participant.userId] ??
                                          false)
                                      ? const Color(0xFF4CAF50)
                                      : Colors.grey.shade400,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(presentation.displayName),
                    dense: true,
                    subtitle: Text(chips.join(' • ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onParticipantTap(participant),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _roleRank(RoomParticipantModel participant, String hostUserId) {
    final role = normalizeRoomRole(participant.role, fallbackRole: '');
    if (participant.userId == hostUserId || isHostLikeRole(role)) {
      return 0;
    }
    if (role == roomRoleModerator) {
      return 1;
    }
    if (role == roomRoleCohost) {
      return 2;
    }
    if (role == roomRoleStage) {
      return 3;
    }
    return 4;
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, this.destructive = false});

  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: destructive
            ? colorScheme.errorContainer
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: destructive
              ? colorScheme.onErrorContainer
              : colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../widgets/safe_network_avatar.dart';

enum ProfilePresenceState { online, recentlyActive, inRoom, offline }

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    this.usernameHandle,
    required this.statusText,
    required this.presenceState,
    required this.onmessage,
    required this.onInvite,
    this.onJoin,
    this.currentRoom,
    this.lastMessagePreview,
    this.mutualFriendsCount,
    this.activities = const <ProfileActivityItem>[],
    this.onMute,
    required this.onBlock,
    required this.onReport,
    this.blockLabel = 'Block',
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? usernameHandle;
  final String statusText;
  final ProfilePresenceState presenceState;
  final VoidCallback onmessage;
  final VoidCallback onInvite;
  final VoidCallback? onJoin;
  final String? currentRoom;
  final String? lastMessagePreview;
  final int? mutualFriendsCount;
  final List<ProfileActivityItem> activities;
  final VoidCallback? onMute;
  final VoidCallback onBlock;
  final VoidCallback onReport;
  final String blockLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ProfileHeader(
          userId: userId,
          displayName: displayName,
          avatarUrl: avatarUrl,
          usernameHandle: usernameHandle,
          statusText: statusText,
          presenceState: presenceState,
        ),
        const SizedBox(height: 16),
        ProfileActionsRow(
          onmessage: onmessage,
          onInvite: onInvite,
          onJoin: onJoin,
        ),
        const SizedBox(height: 10),
        _SecondaryActionsRow(
          onMute: onMute,
          onBlock: onBlock,
          onReport: onReport,
          blockLabel: blockLabel,
        ),
      ],
    );
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    this.usernameHandle,
    required this.statusText,
    required this.presenceState,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? usernameHandle;
  final String statusText;
  final ProfilePresenceState presenceState;

  @override
  Widget build(BuildContext context) {
    final ringColor = _presenceColor(presenceState);
    final glowColor = _presenceGlowColor(presenceState);

    return Center(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 84,
            height: 84,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: 2.2),
              boxShadow: glowColor == null
                  ? null
                  : [
                      BoxShadow(
                        color: glowColor,
                        blurRadius: 14,
                        spreadRadius: 0,
                      ),
                    ],
            ),
            child: Hero(
              tag: 'avatar-$userId',
              child: SafeNetworkAvatar(
                radius: 36,
                avatarUrl: avatarUrl,
                backgroundColor: VelvetNoir.surfaceHigh,
                fallbackText: displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
                    : '?',
                fallbackTextStyle: GoogleFonts.raleway(
                  color: VelvetNoir.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: GoogleFonts.raleway(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: VelvetNoir.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          if ((usernameHandle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              usernameHandle!.trim(),
              textAlign: TextAlign.center,
              style: GoogleFonts.raleway(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: VelvetNoir.primary,
                letterSpacing: 0.2,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: GoogleFonts.raleway(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: VelvetNoir.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Color _presenceColor(ProfilePresenceState state) {
    switch (state) {
      case ProfilePresenceState.online:
        return const Color(0xFF22C55E);
      case ProfilePresenceState.recentlyActive:
        return const Color(0xFF86EFAC);
      case ProfilePresenceState.inRoom:
        return VelvetNoir.secondaryBright;
      case ProfilePresenceState.offline:
        return VelvetNoir.outlineVariant.withValues(alpha: 0.55);
    }
  }

  Color? _presenceGlowColor(ProfilePresenceState state) {
    switch (state) {
      case ProfilePresenceState.online:
        return const Color(0x5522C55E);
      case ProfilePresenceState.recentlyActive:
        return const Color(0x3386EFAC);
      case ProfilePresenceState.inRoom:
        return VelvetNoir.secondaryBright.withValues(alpha: 0.45);
      case ProfilePresenceState.offline:
        return null;
    }
  }
}

class ProfileActionsRow extends StatelessWidget {
  const ProfileActionsRow({
    super.key,
    required this.onmessage,
    required this.onInvite,
    this.onJoin,
  });

  final VoidCallback onmessage;
  final VoidCallback onInvite;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onmessage,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Message'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onInvite,
            icon: const Icon(Icons.mail_outline_rounded, size: 18),
            label: const Text('Invite'),
          ),
        ),
        if (onJoin != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onJoin,
              icon: const Icon(Icons.meeting_room_outlined, size: 18),
              label: const Text('Join'),
            ),
          ),
        ],
      ],
    );
  }
}

class ProfileActivityItem {
  const ProfileActivityItem({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
}

class ProfileActivitySection extends StatelessWidget {
  const ProfileActivitySection({
    super.key,
    this.currentRoom,
    this.lastMessagePreview,
    this.mutualFriendsCount,
    this.activities = const <ProfileActivityItem>[],
  });

  final String? currentRoom;
  final String? lastMessagePreview;
  final int? mutualFriendsCount;
  final List<ProfileActivityItem> activities;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (final activity in activities) {
      rows.add(
        _ActivityRow(
          icon: activity.icon,
          label: activity.label,
          value: activity.value,
          accent: activity.accent,
        ),
      );
    }

    if ((currentRoom ?? '').isNotEmpty) {
      rows.add(
        _ActivityRow(
          icon: Icons.mic_rounded,
          label: 'Current room',
          value: currentRoom!,
          accent: VelvetNoir.secondaryBright,
        ),
      );
    }

    if ((lastMessagePreview ?? '').isNotEmpty) {
      rows.add(
        _ActivityRow(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Last message',
          value: lastMessagePreview!,
        ),
      );
    }

    if (mutualFriendsCount != null) {
      rows.add(
        _ActivityRow(
          icon: Icons.people_outline_rounded,
          label: 'Mutual friends',
          value: '$mutualFriendsCount',
        ),
      );
    }

    if (rows.isEmpty) {
      rows.add(
        const _ActivityRow(
          icon: Icons.hourglass_bottom_rounded,
          label: 'Activity',
          value: 'No recent activity',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: Color(0x1FF7EDE2)),
        const SizedBox(height: 10),
        Text(
          'Recent activity',
          style: GoogleFonts.raleway(
            color: VelvetNoir.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0x1FF7EDE2)),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: accent ?? VelvetNoir.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.raleway(
            fontSize: 12,
            color: VelvetNoir.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.raleway(
              fontSize: 12,
              color: VelvetNoir.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SecondaryActionsRow extends StatelessWidget {
  const _SecondaryActionsRow({
    required this.onMute,
    required this.onBlock,
    required this.onReport,
    required this.blockLabel,
  });

  final VoidCallback? onMute;
  final VoidCallback onBlock;
  final VoidCallback onReport;
  final String blockLabel;

  @override
  Widget build(BuildContext context) {
    final subtleColor = VelvetNoir.onSurfaceVariant;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: onMute,
          icon: Icon(Icons.volume_off_outlined, size: 16, color: subtleColor),
          label: Text(
            'Mute',
            style: GoogleFonts.raleway(
              fontSize: 12,
              color: subtleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: onBlock,
          icon: Icon(Icons.block_outlined, size: 16, color: subtleColor),
          label: Text(
            blockLabel,
            style: GoogleFonts.raleway(
              fontSize: 12,
              color: subtleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: onReport,
          icon: const Icon(
            Icons.flag_outlined,
            size: 16,
            color: VelvetNoir.error,
          ),
          label: Text(
            'Report',
            style: GoogleFonts.raleway(
              fontSize: 12,
              color: VelvetNoir.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// lib/features/home/widgets/active_friends_row.dart
//
// ActiveFriendsRow – horizontal scrollable row of friend avatars that
// are currently online or recently active, shown on the home screen.
//
// Avatar ring states:
//   - online     : solid neon green ring
//   - recent     : dashed/dimmer cyan ring with pulse
//   - inRoom     : orange ring with neon pulse
//   - offline    : grey ring (no pulse)
//
// Usage:
//   ActiveFriendsRow(presenceList: friends)
// ─────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../core/motion/app_motion.dart';
import '../../../core/theme/neon_colors.dart';
import '../../../features/room/services/user_presence_service.dart';

class ActiveFriendsRow extends StatelessWidget {
  final List<UserPresence> presenceList;
  final void Function(UserPresence)? onAvatarTap;

  const ActiveFriendsRow({
    super.key,
    required this.presenceList,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    if (presenceList.isEmpty) return const SizedBox.shrink();

    return AppMotion.slideFadeIn(
      beginOffset: const Offset(0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: NeonColors.successGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Active Now',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${presenceList.length})',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: presenceList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (ctx, i) => _FriendAvatar(
                presence: presenceList[i],
                onTap: () => onAvatarTap?.call(presenceList[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Single friend avatar with animated ring
// ─────────────────────────────────────────────────────────────────
class _FriendAvatar extends StatefulWidget {
  final UserPresence presence;
  final VoidCallback? onTap;

  const _FriendAvatar({required this.presence, this.onTap});

  @override
  State<_FriendAvatar> createState() => _FriendAvatarState();
}

class _FriendAvatarState extends State<_FriendAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    if (_shouldPulse) _ctrl.repeat(reverse: true);
  }

  bool get _shouldPulse =>
      widget.presence.status == PresenceStatus.online ||
      widget.presence.status == PresenceStatus.away;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = _ringColor(widget.presence.status);

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar + ring
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) {
              final t = AppMotion.pulse.transform(_ctrl.value);
              final alpha = _shouldPulse ? 0.55 + t * 0.45 : 0.4;
              final blur = _shouldPulse ? 4.0 + t * 6.0 : 0.0;

              return Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ringColor.withValues(alpha: alpha),
                    width: 2.0,
                  ),
                  boxShadow: _shouldPulse
                      ? [
                          BoxShadow(
                            color: ringColor.withValues(alpha: t * 0.5),
                            blurRadius: blur,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
                child: ClipOval(child: child),
              );
            },
            child: _buildAvatar(),
          ),

          const SizedBox(height: 4),

          // Name
          SizedBox(
            width: 52,
            child: Text(
              widget.presence.displayName.split(' ').first,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (widget.presence.avatarUrl.isNotEmpty) {
      return Image.network(
        widget.presence.avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initialsAvatar(),
      );
    }
    return _initialsAvatar();
  }

  Widget _initialsAvatar() {
    final ringColor = _ringColor(widget.presence.status);
    final initials = widget.presence.displayName.isNotEmpty
        ? widget.presence.displayName[0].toUpperCase()
        : '?';
    return Container(
      color: ringColor.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: ringColor,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }

  Color _ringColor(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return NeonColors.successGreen;
      case PresenceStatus.away:
        return NeonColors.neonBlue;
      case PresenceStatus.doNotDisturb:
        return NeonColors.errorRed;
      case PresenceStatus.offline:
        return Colors.grey.shade600;
    }
  }
}

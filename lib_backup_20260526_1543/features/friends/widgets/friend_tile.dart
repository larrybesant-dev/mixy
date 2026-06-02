import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/network_image_url.dart';
import '../../../core/theme.dart';
import '../../../models/user_model.dart';

class FriendTileAction {
  const FriendTileAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

/// Dense messenger-style contact row.
///
/// Layout: [presence-ring avatar] | [username + status dot] | [compact chips]
/// Tap = primary action (open chat / join room).
/// Long press = full action sheet.
class FriendTile extends StatelessWidget {
  const FriendTile({
    required this.user,
    required this.statusLabel,
    required this.statusColor,
    required this.actions,
    this.statusIcon,
    this.onTap,
    super.key,
  });

  final UserModel user;
  final String statusLabel;
  final Color statusColor;
  final IconData? statusIcon;
  final List<FriendTileAction> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = sanitizeNetworkImageUrl(user.avatarUrl);
    final isActive = statusColor != VelvetNoir.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress:
            actions.isNotEmpty ? () => _showActionSheet(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PresenceRingAvatar(
                avatarUrl: avatarUrl,
                username: user.username,
                ringColor: isActive ? statusColor : Colors.transparent,
                glowActive: isActive && statusIcon != null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VelvetNoir.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _StatusRow(
                      statusLabel: statusLabel,
                      statusColor: statusColor,
                      statusIcon: statusIcon,
                    ),
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length && i < 2; i++) ...[
                      if (i > 0) const SizedBox(height: 4),
                      _CompactChip(action: actions[i]),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VelvetNoir.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ActionSheet(username: user.username, actions: actions),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

/// Avatar surrounded by a colored presence ring with optional glow.
class _PresenceRingAvatar extends StatelessWidget {
  const _PresenceRingAvatar({
    required this.avatarUrl,
    required this.username,
    required this.ringColor,
    required this.glowActive,
  });

  final String? avatarUrl;
  final String username;
  final Color ringColor;
  final bool glowActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2.0),
        boxShadow: glowActive
            ? [
                BoxShadow(
                  color: ringColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: avatarUrl != null
              ? CachedNetworkImage(
                  imageUrl: avatarUrl!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => CircleAvatar(
                    backgroundColor: VelvetNoir.surfaceHighest,
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: VelvetNoir.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              : CircleAvatar(
                  backgroundColor: VelvetNoir.surfaceHighest,
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: VelvetNoir.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Inline status dot + label row.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.statusLabel,
    required this.statusColor,
    this.statusIcon,
  });

  final String statusLabel;
  final Color statusColor;
  final IconData? statusIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (statusIcon != null) ...[
          Icon(statusIcon, size: 10, color: statusColor),
          const SizedBox(width: 4),
        ] else ...[
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 4, top: 1),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
        Flexible(
          child: Text(
            statusLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: statusColor.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small labeled chip used as a trailing action affordance on a friend tile.
class _CompactChip extends StatelessWidget {
  const _CompactChip({required this.action});

  final FriendTileAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VelvetNoir.surfaceBright,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: action.onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: VelvetNoir.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            action.label,
            style: const TextStyle(
              color: VelvetNoir.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet shown on long-press with the full list of friend actions.
class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.username, required this.actions});

  final String username;
  final List<FriendTileAction> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: VelvetNoir.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              username,
              style: const TextStyle(
                color: VelvetNoir.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(color: VelvetNoir.outlineVariant, height: 1),
          ...actions.map(
            (action) => ListTile(
              leading: Icon(action.icon, color: VelvetNoir.primary),
              title: Text(
                action.label,
                style: const TextStyle(
                  color: VelvetNoir.onSurface,
                  fontSize: 15,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                action.onPressed();
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

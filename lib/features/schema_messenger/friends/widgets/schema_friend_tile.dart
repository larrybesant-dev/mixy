import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../models/schema_friend_identity.dart';
import '../models/schema_friend_presence.dart';

enum FriendRowDensity { dense, compact }

class SchemaFriendTile extends StatelessWidget {
  const SchemaFriendTile({
    super.key,
    required this.identity,
    required this.presence,
    required this.trailing,
    this.density = FriendRowDensity.dense,
    this.isSelected = false,
    this.onTap,
  });

  final SchemaFriendIdentity identity;
  final SchemaFriendPresence presence;
  final Widget trailing;
  final FriendRowDensity density;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _parseColor(identity.accentColor) ?? VelvetNoir.primary;
    final selectionColor =
        presence.roomId != null && presence.roomId!.isNotEmpty
        ? VelvetNoir.primary
        : (presence.isOnline ? const Color(0xFF34D399) : accent);
    final avatarRadius = density == FriendRowDensity.dense ? 18.0 : 21.0;
    final horizontalPadding = density == FriendRowDensity.dense ? 10.0 : 12.0;
    final verticalPadding = density == FriendRowDensity.dense ? 7.0 : 10.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: density == FriendRowDensity.dense
              ? (isSelected
                    ? VelvetNoir.surfaceHighest.withValues(alpha: 0.92)
                    : VelvetNoir.surfaceHigh.withValues(alpha: 0.22))
              : VelvetNoir.surfaceHigh.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: isSelected
                  ? selectionColor.withValues(alpha: 0.95)
                  : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(
              color: isSelected
                  ? selectionColor.withValues(alpha: 0.24)
                  : VelvetNoir.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectionColor.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: accent.withValues(alpha: 0.2),
                  child: Text(
                    _initials(identity.username),
                    style: TextStyle(
                      color: VelvetNoir.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: density == FriendRowDensity.dense ? 12 : 14,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: density == FriendRowDensity.dense ? 10 : 11,
                    height: density == FriendRowDensity.dense ? 10 : 11,
                    decoration: BoxDecoration(
                      color: presence.isOnline
                          ? const Color(0xFF34D399)
                          : const Color(0xFF71717A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: VelvetNoir.surfaceHigh,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: density == FriendRowDensity.dense ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identity.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VelvetNoir.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? selectionColor.withValues(alpha: 0.92)
                          : VelvetNoir.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontSize: density == FriendRowDensity.dense ? 11 : 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            trailing,
          ],
        ),
      ),
    );
  }

  String _statusLabel() {
    if (presence.roomId != null && presence.roomId!.isNotEmpty) {
      return 'In room now';
    }
    if (presence.isOnline) return 'Online now';
    final lastSeen = presence.lastActiveAt;
    if (lastSeen == null) return 'Offline';

    final delta = DateTime.now().difference(lastSeen);
    if (delta.inMinutes < 1) return 'Last seen just now';
    if (delta.inMinutes < 60) return 'Last seen ${delta.inMinutes}m ago';
    if (delta.inHours < 24) return 'Last seen ${delta.inHours}h ago';
    return 'Last seen ${delta.inDays}d ago';
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    final cleaned = hex.trim().replaceFirst('#', '');
    final value = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    final intValue = int.tryParse(value, radix: 16);
    if (intValue == null) return null;
    return Color(intValue);
  }
}

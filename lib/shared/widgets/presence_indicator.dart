import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_presence.dart';
import '../providers/user_providers.dart';

/// Widget that shows user presence status as a colored dot
class PresenceIndicator extends ConsumerWidget {
  final String userId;
  final double size;
  final bool showBorder;

  const PresenceIndicator({
    super.key,
    required this.userId,
    this.size = 12,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presenceService = ref.watch(presenceServiceProvider);

    return StreamBuilder<UserPresence?>(
      stream: presenceService.getUserPresence(userId),
      builder: (context, snapshot) {
        final presence = snapshot.data;
        final status = presence?.status ?? PresenceStatus.offline;

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusColor(status),
            border: showBorder
                ? Border.all(
                    color: Colors.white,
                    width: size * 0.15,
                  )
                : null,
          ),
        );
      },
    );
  }

  Color _getStatusColor(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return Colors.green;
      case PresenceStatus.away:
        return Colors.orange;
      case PresenceStatus.busy:
        return Colors.red;
      case PresenceStatus.offline:
        return Colors.grey;
    }
  }
}

/// Widget that shows presence with text label
class PresenceIndicatorWithLabel extends ConsumerWidget {
  final String userId;

  const PresenceIndicatorWithLabel({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presenceService = ref.watch(presenceServiceProvider);

    return StreamBuilder<UserPresence?>(
      stream: presenceService.getUserPresence(userId),
      builder: (context, snapshot) {
        final presence = snapshot.data;
        final status = presence?.status ?? PresenceStatus.offline;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PresenceIndicator(userId: userId, size: 10),
            const SizedBox(width: 6),
            Text(
              _getStatusText(status),
              style: TextStyle(
                color: _getStatusColor(status),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  String _getStatusText(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return 'Online';
      case PresenceStatus.away:
        return 'Away';
      case PresenceStatus.busy:
        return 'Busy';
      case PresenceStatus.offline:
        return 'Offline';
    }
  }

  Color _getStatusColor(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return Colors.green;
      case PresenceStatus.away:
        return Colors.orange;
      case PresenceStatus.busy:
        return Colors.red;
      case PresenceStatus.offline:
        return Colors.grey;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/room/services/user_presence_service.dart';

/// User Presence Indicator Widget
///
/// Features:
/// - Online status indicator
/// - Typing indicators
/// - Last seen timestamp
/// - Status colors
class UserPresenceIndicator extends ConsumerWidget {
  final UserPresence presence;
  final double size;
  final bool showLastSeen;

  const UserPresenceIndicator({
    super.key,
    required this.presence,
    this.size = 24,
    this.showLastSeen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: size / 2,
              backgroundImage: presence.avatarUrl.isNotEmpty
                  ? NetworkImage(presence.avatarUrl)
                  : null,
              child: presence.avatarUrl.isEmpty
                  ? Text(presence.displayName[0].toUpperCase())
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.35,
                height: size * 0.35,
                decoration: BoxDecoration(
                  color: _getStatusColor(presence.status),
                  border: Border.all(
                    color: const Color(0xFF1E1E2F),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ),
        if (showLastSeen) ...[
          const SizedBox(height: 4),
          Text(
            _getStatusText(presence),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }

  Color _getStatusColor(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return Colors.green;
      case PresenceStatus.away:
        return Colors.yellow;
      case PresenceStatus.offline:
        return Colors.grey;
      case PresenceStatus.doNotDisturb:
        return Colors.red;
    }
  }

  String _getStatusText(UserPresence presence) {
    if (presence.isTyping) {
      return 'typing...';
    }

    switch (presence.status) {
      case PresenceStatus.online:
        return 'Online';
      case PresenceStatus.away:
        return 'Away';
      case PresenceStatus.offline:
        return 'Offline';
      case PresenceStatus.doNotDisturb:
        return 'Do Not Disturb';
    }
  }
}

/// Typing Indicator Widget
///
/// Shows a typing indicator animation for users who are typing
class TypingIndicator extends StatefulWidget {
  final String userName;
  final bool isTyping;

  const TypingIndicator({
    super.key,
    required this.userName,
    this.isTyping = true,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;

  @override
  void initState() {
    super.initState();
    _animationControllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    if (widget.isTyping) {
      for (var i = 0; i < _animationControllers.length; i++) {
        _animationControllers[i].repeat(
          min: 0,
          max: 1,
          reverse: true,
          period: Duration(
            milliseconds: 600 + (i * 100),
          ),
        );
      }
    }
  }

  @override
  void didUpdateWidget(TypingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTyping && !oldWidget.isTyping) {
      for (var controller in _animationControllers) {
        controller.repeat(reverse: true);
      }
    } else if (!widget.isTyping && oldWidget.isTyping) {
      for (var controller in _animationControllers) {
        controller.stop();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isTyping) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Text(
          '${widget.userName} is typing',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 6),
        Row(
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _animationControllers[index],
              builder: (context, child) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        Colors.grey[600],
                        Colors.grey[300],
                        _animationControllers[index].value,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

/// Room Presence Panel Widget
///
/// Displays all users in a room with their presence status
class RoomPresencePanelWidget extends ConsumerWidget {
  final String roomId;

  const RoomPresencePanelWidget({
    super.key,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomPresenceAsync = ref.watch(roomPresenceProvider(roomId));
    final typingUsersAsync = ref.watch(typingUsersProvider(roomId));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF4C4C).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(
                Icons.people,
                color: Color(0xFFFF4C4C),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Who\'s Online',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          roomPresenceAsync.when(
            data: (presences) {
              if (presences.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No one online',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                );
              }

              return Column(
                children: presences.map((presence) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: presence.avatarUrl.isNotEmpty
                                  ? NetworkImage(presence.avatarUrl)
                                  : null,
                              child: presence.avatarUrl.isEmpty
                                  ? Text(
                                      presence.displayName[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 10),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(presence.status),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFF1E1E2F),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                presence.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (presence.isTyping)
                                Text(
                                  'typing...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox(
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF4C4C),
                    ),
                  ),
                ),
              ),
            ),
            error: (error, __) => Text(
              'Error loading presence',
              style: TextStyle(color: Colors.red[300], fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          typingUsersAsync.whenData((typingUsers) {
                if (typingUsers.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: typingUsers.map((user) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TypingIndicator(
                        userName: user.displayName,
                        isTyping: true,
                      ),
                    );
                  }).toList(),
                );
              }).value ??
              const SizedBox.shrink(),
        ],
      ),
    );
  }

  Color _getStatusColor(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return Colors.green;
      case PresenceStatus.away:
        return Colors.yellow;
      case PresenceStatus.offline:
        return Colors.grey;
      case PresenceStatus.doNotDisturb:
        return Colors.red;
    }
  }
}


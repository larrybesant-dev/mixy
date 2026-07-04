import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/presence_provider.dart';
import '../../../core/theme.dart';

/// Widget to display user's online status in chat header
class UserStatusBadge extends ConsumerWidget {
  final String userId;
  final String userName;
  final String? avatarUrl;

  const UserStatusBadge({
    required this.userId,
    required this.userName,
    this.avatarUrl,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presenceAsync = ref.watch(userPresenceProvider(userId));

    return presenceAsync.when(
      loading: () => _buildStatus(context, userName, 'Checking...', Colors.grey),
      error: (_, __) => _buildStatus(context, userName, userName, Colors.grey),
      data: (presence) {
        final status = presence?.getStatusText() ?? 'Offline';
        final statusColor = presence?.isOnline == true
            ? Colors.green
            : Colors.grey;

        return _buildStatus(context, userName, status, statusColor);
      },
    );
  }

  Widget _buildStatus(
    BuildContext context,
    String name,
    String status,
    Color statusColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: statusColor,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Widget to display typing indicator
class TypingIndicator extends StatelessWidget {
  final List<String> typingUserIds;
  final Map<String, String> userNames; // userId -> userName mapping

  const TypingIndicator({
    required this.typingUserIds,
    required this.userNames,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (typingUserIds.isEmpty) return const SizedBox.shrink();

    final typingNames = typingUserIds
        .map((id) => userNames[id] ?? 'Someone')
        .toList();

    final displayText = typingNames.length == 1
        ? '${typingNames[0]} is typing'
        : typingNames.length == 2
            ? '${typingNames[0]} and ${typingNames[1]} are typing'
            : '${typingNames.take(2).join(', ')} and ${typingNames.length - 2} others are typing';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(
            displayText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            height: 16,
            child: _buildAnimatedDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDots() {
    return const _AnimatedTypingDots();
  }
}

/// Animated typing dots
class _AnimatedTypingDots extends StatefulWidget {
  const _AnimatedTypingDots();

  @override
  State<_AnimatedTypingDots> createState() => _AnimatedTypeingDotsState();
}

class _AnimatedTypeingDotsState extends State<_AnimatedTypingDots>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final animation = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(
              index * 0.2,
              (index + 1) * 0.2 + 0.5,
              curve: Curves.easeInOut,
            ),
          ),
        );

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -4 * animation.value),
              child: child,
            );
          },
          child: Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey,
            ),
          ),
        );
      }),
    );
  }
}

/// Widget to display message delivery/read status
class MessageStatusIcon extends StatelessWidget {
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final bool isPending;

  const MessageStatusIcon({
    this.deliveredAt,
    this.readAt,
    this.isPending = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (isPending) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1),
        ),
      );
    }

    if (readAt != null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.done_all, size: 14, color: VelvetNoir.primary),
      );
    }

    if (deliveredAt != null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.done_all, size: 14, color: Colors.grey),
      );
    }

    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.done, size: 14, color: Colors.grey),
    );
  }
}

/// Tooltip showing detailed delivery/read status
class MessageStatusTooltip extends StatelessWidget {
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  const MessageStatusTooltip({
    this.createdAt,
    this.deliveredAt,
    this.readAt,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _buildStatusText(),
      child: MessageStatusIcon(
        deliveredAt: deliveredAt,
        readAt: readAt,
      ),
    );
  }

  String _buildStatusText() {
    if (readAt != null) {
      return 'Read at ${_formatTime(readAt!)}';
    }
    if (deliveredAt != null) {
      return 'Delivered at ${_formatTime(deliveredAt!)}';
    }
    if (createdAt != null) {
      return 'Sent at ${_formatTime(createdAt!)}';
    }
    return 'Pending';
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/shared/providers/providers.dart';

/// Widget that shows who is typing in a room/chat
class TypingIndicatorWidget extends ConsumerWidget {
  final String roomId;
  final String? currentUserId;

  const TypingIndicatorWidget({
    super.key,
    required this.roomId,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typingService = ref.watch(typingServiceProvider);
    final userId = currentUserId ?? '';

    return StreamBuilder(
      stream: typingService.getTypingIndicators(roomId, userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data;
        if (data == null) {
          return const SizedBox.shrink();
        }

        final typingUsers =
            data.map((indicator) => indicator.userName).take(3).toList();

        if (typingUsers.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildTypingAnimation(),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _getTypingText(typingUsers),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getTypingText(List<String> users) {
    if (users.length == 1) {
      return '${users[0]} is typing...';
    } else if (users.length == 2) {
      return '${users[0]} and ${users[1]} are typing...';
    } else if (users.length == 3) {
      return '${users[0]}, ${users[1]}, and ${users[2]} are typing...';
    } else {
      return 'Several people are typing...';
    }
  }

  Widget _buildTypingAnimation() {
    return const SizedBox(
      width: 24,
      height: 12,
      child: _TypingDots(),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final opacity =
                ((_controller.value + delay) % 1.0) < 0.5 ? 0.3 : 1.0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

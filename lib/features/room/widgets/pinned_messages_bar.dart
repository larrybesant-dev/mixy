import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/providers/chat_providers.dart';

class PinnedMessagesBar extends ConsumerWidget {
  final String roomId;
  final VoidCallback? onViewAll;

  const PinnedMessagesBar({
    super.key,
    required this.roomId,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedAsync = ref.watch(pinnedMessagesProvider(roomId));

    return pinnedAsync.when(
      data: (pinned) {
        if (pinned.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          color: Colors.amber[50],
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.push_pin, size: 14, color: Colors.amber[700]),
                  const SizedBox(width: 6),
                  Text(
                    'Pinned Messages',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[800],
                    ),
                  ),
                  const Spacer(),
                  if (pinned.length > 1)
                    TextButton(
                      onPressed: onViewAll,
                      child: Text(
                        '${pinned.length} messages',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.amber[700],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              ...pinned.take(2).map((msg) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${msg.senderId}: ${msg.content.substring(0, Math.min(60, msg.content.length))}${msg.content.length > 60 ? '...' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// Helper for Math.min
class Math {
  static int min(int a, int b) => a < b ? a : b;
}


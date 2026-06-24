import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/shared/providers/mic_providers.dart';

class MicQueueIndicator extends ConsumerWidget {
  final String roomId;
  final int maxMics;

  const MicQueueIndicator({
    super.key,
    required this.roomId,
    this.maxMics = 5,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(activeMicCountProvider(roomId));
    final pendingAsync = ref.watch(pendingMicCountProvider(roomId));

    return countAsync.when(
      data: (count) {
        final pendingCount = pendingAsync.maybeWhen(
          data: (pending) => pending,
          orElse: () => 0,
        );
        final isAtCapacity = count >= maxMics;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isAtCapacity ? Colors.orange[50] : Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAtCapacity ? Colors.orange[300]! : Colors.blue[300]!,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mic,
                    color: isAtCapacity ? Colors.orange : Colors.blue,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ðŸŽ¤ Mics: $count/$maxMics',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          isAtCapacity ? Colors.orange[700] : Colors.blue[700],
                      fontSize: 12,
                    ),
                  ),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'â³ $pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (isAtCapacity)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'ðŸ”´ Mic queue full',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange[600],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 6),
            Text(
              'Loading...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[400],
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Error',
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

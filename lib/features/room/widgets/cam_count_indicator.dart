import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/shared/providers/camera_providers.dart';

class CamCountIndicator extends ConsumerWidget {
  final String roomId;
  final int maxCameras;

  const CamCountIndicator({
    super.key,
    required this.roomId,
    this.maxCameras = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(activeCameraCountProvider(roomId));

    return countAsync.when(
      data: (count) {
        final isAtCapacity = count >= maxCameras;
        final percentFull = (count / maxCameras * 100).toInt();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isAtCapacity ? Colors.red[50] : Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAtCapacity ? Colors.red[300]! : Colors.blue[300]!,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam,
                    color: isAtCapacity ? Colors.red : Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ðŸŽ¥ Cameras: $count/$maxCameras',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isAtCapacity ? Colors.red[700] : Colors.blue[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: count / maxCameras,
                  backgroundColor:
                      isAtCapacity ? Colors.red[200] : Colors.blue[200],
                  valueColor: AlwaysStoppedAnimation(
                    isAtCapacity ? Colors.red[600] : Colors.blue[600],
                  ),
                  minHeight: 6,
                ),
              ),

              const SizedBox(height: 8),

              // Status message
              Text(
                isAtCapacity
                    ? 'ðŸ”´ Room at camera capacity'
                    : 'ðŸ“Š $percentFull% full',
                style: TextStyle(
                  fontSize: 12,
                  color: isAtCapacity ? Colors.red[600] : Colors.blue[600],
                ),
              ),

              // Available slots
              if (!isAtCapacity)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${maxCameras - count} slots available',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
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
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
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
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Error loading',
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/providers/camera_providers.dart';
import 'camera_tile.dart';

class CameraGrid extends ConsumerWidget {
  final String roomId;
  final int maxCameras;
  final bool showSpotlight;
  final Function(String) onCameraSelected;

  const CameraGrid({
    super.key,
    required this.roomId,
    this.maxCameras = 20,
    this.showSpotlight = false,
    required this.onCameraSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camerasAsync = ref.watch(activeCamerasProvider(roomId));

    return camerasAsync.when(
      data: (cameras) {
        if (cameras.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No active cameras',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        // Responsive grid
        final crossAxisCount = _getGridCrossAxisCount(context);
        const childAspectRatio = 16 / 9; // 16:9 aspect ratio for cameras

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: cameras.length,
          itemBuilder: (context, index) {
            final camera = cameras[index];
            return CameraTile(
              cameraState: camera,
              roomId: roomId,
              isSpotlighted: showSpotlight && camera.isSpotlighted,
              onSelected: () => onCameraSelected(camera.uid),
            );
          },
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading cameras...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading cameras',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Get responsive grid column count
  int _getGridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      // Mobile: 2 columns
      return 2;
    } else if (width < 1000) {
      // Tablet: 3 columns
      return 3;
    } else {
      // Desktop: 4 columns
      return 4;
    }
  }
}


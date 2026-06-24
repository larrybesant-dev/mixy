import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/models/camera_state.dart';

class SpotlightView extends ConsumerWidget {
  final CameraState cameraState;
  final String roomId;
  final List<CameraState> availableCameras;
  final Function(CameraState) onCameraSwitch;
  final VoidCallback onClose;

  const SpotlightView({
    super.key,
    required this.cameraState,
    required this.roomId,
    required this.availableCameras,
    required this.onCameraSwitch,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherCameras =
        availableCameras.where((cam) => cam.uid != cameraState.uid).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (didPop) return;
        onClose();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black87,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
          title: Text(cameraState.userName),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Chip(
                avatar: Icon(
                  _getStatusIcon(),
                  size: 16,
                  color: _getStatusColor(),
                ),
                label: Text(_getStatusText()),
                backgroundColor: Colors.grey[800],
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Main camera view
            Expanded(
              child: Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    // Video placeholder
                    Center(
                      child: Icon(
                        Icons.videocam,
                        size: 120,
                        color: Colors.grey[700],
                      ),
                    ),

                    // Camera info overlay
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  cameraState.userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (cameraState.isVIP)
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.visibility,
                                  color: Colors.grey[400],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${cameraState.viewCount} views',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(
                                  Icons.timer,
                                  color: Colors.grey[400],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${cameraState.uptimeSeconds ~/ 60} min',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Thumbnail gallery at bottom
            if (otherCameras.isNotEmpty)
              Container(
                height: 100,
                color: Colors.grey[900],
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: otherCameras.length,
                  itemBuilder: (context, index) {
                    final camera = otherCameras[index];
                    return GestureDetector(
                      onTap: () => onCameraSwitch(camera),
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.grey[700]!, width: 1),
                          color: Colors.black87,
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Icon(
                                Icons.videocam,
                                color: Colors.grey[600],
                                size: 32,
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              left: 4,
                              right: 4,
                              child: Text(
                                camera.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (cameraState.status) {
      case CameraStatus.active:
        return Icons.fiber_manual_record;
      case CameraStatus.loading:
        return Icons.hourglass_empty;
      case CameraStatus.frozen:
        return Icons.ac_unit;
      case CameraStatus.error:
        return Icons.warning;
      case CameraStatus.inactive:
        return Icons.circle_outlined;
    }
  }

  Color _getStatusColor() {
    switch (cameraState.status) {
      case CameraStatus.active:
        return Colors.green;
      case CameraStatus.loading:
        return Colors.orange;
      case CameraStatus.frozen:
        return Colors.red;
      case CameraStatus.error:
        return Colors.red;
      case CameraStatus.inactive:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (cameraState.status) {
      case CameraStatus.active:
        return 'LIVE';
      case CameraStatus.loading:
        return 'LOADING';
      case CameraStatus.frozen:
        return 'FROZEN';
      case CameraStatus.error:
        return 'ERROR';
      case CameraStatus.inactive:
        return 'OFFLINE';
    }
  }
}


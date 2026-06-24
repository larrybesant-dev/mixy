import 'package:flutter/material.dart';
import 'package:mixvy/shared/models/camera_state.dart';

class FreezeDetector extends StatelessWidget {
  final CameraState cameraState;
  final VoidCallback onFrozenDetected;

  const FreezeDetector({
    super.key,
    required this.cameraState,
    required this.onFrozenDetected,
  });

  @override
  Widget build(BuildContext context) {
    // Trigger callback if frozen
    if (cameraState.isFrozen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onFrozenDetected();
      });
    }

    // Don't render anything - this is a utility widget
    return const SizedBox.shrink();
  }

  /// Check if camera appears frozen
  static bool checkIfFrozen(CameraState camera) {
    return camera.isFrozen;
  }

  /// Get frozen status text
  static String getFrozenStatusText(CameraState camera) {
    if (camera.isFrozen) {
      return 'â„ï¸ FROZEN - No video feed';
    }
    return 'âœ… Streaming normally';
  }
}


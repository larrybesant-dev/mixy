import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:mixvy/features/room/widgets/video_grid_layout.dart';

/// Video tile states for display
enum VideoTileState {
  loading,
  active,
  cameraOff,
  permissionDenied,
  error,
}

/// A standardized video tile widget with proper state handling and active speaker highlight
class VideoTile extends StatelessWidget {
  final VideoViewController? controller;
  final String displayName;
  final String avatarUrl;
  final VideoTileState state;
  final VoidCallback? onRetry;
  final bool isActiveSpeaker;
  final bool isMuted;
  final String? userId;

  const VideoTile({
    super.key,
    this.controller,
    required this.displayName,
    required this.avatarUrl,
    this.state = VideoTileState.loading,
    this.onRetry,
    this.isActiveSpeaker = false,
    this.isMuted = false,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: VideoGridLayout.getTileBorderRadius(),
        border: Border.all(
          color: isActiveSpeaker
              ? VideoGridLayout.getActiveSpeakerGlowColor()
              : VideoGridLayout.getTileBorderColor(),
          width: isActiveSpeaker
              ? VideoGridLayout.getActiveSpeakerBorderWidth()
              : VideoGridLayout.getDefaultBorderWidth(),
        ),
        boxShadow: isActiveSpeaker
            ? VideoGridLayout.getActiveSpeakerShadow()
            : VideoGridLayout.getDefaultShadow(),
      ),
      child: ClipRRect(
        borderRadius: VideoGridLayout.getTileBorderRadius(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildContent(),
            // Active speaker badge
            if (isActiveSpeaker)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: VideoGridLayout.getActiveSpeakerGlowColor()
                        .withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.graphic_eq, size: 12, color: Colors.black),
                      SizedBox(width: 4),
                      Text(
                        'Speaking',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Name tag at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (isMuted)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.mic_off,
                            size: 14,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (state) {
      case VideoTileState.loading:
        return _buildLoadingState();
      case VideoTileState.active:
        return _buildActiveState();
      case VideoTileState.cameraOff:
        return _buildCameraOffState();
      case VideoTileState.permissionDenied:
        return _buildPermissionDeniedState();
      case VideoTileState.error:
        return _buildErrorState();
    }
  }

  Widget _buildLoadingState() {
    return Container(
      color: VideoGridLayout.getTileBackgroundColor(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: VideoGridLayout.getActiveSpeakerGlowColor(),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Connecting video...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveState() {
    if (controller != null) {
      return AgoraVideoView(controller: controller!);
    }

    return Container(
      color: VideoGridLayout.getTileBackgroundColor(),
      child: const Center(
        child: Text(
          'Video not available',
          style: TextStyle(color: Colors.white54),
        ),
      ),
    );
  }

  Widget _buildCameraOffState() {
    return Container(
      color: VideoGridLayout.getTileBackgroundColor(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
                image: avatarUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatarUrl.isEmpty
                  ? const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white54,
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam_off,
                  size: 16,
                  color: Colors.white54,
                ),
                SizedBox(width: 6),
                Text(
                  'Camera off',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedState() {
    return Container(
      color: const Color(0xFF1E1E2F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            const Text(
              'Permission denied',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4C4C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: const Color(0xFF1E1E2F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error,
              size: 48,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 12),
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            const Text(
              'Video failed to load',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


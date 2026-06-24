import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:mixvy/services/camera/camera_permission_service.dart';
import 'package:mixvy/shared/providers/all_providers.dart';
import '../widgets/camera_permission_request_dialog.dart';

class PermissionAwareVideoView extends ConsumerStatefulWidget {
  final String ownerId;
  final String ownerName;
  final int uid;
  final String? channelId;
  final VideoViewController? controller;

  const PermissionAwareVideoView({
    super.key,
    required this.ownerId,
    required this.ownerName,
    required this.uid,
    this.channelId,
    this.controller,
  });

  @override
  ConsumerState<PermissionAwareVideoView> createState() =>
      _PermissionAwareVideoViewState();
}

class _PermissionAwareVideoViewState
    extends ConsumerState<PermissionAwareVideoView> {
  bool _hasPermission = false;
  bool _isCheckingPermission = true;
  bool _isRequestingPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() => _isCheckingPermission = true);

    try {
      final hasPermission = await CameraPermissionService().hasPermission(
        ownerId: widget.ownerId,
        channelId: widget.channelId,
      );

      if (mounted) {
        setState(() {
          _hasPermission = hasPermission;
          _isCheckingPermission = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking permission: $e');
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isCheckingPermission = false;
        });
      }
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _isRequestingPermission = true);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CameraPermissionRequestDialog(
        ownerId: widget.ownerId,
        ownerName: widget.ownerName,
        channelId: widget.channelId,
      ),
    );

    if (result == true) {
      // Request sent, show waiting message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Request sent. Waiting for ${widget.ownerName} to respond...'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    setState(() => _isRequestingPermission = false);
  }

  @override
  Widget build(BuildContext context) {
    final agoraService = ref.watch(agoraVideoServiceProvider);

    // Loading state - checking Firestore permissions
    if (_isCheckingPermission) {
      return Container(
        color: const Color(0xFF1E1E2F),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: Color(0xFFFF4C4C),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Checking permissions...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Browser camera/mic permission denied state
    if (agoraService.isCameraPermissionDenied ||
        agoraService.isMicPermissionDenied) {
      final isPermanentlyDenied =
          agoraService.isCameraPermissionPermanentlyDenied ||
              agoraService.isMicPermissionPermanentlyDenied;

      return Container(
        color: const Color(0xFF1E1E2F),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.ownerName}\'s camera',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (isPermanentlyDenied)
                const Column(
                  children: [
                    Text(
                      'Camera blocked in browser settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please unblock camera access in browser settings to view this video',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    const Text(
                      'Permission required to view camera',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed:
                          _isRequestingPermission ? null : _requestPermission,
                      icon: const Icon(Icons.videocam),
                      label: const Text('Grant Camera Access'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4C4C),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    // Firestore permission not granted state
    if (!_hasPermission) {
      return Container(
        color: const Color(0xFF1E1E2F),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam_off,
                size: 64,
                color: Colors.white30,
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.ownerName}\'s camera',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Permission required to view',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isRequestingPermission ? null : _requestPermission,
                icon: const Icon(Icons.lock_open),
                label: const Text('Request Access'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4C4C),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Has permission - show video
    if (widget.controller != null) {
      return AgoraVideoView(controller: widget.controller!);
    }

    // Create default controller
    if (agoraService.engine == null) {
      return Container(
        color: const Color(0xFF1E1E2F),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: Color(0xFFFF4C4C),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Initializing video engine...',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    // Create controller based on whether we have a channelId
    final controller = widget.channelId != null
        ? VideoViewController.remote(
            rtcEngine: agoraService.engine!,
            canvas: VideoCanvas(uid: widget.uid),
            connection: RtcConnection(channelId: widget.channelId!),
          )
        : VideoViewController.remote(
            rtcEngine: agoraService.engine!,
            canvas: VideoCanvas(uid: widget.uid),
            connection: RtcConnection(channelId: widget.channelId!),
          );

    return AgoraVideoView(controller: controller);
  }
}


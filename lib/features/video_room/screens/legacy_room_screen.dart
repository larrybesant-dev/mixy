// lib/screens/room_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/shared/providers/agora_provider.dart';
import 'package:mixmingle/core/diagnostics/agora_diagnostics.dart';
import '../widgets/agora_video_preview.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String appId;
  final String channelName;
  final int uid;

  const RoomScreen({
    super.key,
    required this.appId,
    required this.channelName,
    required this.uid,
  });

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  AgoraDiagnosticsResult? _diagnosticsResult;
  bool _showDiagnostics = false;
  bool _isMuted = false;
  bool _isCameraOn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mix & Mingle Room',
            style: Theme.of(context).textTheme.titleLarge),
        backgroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.blueAccent),
            onPressed: () =>
                setState(() => _showDiagnostics = !_showDiagnostics),
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            onPressed: _leaveRoom,
          ),
        ],
      ),
      body: Stack(
        children: [
          AgoraVideoPreview(channelName: widget.channelName, uid: widget.uid),
          if (_showDiagnostics && _diagnosticsResult != null)
            Positioned(
              top: 16,
              right: 16,
              child: _DiagnosticsOverlay(result: _diagnosticsResult!),
            ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_isMuted ? Icons.mic_off : Icons.mic,
                      color: Colors.white),
                  onPressed: () => setState(() => _isMuted = !_isMuted),
                ),
                IconButton(
                  icon: Icon(_isCameraOn ? Icons.videocam : Icons.videocam_off,
                      color: Colors.white),
                  onPressed: () => setState(() => _isCameraOn = !_isCameraOn),
                ),
                IconButton(
                  icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                  onPressed: _leaveRoom,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveRoom() async {
    try {
      await ref.read(agoraServiceProvider).leaveChannel();
    } catch (e) {
      debugPrint('[RoomScreen] Leave error: $e');
    }
    if (mounted) Navigator.of(context).pop();
  }
}

class _DiagnosticsOverlay extends StatelessWidget {
  final AgoraDiagnosticsResult result;
  const _DiagnosticsOverlay({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Agora Diagnostics',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Permissions OK: ${result.permissionsOk}',
                style: const TextStyle(color: Colors.white70)),
            Text('Platform Supported: ${result.platformSupported}',
                style: const TextStyle(color: Colors.white70)),
            ...result.warnings.map((w) => Text('Warning: $w',
                style: const TextStyle(color: Colors.orange))),
            ...result.errors.map((e) =>
                Text('Error: $e', style: const TextStyle(color: Colors.red))),
            if (result.isHealthy)
              const Text('Status: Healthy',
                  style: TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}

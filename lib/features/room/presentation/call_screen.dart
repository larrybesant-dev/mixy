import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../services/webrtc_room_service.dart'; 
import '../../../core/streams/stream_lifecycle_manager.dart';
import '../../auth/controllers/auth_controller.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  late final WebRtcRoomService _signaling;
  final TextEditingController _roomIdController = TextEditingController();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  String? _roomId;

  @override
  void initState() {
    super.initState();
    _signaling = WebRtcRoomService(
      firestore: ref.read(firestoreProvider),
      localUserId: ref.read(authControllerProvider).uid ?? 'legacy_call',
      streamLifecycleManager: ref.read(streamLifecycleManagerProvider),
    );
    
    _localRenderer.initialize();

    _signaling.onLocalVideoCaptureChanged = () async {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        setState(() {});
      }
    };

    _signaling.onRemoteUserJoined = () {
      if (mounted) {
        setState(() {});
      }
    };

    _signaling.onRemoteUserLeft = () {
      if (mounted) {
        setState(() {});
      }
    };

    _signaling.initializeProductionNetworking();
  }

  Future<void> _openCamera() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {'facingMode': 'user'}
    };
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = _localStream;
    await _signaling.enableVideo(true);
    
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startCall() async {
    if (_localStream == null) await _openCamera();
    
    final id = await _signaling.createRoom(_localStream!, (remoteStream) {
      if (mounted) setState(() {});
    });
    
    setState(() {
      _roomId = id;
      _roomIdController.text = id;
    });
  }

  Future<void> _joinCall() async {
    final targetRoomId = _roomIdController.text.trim();
    if (targetRoomId.isEmpty) return;
    
    if (_localStream == null) await _openCamera();
    
    await _signaling.joinRoomById(targetRoomId, _localStream!, (remoteStream) {
      if (mounted) setState(() {});
    });
    
    setState(() {
      _roomId = targetRoomId;
    });
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    _localRenderer.dispose();
    _localStream?.dispose();
    _signaling.disposeAll(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<int> activeRemotePeers = _signaling.remoteUids;
    final bool showingLocalCam = _signaling.isLocalVideoCapturing;

    return Scaffold(
      appBar: AppBar(title: const Text('MixVy Secure Call')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFF121214), 
              padding: const EdgeInsets.all(8.0),
              child: _buildAdaptiveVideoGrid(showingLocalCam, activeRemotePeers),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0, left: 16.0, right: 16.0),
            child: Column(
              children: [
                Text('Room ID: ${_roomId ?? "Not connected"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _roomIdController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Room ID here to join',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _openCamera();
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      icon: Icon(_signaling.isLocalVideoCapturing ? Icons.videocam : Icons.videocam_off),
                      label: const Text('1. Camera'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _startCall,
                      icon: const Icon(Icons.add_call),
                      label: const Text('2. Create Call'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _joinCall,
                      icon: const Icon(Icons.call_received),
                      label: const Text('3. Join Call'),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAdaptiveVideoGrid(bool showLocal, List<int> remotePeers) {
    const int totalGridSlots = 16;
    final List<Widget> structuralTiles = [];

    Widget localTile = Container(
      color: const Color(0xFF1E1E24),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white24, size: 40),
      ),
    );

    if (showLocal) {
      localTile = Stack(
        children: [
          SizedBox.expand(child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: Colors.black87, 
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              child: const Text(
                'Curve (You)', 
                style: TextStyle(color: Color(0xFF00E6FF), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }
    structuralTiles.add(localTile);

    if (remotePeers.isNotEmpty) {
      for (final int uid in remotePeers) {
        structuralTiles.add(
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              color: Colors.black,
              child: _signaling.getRemoteView(uid, _roomId ?? ''),
            ),
          ),
        );
      }
    }

    while (structuralTiles.length < totalGridSlots) {
      structuralTiles.add(
        Container(
          color: const Color(0xFF16161A), 
          child: const Center(
            child: Icon(Icons.person, color: Colors.white10, size: 32),
          ),
        ),
      );
    }

    return GridView.builder(
      itemCount: totalGridSlots,
      physics: const NeverScrollableScrollPhysics(), 
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,         
        crossAxisSpacing: 4,       
        mainAxisSpacing: 4,
        childAspectRatio: 4 / 3,   
      ),
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: structuralTiles[index],
        );
      },
    );
  }
}




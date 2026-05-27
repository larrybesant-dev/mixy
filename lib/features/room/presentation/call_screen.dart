import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../services/webrtc_room_service.dart'; 

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // 1. Initialize our hardened engine
  final WebRTCRoomService _signaling = WebRTCRoomService();
  
  // 2. These renderers are the "TV screens" that show the video
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final TextEditingController _roomIdController = TextEditingController();

  MediaStream? _localStream;
  String? _roomId;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    // Warm up the production servers
    _signaling.initializeProductionNetworking();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  // 3. Ask for permissions and turn on the camera
  Future<void> _openCamera() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user', // Uses the front camera
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = _localStream;
    setState(() {}); // Tell Flutter to redraw the screen with the video
  }

  // 4. Phone A: Creates the room
  Future<void> _startCall() async {
    if (_localStream == null) await _openCamera();
    
    final id = await _signaling.createRoom(_localStream!, (remoteStream) {
      // When Phone B connects, put their video on the remote screen
      setState(() {
        _remoteRenderer.srcObject = remoteStream;
      });
    });

    setState(() {
      _roomId = id;
      _roomIdController.text = id;
    });
  }

  // 5. Phone B: Joins the room
  Future<void> _joinCall() async {
    if (_localStream == null) await _openCamera();
    
    await _signaling.joinRoom(
      _roomIdController.text.trim(),
      _localStream!,
      (remoteStream) {
        // When connected to Phone A, put their video on the remote screen
        setState(() {
          _remoteRenderer.srcObject = remoteStream;
        });
      },
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _signaling.disposeAll(); // Cleans up the hardware locks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MixVy Secure Call')),
      body: Column(
        children: [
          // TOP HALF: The Video Screens
          Expanded(
            child: Row(
              children: [
                // Our Camera
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: RTCVideoView(_localRenderer, mirror: true),
                  ),
                ),
                // Their Camera
                Expanded(
                  child: Container(
                    color: Colors.black87,
                    child: RTCVideoView(_remoteRenderer),
                  ),
                ),
              ],
            ),
          ),
          
          // BOTTOM HALF: The Controls
          Padding(
            padding: const EdgeInsets.all(16.0),
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
                    ElevatedButton(
                      onPressed: _openCamera,
                      child: const Text('1. Camera'),
                    ),
                    ElevatedButton(
                      onPressed: _startCall,
                      child: const Text('2. Create Call'),
                    ),
                    ElevatedButton(
                      onPressed: _joinCall,
                      child: const Text('3. Join Call'),
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
}

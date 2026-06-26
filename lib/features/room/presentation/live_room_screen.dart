import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/room_model.dart';
import '../../../core/theme.dart';
import '../providers/room_webrtc_provider.dart';

class LiveRoomScreen extends ConsumerStatefulWidget {
  final String roomId;

  const LiveRoomScreen({
    super.key,
    required this.roomId,
  });

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen>
    with WidgetsBindingObserver {
  late TextEditingController messageController;
  late ScrollController scrollController;
  bool _hasJoined = false;
  bool _isVideoEnabled = false;
  bool _isAudioEnabled = false;
  bool _isAudioSharingEnabled = false;
  List<String> _remoteUsers = [];
  bool _isHost = false;
  final Map<String, String> _userDisplayNames = {};

  @override
  void initState() {
    super.initState();
    messageController = TextEditingController();
    scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    messageController.dispose();
    scrollController.dispose();
    if (_hasJoined) {
      _leaveRoom();
    }
    super.dispose();
  }

  Future<void> _joinRoom(String uid, String username) async {
    try {
      final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
      
      // Create participant doc (required for chat permissions)
      await roomRef.collection('participants').doc(uid).set({
        'userId': uid,
        'role': 'audience',
        'micOn': true,
        'cameraOn': true,
        'camOn': true,
        'isMuted': false,
        'isBanned': false,
        'userStatus': 'joined',
        'displayName': username,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update room with user
      await roomRef.update({
        'audienceUserIds': FieldValue.arrayUnion([uid]),
        'memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Initialize WebRTC
      final notifier = ref.read(activeRoomWebRTCProvider(widget.roomId).notifier);
      await notifier.joinAsAudience();

      // Update local display name cache
      _userDisplayNames[uid] = username;

      setState(() => _hasJoined = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Successfully joined room'),
            backgroundColor: VelvetNoir.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error joining room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveRoom() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
      
      // Delete participant doc
      await roomRef.collection('participants').doc(currentUser.uid).delete();
      
      // Update room
      await roomRef.update({
        'audienceUserIds': FieldValue.arrayRemove([currentUser.uid]),
        'memberCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ref.read(activeRoomWebRTCProvider(widget.roomId).notifier).disconnect();
      setState(() => _hasJoined = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Left the room'),
            backgroundColor: VelvetNoir.secondary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error leaving room: $e');
    }
  }

  void _toggleVideo(bool enabled) {
    setState(() => _isVideoEnabled = enabled);
    ref.read(activeRoomWebRTCProvider(widget.roomId).notifier).toggleVideo(enabled);
  }

  void _toggleAudio(bool enabled) {
    setState(() => _isAudioEnabled = enabled);
    ref.read(activeRoomWebRTCProvider(widget.roomId).notifier).toggleAudio(enabled);
  }

  void _toggleAudioSharing(bool enabled) {
    setState(() => _isAudioSharingEnabled = enabled);
    // TODO: Implement audio sharing setup with system audio capture
    // This would integrate with the WebRTC service to share desktop audio
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'userId': currentUser.uid,
        'username': _userDisplayNames[currentUser.uid] ?? 'Anonymous',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      messageController.clear();
      
      // Auto-scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void _shareRoom(String roomName) {
    Share.share(
      'Join me in "$roomName" on MIXVY!\nhttps://mixvy-v2.web.app/rooms/room/${widget.roomId}',
      subject: '$roomName – MIXVY live room',
    );
  }

  void _showPeopleSheet(List<String> participantIds) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Room Participants',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: VelvetNoir.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: participantIds.length,
                itemBuilder: (context, index) {
                  final userId = participantIds[index];
                  final displayName = _userDisplayNames[userId] ?? 'User $index';
                  return ListTile(
                    title: Text(displayName),
                    leading: CircleAvatar(
                      backgroundColor: VelvetNoir.primary,
                      child: Text(
                        displayName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    trailing: userId == FirebaseAuth.instance.currentUser?.uid
                        ? const Chip(
                            label: Text('You'),
                            backgroundColor: Color.fromARGB(255, 102, 255, 102),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDesktop = MediaQuery.of(context).size.width > 1200;

    return Scaffold(
      backgroundColor: VelvetNoir.surface,
      appBar: AppBar(
        backgroundColor: VelvetNoir.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_hasJoined)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _shareRoom('Live Room'),
              tooltip: 'Share room',
            ),
          if (_hasJoined && _remoteUsers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.people_outline),
              onPressed: () => _showPeopleSheet(_remoteUsers),
              tooltip: 'Participants',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: GoogleFonts.raleway(color: VelvetNoir.onSurface),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Room not found',
                style: GoogleFonts.raleway(color: VelvetNoir.onSurface),
              ),
            );
          }

          final room = RoomModel.fromJson(
            snapshot.data!.data() as Map<String, dynamic>,
            widget.roomId,
          );

          _isHost = room.hostId == currentUser?.uid;

          return isDesktop ? _buildDesktopLayout(room, currentUser) : _buildMobileLayout(room, currentUser);
        },
      ),
    );
  }

  Widget _buildMobileLayout(RoomModel room, User? currentUser) {
    return Column(
      children: [
        // Video Grid Area
        if (_hasJoined)
          _buildVideoArea()
        else
          _buildRoomPreview(room),
        
        // Room Info & Controls
        Expanded(
          child: Column(
            children: [
              _buildRoomHeader(room),
              Expanded(
                child: _buildChatArea(),
              ),
              _buildControlBar(room, currentUser),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(RoomModel room, User? currentUser) {
    return Row(
      children: [
        // Left: Video Grid
        Expanded(
          flex: 3,
          child: Column(
            children: [
              if (_hasJoined)
                Expanded(child: _buildVideoArea())
              else
                Expanded(child: _buildRoomPreview(room)),
              _buildControlBar(room, currentUser),
            ],
          ),
        ),
        VerticalDivider(color: VelvetNoir.surfaceHigh, width: 1),
        // Right: Chat
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildRoomHeader(room),
              Expanded(child: _buildChatArea()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoArea() {
    return Consumer(
      builder: (context, ref, _) {
        final webrtcState = ref.watch(activeRoomWebRTCProvider(widget.roomId));
        
        if (webrtcState?.service == null) {
          return Center(
            child: Text(
              'Initializing video...',
              style: GoogleFonts.raleway(
                color: VelvetNoir.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          );
        }

        return Stack(
          children: [
            // Local video
            Container(
              color: VelvetNoir.surfaceHigh,
              child: webrtcState!.service!.getLocalView(),
            ),
            // Audio/Video Status Overlays
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                spacing: 8,
                children: [
                  _buildStatusBadge(
                    _isVideoEnabled ? 'Video ON' : 'Video OFF',
                    _isVideoEnabled ? VelvetNoir.liveGlow : Colors.grey.shade700,
                  ),
                  _buildStatusBadge(
                    _isAudioEnabled ? 'Mic ON' : 'Mic OFF',
                    _isAudioEnabled ? VelvetNoir.liveGlow : Colors.grey.shade700,
                  ),
                ],
              ),
            ),
            // Remote Users Grid (if any)
            if (_remoteUsers.isNotEmpty)
              Positioned(
                bottom: 16,
                right: 16,
                child: SizedBox(
                  width: 120,
                  height: 150,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 1,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _remoteUsers.length,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: VelvetNoir.primary, width: 2),
                          borderRadius: BorderRadius.circular(8),
                          color: VelvetNoir.surfaceHigh,
                        ),
                        child: Center(
                          child: Text(
                            _userDisplayNames[_remoteUsers[index]] ?? 'User ${index + 1}',
                            style: GoogleFonts.raleway(
                              color: VelvetNoir.onSurface,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.raleway(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRoomPreview(RoomModel room) {
    return Container(
      color: VelvetNoir.surfaceHigh,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: VelvetNoir.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.videocam_outlined,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              room.name,
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: VelvetNoir.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              room.description ?? 'A live streaming room',
              style: GoogleFonts.raleway(
                fontSize: 14,
                color: VelvetNoir.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (room.isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: VelvetNoir.liveGlow,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '● LIVE',
                      style: GoogleFonts.raleway(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Text(
                  '${room.memberCount} listeners',
                  style: GoogleFonts.raleway(
                    color: VelvetNoir.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomHeader(RoomModel room) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        border: Border(bottom: BorderSide(color: VelvetNoir.primary.withValues(alpha: 0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  room.name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: VelvetNoir.onSurface,
                  ),
                ),
              ),
              if (room.isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: VelvetNoir.liveGlow,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'LIVE',
                    style: GoogleFonts.raleway(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Hosted by ${room.hostUsername ?? 'Anonymous'} • ${room.memberCount} listeners',
            style: GoogleFonts.raleway(
              fontSize: 12,
              color: VelvetNoir.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rooms')
                .doc(widget.roomId)
                .collection('messages')
                .orderBy('timestamp', descending: false)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: Text(
                    'Loading messages...',
                    style: GoogleFonts.raleway(color: VelvetNoir.onSurfaceVariant),
                  ),
                );
              }

              final messages = snapshot.data!.docs;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scrollController.hasClients) {
                  scrollController.animateTo(
                    scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });

              return ListView.builder(
                controller: scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final data = msg.data() as Map<String, dynamic>;
                  final username = data['username'] as String? ?? 'Anonymous';
                  final text = data['text'] as String? ?? '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: VelvetNoir.primary,
                          child: Text(
                            username[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: GoogleFonts.raleway(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: VelvetNoir.primary,
                                ),
                              ),
                              Text(
                                text,
                                style: GoogleFonts.raleway(
                                  fontSize: 12,
                                  color: VelvetNoir.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (_hasJoined)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: GoogleFonts.raleway(
                        color: VelvetNoir.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: VelvetNoir.surfaceHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: GoogleFonts.raleway(color: VelvetNoir.onSurface),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: VelvetNoir.primary,
                  onPressed: () => _sendMessage(messageController.text),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildControlBar(RoomModel room, User? currentUser) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        border: Border(top: BorderSide(color: VelvetNoir.primary.withValues(alpha: 0.2))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (!_hasJoined)
              FilledButton.icon(
                onPressed: currentUser != null
                    ? () => _joinRoom(currentUser.uid, currentUser.displayName ?? 'Anonymous')
                    : null,
                icon: const Icon(Icons.call_outlined),
                label: const Text('JOIN'),
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetNoir.primary,
                ),
              )
            else ...[
              FilledButton.icon(
                onPressed: () => _toggleVideo(!_isVideoEnabled),
                icon: Icon(_isVideoEnabled ? Icons.videocam : Icons.videocam_off),
                label: Text(_isVideoEnabled ? 'Camera' : 'Camera Off'),
                style: FilledButton.styleFrom(
                  backgroundColor: _isVideoEnabled ? VelvetNoir.primary : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _toggleAudio(!_isAudioEnabled),
                icon: Icon(_isAudioEnabled ? Icons.mic : Icons.mic_off),
                label: Text(_isAudioEnabled ? 'Mic' : 'Mic Off'),
                style: FilledButton.styleFrom(
                  backgroundColor: _isAudioEnabled ? VelvetNoir.primary : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _toggleAudioSharing(!_isAudioSharingEnabled),
                icon: Icon(_isAudioSharingEnabled ? Icons.volume_up : Icons.volume_mute),
                label: Text(_isAudioSharingEnabled ? 'Share Audio' : 'No Audio Share'),
                style: FilledButton.styleFrom(
                  backgroundColor: _isAudioSharingEnabled ? VelvetNoir.secondary : Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: currentUser != null ? _leaveRoom : null,
                icon: const Icon(Icons.logout),
                label: const Text('LEAVE'),
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetNoir.secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}






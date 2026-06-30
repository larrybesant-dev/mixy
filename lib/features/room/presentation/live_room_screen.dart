import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/room_model.dart';
import '../../../core/theme.dart';
import '../../../core/providers/firebase_providers.dart';
import 'room_management_modal.dart';
import '../providers/room_webrtc_provider.dart';
import '../providers/room_session_provider.dart';
import '../providers/participant_providers.dart';
import '../widgets/network_health_widget.dart';

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
    // Note: sessionState will be automatically cleaned up when room is left
    super.dispose();
  }

  /// Fetch the user's display name from Firestore profile.
  Future<String> _getUserDisplayName(String uid) async {
    try {
      final firestore = ref.read(firestoreProvider);
      final userDoc = await firestore.collection('users').doc(uid).get();
      final displayName = userDoc.data()?['displayName'] as String?;
      return displayName ?? 'Anonymous';
    } catch (e) {
      return 'Anonymous';
    }
  }

  Future<void> _joinRoom(String uid, String username) async {
    try {
      final firestore = ref.read(firestoreProvider);
      final roomRef = firestore.collection('rooms').doc(widget.roomId);
      
      // Fetch user's avatar URL
      String? avatarUrl;
      try {
        final userDoc = await firestore.collection('users').doc(uid).get();
        avatarUrl = userDoc.data()?['avatarUrl'] as String?;
      } catch (_) {
        // Continue without avatar if fetch fails
      }
      
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

      // Update room with user and avatar
      await roomRef.update({
        'audienceUserIds': FieldValue.arrayUnion([uid]),
        'audienceUserAvatarUrls': FieldValue.arrayUnion([avatarUrl ?? '']),
        'memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Initialize WebRTC
      final notifier = ref.read(activeRoomWebRTCProvider(widget.roomId).notifier);
      await notifier.joinAsAudience();

      // Update Riverpod session state
      final sessionNotifier = ref.read(roomSessionProvider(widget.roomId).notifier);
      sessionNotifier.setJoined(true);
      sessionNotifier.updateDisplayName(uid, username);

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
      final auth = ref.read(firebaseAuthProvider);
      final currentUser = auth.currentUser;
      if (currentUser == null) return;

      final firestore = ref.read(firestoreProvider);
      final roomRef = firestore.collection('rooms').doc(widget.roomId);
      
      // Get current room state to remove matching avatar URL
      final roomDoc = await roomRef.get();
      final roomData = roomDoc.data();
      String? avatarUrlToRemove;
      
      if (roomData != null) {
        final audienceIds = List<String>.from(roomData['audienceUserIds'] ?? []);
        final avatarUrls = List<String>.from(roomData['audienceUserAvatarUrls'] ?? []);
        
        // Find the index of current user and get matching avatar URL
        final userIndex = audienceIds.indexOf(currentUser.uid);
        if (userIndex >= 0 && userIndex < avatarUrls.length) {
          avatarUrlToRemove = avatarUrls[userIndex];
        }
      }
      
      // Delete participant doc
      await roomRef.collection('participants').doc(currentUser.uid).delete();
      
      // Update room
      await roomRef.update({
        'audienceUserIds': FieldValue.arrayRemove([currentUser.uid]),
        if (avatarUrlToRemove != null)
          'audienceUserAvatarUrls': FieldValue.arrayRemove([avatarUrlToRemove]),
        'memberCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await ref.read(activeRoomWebRTCProvider(widget.roomId).notifier).disconnect();
      ref.read(roomSessionProvider(widget.roomId).notifier).reset();

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
    ref.read(roomSessionProvider(widget.roomId).notifier).setVideoEnabled(enabled);
    ref.read(activeRoomWebRTCProvider(widget.roomId).notifier).toggleVideo(enabled);
  }

  void _toggleAudio(bool enabled) {
    ref.read(roomSessionProvider(widget.roomId).notifier).setAudioEnabled(enabled);
    ref.read(activeRoomWebRTCProvider(widget.roomId).notifier).toggleAudio(enabled);
  }

  void _toggleAudioSharing(bool enabled) {
    ref.read(roomSessionProvider(widget.roomId).notifier).setAudioSharingEnabled(enabled);
    ref.read(activeRoomWebRTCProvider(widget.roomId).notifier).toggleSystemAudioSharing(enabled).catchError((e) {
      // Revert UI state on error
      if (mounted) {
        ref.read(roomSessionProvider(widget.roomId).notifier).setAudioSharingEnabled(!enabled);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share audio: $e')),
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    try {
      final auth = ref.read(firebaseAuthProvider);
      final currentUser = auth.currentUser;
      if (currentUser == null) return;

      final sessionState = ref.watch(roomSessionProvider(widget.roomId));
      final firestore = ref.read(firestoreProvider);

      final messageRef = firestore
          .collection('rooms')
          .doc(widget.roomId)
          .collection('messages')
          .doc();
      await messageRef.set({
        'id': messageRef.id,
        'senderId': currentUser.uid,
        'senderName': sessionState.userDisplayNames[currentUser.uid] ?? 'Anonymous',
        'roomId': widget.roomId,
        'content': text,
        'createdAt': FieldValue.serverTimestamp(),
        'sentAt': FieldValue.serverTimestamp(),
        'clientSentAt': Timestamp.now(),
      });

      messageController.clear();
      
      // Auto-scroll to bottom
      unawaited(Future.delayed(const Duration(milliseconds: 100), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }));
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

  void _showManagementModal(BuildContext context, RoomModel room) {
    showDialog(
      context: context,
      builder: (context) => RoomManagementModal(
        roomId: widget.roomId,
        room: room,
      ),
    );
  }

  void _showParticipantsPanel(String roomId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Room Participants',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: VelvetNoir.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: VelvetNoir.onSurface,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(roomId)
                    .collection('participants')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: VelvetNoir.primary,
                      ),
                    );
                  }

                  final participants = snapshot.data!.docs;
                  if (participants.isEmpty) {
                    return Center(
                      child: Text(
                        'No participants yet',
                        style: GoogleFonts.raleway(
                          color: VelvetNoir.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final participantData =
                          participants[index].data() as Map<String, dynamic>;
                      final userId = participantData['userId'] as String? ?? '';
                      final displayName = participantData['displayName'] as String? ?? 'Anonymous';
                      final role = participantData['role'] as String? ?? 'audience';
                      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                      final isYou = userId == currentUserId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VelvetNoir.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: VelvetNoir.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: role == 'host'
                                  ? VelvetNoir.primary
                                  : VelvetNoir.secondary,
                              radius: 20,
                              child: Text(
                                displayName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        displayName,
                                        style: GoogleFonts.raleway(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: VelvetNoir.onSurface,
                                        ),
                                      ),
                                      if (isYou)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: Chip(
                                            label: Text(
                                              'You',
                                              style: GoogleFonts.raleway(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            backgroundColor: VelvetNoir.liveGlow,
                                            labelPadding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: role == 'host'
                                          ? VelvetNoir.primary.withValues(alpha: 0.2)
                                          : VelvetNoir.secondary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      role.toUpperCase(),
                                      style: GoogleFonts.raleway(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: role == 'host'
                                            ? VelvetNoir.primary
                                            : VelvetNoir.secondary,
                                      ),
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    final sessionState = ref.watch(roomSessionProvider(widget.roomId));

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
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final room = RoomModel.fromJson(
                  snapshot.data!.data() as Map<String, dynamic>,
                  widget.roomId,
                );
                final isOwner = currentUser?.uid == room.ownerId;
                final isAdmin = room.adminUserIds.contains(currentUser?.uid);
                final canManage = isOwner || isAdmin;

                if (canManage) {
                  return IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => _showManagementModal(context, room),
                    tooltip: 'Manage room',
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
          if (sessionState.hasJoined)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _shareRoom('Live Room'),
              tooltip: 'Share room',
            ),
          if (sessionState.hasJoined)
            IconButton(
              icon: const Icon(Icons.people_outline),
              onPressed: () => _showParticipantsPanel(widget.roomId),
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

          return isDesktop ? _buildDesktopLayout(room, currentUser, sessionState) : _buildMobileLayout(room, currentUser, sessionState);
        },
      ),
    );
  }

  Widget _buildMobileLayout(RoomModel room, User? currentUser, RoomSessionState sessionState) {
    return Column(
      children: [
        // Video Grid Area
        if (sessionState.hasJoined)
          _buildVideoArea(sessionState)
        else
          _buildRoomPreview(room),
        
        // Room Info & Controls
        Expanded(
          child: Column(
            children: [
              _buildRoomHeader(room, ref),
              Expanded(
                child: _buildChatArea(sessionState),
              ),
              _buildControlBar(room, currentUser, sessionState),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(RoomModel room, User? currentUser, RoomSessionState sessionState) {
    return Row(
      children: [
        // Left: Video Grid
        Expanded(
          flex: 3,
          child: Column(
            children: [
              if (sessionState.hasJoined)
                Expanded(child: _buildVideoArea(sessionState))
              else
                Expanded(child: _buildRoomPreview(room)),
              _buildControlBar(room, currentUser, sessionState),
            ],
          ),
        ),
        VerticalDivider(color: VelvetNoir.surfaceHigh, width: 1),
        // Right: Chat
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildRoomHeader(room, ref),
              Expanded(child: _buildChatArea(sessionState)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoArea(RoomSessionState sessionState) {
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
                    sessionState.isVideoEnabled ? 'Video ON' : 'Video OFF',
                    sessionState.isVideoEnabled ? VelvetNoir.liveGlow : Colors.grey.shade700,
                  ),
                  _buildStatusBadge(
                    sessionState.isAudioEnabled ? 'Mic ON' : 'Mic OFF',
                    sessionState.isAudioEnabled ? VelvetNoir.liveGlow : Colors.grey.shade700,
                  ),
                  NetworkHealthWidget(
                    showLabel: false,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  ),
                ],
              ),
            ),
            // Remote Users Grid (if any)
            if (sessionState.remoteUsers.isNotEmpty)
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
                    itemCount: sessionState.remoteUsers.length,
                    itemBuilder: (context, index) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: VelvetNoir.primary, width: 2),
                          borderRadius: BorderRadius.circular(8),
                          color: VelvetNoir.surfaceHigh,
                        ),
                        child: Center(
                          child: Text(
                            sessionState.userDisplayNames[sessionState.remoteUsers[index]] ?? 'User ${index + 1}',
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: DecoratedBox(
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

  Widget _buildRoomHeader(RoomModel room, WidgetRef ref) {
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
          Row(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: ref.read(firestoreProvider).collection('users').doc(room.hostId).snapshots(),
                builder: (context, snapshot) {
                  String hostDisplayName = room.hostUsername ?? 'Anonymous';
                  if (snapshot.hasData && snapshot.data != null) {
                    final hostData = snapshot.data!.data() as Map<String, dynamic>?;
                    hostDisplayName = hostData?['displayName'] ?? room.hostUsername ?? 'Anonymous';
                  }
                  return Text(
                    'Hosted by $hostDisplayName',
                    style: GoogleFonts.raleway(
                      fontSize: 12,
                      color: VelvetNoir.onSurfaceVariant,
                    ),
                  );
                },
              ),
              const Spacer(),
              Consumer(
                builder: (context, consumerRef, _) {
                  final participantCount = consumerRef.watch(participantCountProvider(room.id));
                  return GestureDetector(
                    onTap: () => _showParticipantsPanel(room.id),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Row(
                        children: [
                          const Icon(Icons.people, size: 14, color: VelvetNoir.primary),
                          const SizedBox(width: 4),
                          Text(
                            '$participantCount listeners',
                            style: GoogleFonts.raleway(
                              fontSize: 12,
                              color: VelvetNoir.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea(RoomSessionState sessionState) {
    if (!sessionState.hasJoined) {
      return Center(
        child: Text(
          'Join the room to chat',
          style: GoogleFonts.raleway(
            fontSize: 14,
            color: VelvetNoir.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rooms')
                .doc(widget.roomId)
                .collection('messages')
                .orderBy('createdAt', descending: false)
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
                  final senderName = data['senderName'] as String? ?? 'Anonymous';
                  final content = data['content'] as String? ?? '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: VelvetNoir.primary,
                          child: Text(
                            senderName[0].toUpperCase(),
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
                                senderName,
                                style: GoogleFonts.raleway(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: VelvetNoir.primary,
                                ),
                              ),
                              Text(
                                content,
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
        if (sessionState.hasJoined)
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

  Widget _buildControlBar(RoomModel room, User? currentUser, RoomSessionState sessionState) {
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
            if (!sessionState.hasJoined)
              FilledButton.icon(
                onPressed: currentUser != null
                    ? () async {
                        final displayName = await _getUserDisplayName(currentUser.uid);
                        if (mounted) {
                          await _joinRoom(currentUser.uid, displayName);
                        }
                      }
                    : null,
                icon: const Icon(Icons.call_outlined),
                label: const Text('JOIN'),
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetNoir.primary,
                ),
              )
            else ...[
              FilledButton.icon(
                onPressed: () => _toggleVideo(!sessionState.isVideoEnabled),
                icon: Icon(sessionState.isVideoEnabled ? Icons.videocam : Icons.videocam_off),
                label: Text(sessionState.isVideoEnabled ? 'Camera' : 'Camera Off'),
                style: FilledButton.styleFrom(
                  backgroundColor: sessionState.isVideoEnabled ? VelvetNoir.primary : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _toggleAudio(!sessionState.isAudioEnabled),
                icon: Icon(sessionState.isAudioEnabled ? Icons.mic : Icons.mic_off),
                label: Text(sessionState.isAudioEnabled ? 'Mic' : 'Mic Off'),
                style: FilledButton.styleFrom(
                  backgroundColor: sessionState.isAudioEnabled ? VelvetNoir.primary : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _toggleAudioSharing(!sessionState.isAudioSharingEnabled),
                icon: Icon(sessionState.isAudioSharingEnabled ? Icons.volume_up : Icons.volume_mute),
                label: Text(sessionState.isAudioSharingEnabled ? 'Share Audio' : 'No Audio Share'),
                style: FilledButton.styleFrom(
                  backgroundColor: sessionState.isAudioSharingEnabled ? VelvetNoir.secondary : Colors.grey.shade700,
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






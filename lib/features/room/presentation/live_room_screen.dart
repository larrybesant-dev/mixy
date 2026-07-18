import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/room_model.dart';
import '../../../core/theme.dart';
import '../../../services/diagnostic_logger.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../services/connection_recovery_handler.dart';
import '../../../services/connection_health_check.dart';
import 'room_management_modal.dart';
import '../room_controller.dart';
import '../providers/room_webrtc_provider.dart';
import '../providers/room_session_provider.dart';
import '../providers/participant_providers.dart';
import '../providers/connection_recovery_provider.dart';
import '../providers/room_gift_provider.dart';
import '../widgets/network_health_widget.dart';
import '../widgets/recovery_badge.dart';
import '../widgets/connection_failed_overlay.dart';
import '../../../widgets/floating_gift_animation.dart';
import '../../../widgets/gift_ticker_widget.dart';
import '../../../widgets/room_gift_picker_sheet.dart';

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
    with WidgetsBindingObserver, DiagnosticLogger {
  late TextEditingController messageController;
  late ScrollController scrollController;
  String? _lastSeenGiftId;

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
              child: Consumer(
                builder: (context, consumerRef, _) {
                  final participantsAsync = consumerRef.watch(
                    participantsStreamProvider(roomId),
                  );
                  return participantsAsync.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        color: VelvetNoir.primary,
                      ),
                    ),
                    error: (_, __) => Center(
                      child: Text(
                        'Failed to load participants',
                        style: GoogleFonts.raleway(
                          color: VelvetNoir.onSurfaceVariant,
                        ),
                      ),
                    ),
                    data: (participants) {
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
                          final participant = participants[index];
                          final userId = participant.userId;
                          final displayName =
                              participant.displayName?.trim().isNotEmpty == true
                              ? participant.displayName!.trim()
                              : 'Anonymous';
                          final role = participant.role;
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles audio-only fallback when recovery takes longer than 5+ seconds.
  /// If recovery has been active for more than 1 attempt (>5s due to exponential backoff),
  /// automatically disables video to reduce bandwidth and improve stability.
  void _handleRecoveryTimeout({
    required ConnectionRecoveryState recoveryState,
    required RoomSessionNotifier sessionNotifier,
    required BuildContext context,
    required bool isVideoEnabled,
  }) {
    // Threshold: after 2+ attempts, we've waited 2s + 4s = 6s
    const audioOnlyThreshold = 2;
    
    if (recoveryState.isRecovering &&
        recoveryState.attemptNumber >= audioOnlyThreshold &&
        isVideoEnabled) {
      // Degrade to audio-only
      sessionNotifier.setVideoEnabled(false);
      
      if (context.mounted) {
        // Notify user of degradation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Connection is unstable. Camera disabled for stability. You can re-enable it when connection improves.',
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.orange.shade700,
            action: SnackBarAction(
              label: 'Re-enable Camera',
              textColor: Colors.white,
              onPressed: () {
                sessionNotifier.setVideoEnabled(true);
              },
            ),
          ),
        );
      }
    }
    
    // When recovery succeeds after audio-only degradation, notify user
    if (recoveryState.isConnected &&
        !recoveryState.isRecovering &&
        !isVideoEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Connection recovered! Camera is available again.'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    }
  }

  /// Listen to new gift events and show toast + floating animation.
  void _checkForNewGift(List<RoomGiftEvent> gifts) {
    if (gifts.isEmpty) {
      _lastSeenGiftId = null;
      return;
    }

    final latestGift = gifts.first;
    
    // Only trigger animation for new gifts (first time seeing this ID)
    if (_lastSeenGiftId == null || _lastSeenGiftId != latestGift.id) {
      _lastSeenGiftId = latestGift.id;
      
      // Show floating emoji animation
      FloatingGiftAnimation.show(
        context,
        emoji: latestGift.emoji,
        duration: const Duration(milliseconds: 3000),
      );

      // Show toast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${latestGift.senderName} sent ${latestGift.emoji} to ${latestGift.receiverName ?? 'a guest'}!',
              style: const TextStyle(color: VelvetNoir.onSurface),
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: VelvetNoir.secondary.withValues(alpha: 0.8),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    final sessionState = ref.watch(roomSessionProvider(widget.roomId));
    final roomDocAsync = ref.watch(roomDocStreamProvider(widget.roomId));

    RoomModel? parsedRoom;
    final roomDoc = roomDocAsync.valueOrNull;
    if (roomDoc != null) {
      try {
        parsedRoom = RoomModel.fromJson(roomDoc, widget.roomId);
      } catch (_) {
        parsedRoom = null;
      }
    }

    final canManageRoom = parsedRoom != null &&
        ((currentUser?.uid == parsedRoom.ownerId) ||
            parsedRoom.adminUserIds.contains(currentUser?.uid));

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
          if (canManageRoom)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _showManagementModal(context, parsedRoom!),
              tooltip: 'Manage room',
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
      body: roomDocAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Error: $error',
            style: GoogleFonts.raleway(color: VelvetNoir.onSurface),
          ),
        ),
        data: (roomMap) {
          if (roomMap == null) {
            return Center(
              child: Text(
                'Room not found',
                style: GoogleFonts.raleway(color: VelvetNoir.onSurface),
              ),
            );
          }

          final room = RoomModel.fromJson(roomMap, widget.roomId);
          return isDesktop
              ? _buildDesktopLayout(room, currentUser, sessionState)
              : _buildMobileLayout(room, currentUser, sessionState);
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
        final healthState = ref.watch(connectionHealthProvider);
        final recoveryState = ref.watch(connectionRecoveryProvider);
        final giftsAsync = ref.watch(roomGiftStreamProvider(widget.roomId));
        final sessionNotifier = ref.read(roomSessionProvider(widget.roomId).notifier);
        
        // Trigger animations for new gifts
        giftsAsync.whenData((gifts) {
          _checkForNewGift(gifts);
        });
        
        // Trigger audio-only fallback if recovery takes >5 seconds
        _handleRecoveryTimeout(
          recoveryState: recoveryState,
          sessionNotifier: sessionNotifier,
          context: context,
          isVideoEnabled: sessionState.isVideoEnabled,
        );
        
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
            
            // Reconnecting Banner (prominent top notification)
            if (recoveryState.isRecovering)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.orange.withValues(alpha: 0.9),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Reconnecting... (Attempt ${recoveryState.attemptNumber}/${recoveryState.maxAttempts})',
                              style: GoogleFonts.raleway(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (recoveryState.nextRetryDelayMs > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Next attempt in ${(recoveryState.nextRetryDelayMs / 1000).toStringAsFixed(1)}s',
                                  style: GoogleFonts.raleway(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Connection Failed Banner
            if (recoveryState.isFailed)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.red.withValues(alpha: 0.9),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Connection failed. Please check your network or try leaving and rejoining.',
                          style: GoogleFonts.raleway(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Audio/Video Status Overlays + Recovery Badge
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
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
                  
                  // Health Badge: Shows when connection is degrading or worse
                  if (healthState.isAtRisk)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: switch (healthState.health) {
                          ConnectionHealth.healthy => Colors.green.withValues(alpha: 0.8),
                          ConnectionHealth.degrading => Colors.orange.withValues(alpha: 0.8),
                          ConnectionHealth.degraded => Colors.red.withValues(alpha: 0.8),
                          ConnectionHealth.unavailable => Colors.grey.withValues(alpha: 0.8),
                        },
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: VelvetNoir.liveGlow.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: [
                          Icon(
                            switch (healthState.health) {
                              ConnectionHealth.healthy => Icons.cloud_done,
                              ConnectionHealth.degrading => Icons.cloud_queue,
                              ConnectionHealth.degraded => Icons.cloud_off,
                              ConnectionHealth.unavailable => Icons.cloud_off_rounded,
                            },
                            color: Colors.white,
                            size: 14,
                          ),
                          Text(
                            healthState.displayStatus,
                            style: GoogleFonts.raleway(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Recovery Badge: Shows during degraded/reconnecting states
                  if (webrtcState.connectionState == RtcConnectionState.degraded ||
                      webrtcState.connectionState == RtcConnectionState.reconnecting)
                    RecoveryBadge(
                      attemptNumber: webrtcState.reconnectAttemptCount,
                      maxAttempts: 3,
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

            // Connection Failed Overlay: Shows after max retries exhausted
            if (webrtcState.connectionState == RtcConnectionState.failed)
              ConnectionFailedOverlay(
                roomId: widget.roomId,
                onRetry: () {
                  // Attempt to recover by calling reconnect on the service
                  // ignore: use_build_context_synchronously
                  ref.read(activeRoomWebRTCProvider(widget.roomId).notifier)
                      .disconnect()
                      .then((_) {
                    // Service will auto-reinitialize on next join
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Retrying connection...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  });
                },
                onLeave: () => Navigator.of(context).pop(),
              ),
            
            // TEMPORARY TEST BUTTONS - DELETE BEFORE COMMIT
            if (kDebugMode)
              Positioned(
                bottom: 120,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Test WARNING trigger
                    FloatingActionButton.extended(
                      heroTag: 'warning-test',
                      label: const Text('⚠️ Test WARNING'),
                      backgroundColor: Colors.orange,
                      tooltip: 'Trigger a test WARNING alert',
                      onPressed: () {
                        logWarning(
                          'Test Warning Triggered - Verifying alert pipeline',
                          metadata: {
                            'test_type': 'warning',
                            'timestamp': DateTime.now().toIso8601String(),
                            'room_id': widget.roomId,
                          },
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ WARNING logged to Crashlytics (check in 2 min)'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Test ERROR trigger
                    FloatingActionButton.extended(
                      heroTag: 'error-test',
                      label: const Text('🔴 Test ERROR'),
                      backgroundColor: Colors.red,
                      tooltip: 'Trigger a test ERROR alert',
                      onPressed: () {
                        logError(
                          'Test Error Triggered - Verifying alert pipeline',
                          error: Exception('Controlled test failure'),
                          metadata: {
                            'test_type': 'error',
                            'timestamp': DateTime.now().toIso8601String(),
                            'room_id': widget.roomId,
                          },
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ ERROR logged to Crashlytics (check in 2 min)'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Test CRITICAL trigger
                    FloatingActionButton.extended(
                      heroTag: 'critical-test',
                      label: const Text('🚨 Test CRITICAL'),
                      backgroundColor: Colors.redAccent,
                      tooltip: 'Trigger a test CRITICAL alert',
                      onPressed: () {
                        logCritical(
                          'Test Critical Triggered - Verifying EMERGENCY alert pipeline',
                          error: Exception('Controlled critical test failure'),
                          metadata: {
                            'test_type': 'critical',
                            'timestamp': DateTime.now().toIso8601String(),
                            'room_id': widget.roomId,
                          },
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ CRITICAL logged to Crashlytics (check in 2 min)'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            
            // Gift Ticker: Shows recent gifts at bottom
            GiftTickerWidget(
              roomId: widget.roomId,
              bottomPadding: 80,
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
              Text(
                'Hosted by ${room.hostUsername ?? 'Anonymous'}',
                style: GoogleFonts.raleway(
                  fontSize: 12,
                  color: VelvetNoir.onSurfaceVariant,
                ),
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
                          try {
                            final controller = ref.read(roomControllerProvider(widget.roomId).notifier);
                            await controller.joinRoom(
                              currentUser.uid,
                              displayName: displayName,
                              avatarUrl: currentUser.photoURL,
                            );
                          } catch (e) {
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
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => RoomGiftPickerSheet.show(context, ref, roomId: room.id),
                icon: const Icon(Icons.card_giftcard),
                label: const Text('Gift'),
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetNoir.primary,
                  foregroundColor: VelvetNoir.surface,
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






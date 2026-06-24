import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mixmingle/core/responsive/responsive_utils.dart';
import 'package:mixmingle/core/animations/app_animations.dart';
import 'package:mixmingle/shared/models/room.dart';
import 'package:mixmingle/shared/models/message.dart' as room_message;
import 'package:mixmingle/shared/widgets/glow_text.dart';
import 'package:mixmingle/shared/widgets/club_background.dart';
import 'package:mixmingle/shared/providers/all_providers.dart';
import 'package:mixmingle/services/agora/agora_video_service.dart';
import 'package:mixmingle/services/chat/messaging_service.dart';
import 'package:mixmingle/services/room/room_manager_service.dart';
import 'package:mixmingle/features/room/widgets/participant_list_sidebar.dart';
import 'package:mixmingle/features/room/widgets/raised_hands_panel.dart';
import 'package:mixmingle/features/room/widgets/room_controls.dart';
import 'package:mixmingle/core/analytics/analytics_service.dart';

class RoomPage extends ConsumerStatefulWidget {
  final Room room;

  const RoomPage({super.key, required this.room});

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends ConsumerState<RoomPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MessagingService _messagingService = MessagingService();

  bool _isVideoInitialized = false;
  bool _hasInitializedVideo = false;
  String? _videoInitError;
  bool _isTogglingVideo = false;
  bool _isTogglingMic = false;
  bool _showSidebar = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView(screenName: 'screen_room');
    _initializeVideo();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(agoraVideoServiceProvider).addListener(_onAgoraServiceChanged);
      // #8 Activate vibe accent for this room
      if (widget.room.vibeTag != null) {
        ref.read(activeVibeProvider.notifier).set(widget.room.vibeTag);
      }
    });
  }

  @override
  void dispose() {
    AnalyticsService.instance.logRoomLeave(roomId: widget.room.id);
    ref.read(agoraVideoServiceProvider).removeListener(_onAgoraServiceChanged);
    _messageController.dispose();
    _scrollController.dispose();
    ref.read(agoraVideoServiceProvider).leaveRoom();
    // #8 Reset vibe accent when leaving
    ref.read(activeVibeProvider.notifier).set(null);
    super.dispose();
  }

  void _onAgoraServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeVideo() async {
    if (_hasInitializedVideo) return;

    try {
      final agoraService = ref.read(agoraVideoServiceProvider);
      await agoraService.initialize();
      await agoraService.joinRoom(widget.room.id);

      // #1 Record vibe join for intelligence layer
      final vibeUid = FirebaseAuth.instance.currentUser?.uid;
      if (vibeUid != null && widget.room.vibeTag != null) {
        ref
            .read(vibeIntelligenceServiceProvider)
            .recordVibeJoin(userId: vibeUid, vibeTag: widget.room.vibeTag!);
      }

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _hasInitializedVideo = true;
        });
      }
      AnalyticsService.instance.logRoomJoinSuccess(roomId: widget.room.id);
      AnalyticsService.instance.logFirstRoomJoinOnce(roomId: widget.room.id);
    } catch (e) {
      AnalyticsService.instance.logRoomJoinFailed(
        roomId: widget.room.id,
        error: e.toString(),
      );
      debugPrint('âŒ Video initialization failed: $e');
      if (mounted) {
        setState(() {
          _videoInitError = e.toString();
          _hasInitializedVideo = true;
        });
      }
    }
  }

  RoomManagerService get _roomManager => ref.read(roomManagerServiceProvider);

  Future<void> _handlePromote(String userId) async {
    try {
      await _roomManager.promoteToSpeaker(widget.room.id, userId);
    } catch (e) {
      _showError('Failed to promote: $e');
    }
  }

  Future<void> _handleDemote(String userId) async {
    try {
      await _roomManager.demoteToListener(widget.room.id, userId);
    } catch (e) {
      _showError('Failed to demote: $e');
    }
  }

  Future<void> _handleMakeModerator(String userId) async {
    try {
      await _roomManager.makeModerator(widget.room.id, userId);
    } catch (e) {
      _showError('Failed to make moderator: $e');
    }
  }

  Future<void> _handleRemoveModerator(String userId) async {
    try {
      await _roomManager.removeModerator(widget.room.id, userId);
    } catch (e) {
      _showError('Failed to remove moderator: $e');
    }
  }

  Future<void> _handleKick(String userId) async {
    try {
      // Use removeUser for Sprint 2 control
      await _roomManager.removeUser(widget.room.id, userId);
    } catch (e) {
      _showError('Failed to remove user: $e');
    }
  }

  Future<void> _handleBan(String userId) async {
    try {
      // For now, use removeUser - ban would require additional bannedUsers list
      await _roomManager.removeUser(widget.room.id, userId);
    } catch (e) {
      _showError('Failed to remove user: $e');
    }
  }

  Future<void> _handleMute(String userId) async {
    try {
      await _roomManager.muteUser(widget.room.id, userId);
    } catch (e) {
      _showError('Failed to mute: $e');
    }
  }

  Future<void> _handleUnmute(String userId) async {
    try {
      await _roomManager.unmuteUser(widget.room.id, userId);
    } catch (e) {
      _showError('Failed to unmute: $e');
    }
  }

  Future<void> _handleDisableVideo(String userId) async {
    await _handleMute(userId);
  }

  Future<void> _handleEnableVideo(String userId) async {
    await _handleUnmute(userId);
  }

  Future<void> _handleApproveHand(String userId) async {
    try {
      await _roomManager.approveRaisedHand(widget.room.id, userId);
    } catch (e) {
      _showError('Failed to approve hand: $e');
    }
  }

  Future<void> _handleDeclineHand(String userId) async {
    try {
      await _roomManager.declineRaisedHand(widget.room.id, userId);
    } catch (e) {
      _showError('Failed to decline hand: $e');
    }
  }

  Future<void> _handleRaiseHand() async {
    try {
      final userId = ref.read(currentUserProvider).value?.id ?? '';
      await _roomManager.requestToSpeak(widget.room.id, userId);
      _showInfo('Hand raised');
    } catch (e) {
      _showError('Failed to raise hand: $e');
    }
  }

  Future<void> _handleEndRoom() async {
    try {
      await _roomManager.endRoom(widget.room.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('Failed to end room: $e');
    }
  }

  Future<void> _handleLockRoom(bool locked) async {
    try {
      if (locked) {
        await _roomManager.lockRoom(widget.room.id);
      } else {
        await _roomManager.unlockRoom(widget.room.id);
      }
      _showInfo(locked ? 'Room locked ðŸ”’' : 'Room unlocked ðŸ”“');
    } catch (e) {
      _showError('Failed to ${locked ? "lock" : "unlock"} room: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.room.id));
    final currentRoom = roomAsync.maybeWhen(
      data: (r) => r ?? widget.room,
      orElse: () => widget.room,
    );

    // Use Riverpod provider to ensure Firebase auth state is properly synced
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.maybeWhen(
      data: (user) => user,
      orElse: () => null,
    );

    // Sprint 2: Check for host control state changes
    if (currentUser != null) {
      // Check if user was removed from room
      if (currentRoom.removedUsers.contains(currentUser.uid)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Removed from Room'),
                content: const Text('The host has removed you from this room.'),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        });
      }

      // Check if room was ended by host
      if (currentRoom.isRoomEnded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Room Ended'),
                content: const Text('The host has ended this room.'),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        });
      }
    }

    if (roomAsync.asData?.value != null &&
        !(roomAsync.asData?.value?.isLive ?? true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }

    final agoraService = ref.read(agoraVideoServiceProvider);
    final isHost = currentUser != null && currentRoom.hostId == currentUser.uid;
    final isModerator = currentUser != null &&
        (currentRoom.moderators.contains(currentUser.uid) ||
            currentRoom.admins.contains(currentUser.uid));
    final isSpeaker =
        currentUser != null && currentRoom.speakers.contains(currentUser.uid);
    final isListener = currentUser != null && !isSpeaker;
    final hasRaisedHand = currentUser != null &&
        currentRoom.raisedHands.contains(currentUser.uid);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentRoom.name ?? currentRoom.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: Responsive.responsiveFontSize(context, 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${currentRoom.currentMembers}/${currentRoom.capacity}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sprint 2: Lock badge
                  if (currentRoom.isRoomLocked) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.6),
                            width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: Colors.amber, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Locked',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Room type badge
                  const SizedBox(width: 8),
                  _RoomTypeBadge(roomType: currentRoom.roomType),
                ],
              ),
            ],
          ),
        ),
        body: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  // Video area
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2F),
                        border: Border.all(
                          color: const Color(0xFFFF4C4C).withValues(alpha: 0.5),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: EdgeInsets.all(
                          Responsive.responsiveSpacing(context, 16)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          Responsive.responsiveBorderRadius(context, 10),
                        ),
                        child: AppAnimations.fadeIn(
                          child: _buildVideoView(agoraService),
                        ),
                      ),
                    ),
                  ),

                  // Video controls
                  if (_isVideoInitialized) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.responsiveSpacing(context, 16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildControlButton(
                            context,
                            icon: agoraService.isMicMuted
                                ? Icons.mic_off
                                : Icons.mic,
                            label: agoraService.isMicMuted ? 'Unmute' : 'Mute',
                            isActive: !agoraService.isMicMuted,
                            isLoading: _isTogglingMic,
                            onPressed: () async {
                              if (_isTogglingMic) return;
                              setState(() => _isTogglingMic = true);
                              try {
                                await agoraService.toggleMic();
                              } finally {
                                if (mounted) {
                                  setState(() => _isTogglingMic = false);
                                }
                              }
                            },
                          ),
                          SizedBox(
                              width: Responsive.responsiveSpacing(context, 12)),
                          _buildControlButton(
                            context,
                            icon: agoraService.isVideoMuted
                                ? Icons.videocam_off
                                : Icons.videocam,
                            label: 'Camera',
                            isActive: !agoraService.isVideoMuted,
                            isLoading: _isTogglingVideo,
                            onPressed: () async {
                              if (_isTogglingVideo) return;
                              setState(() => _isTogglingVideo = true);
                              try {
                                await agoraService.toggleVideo();
                              } finally {
                                if (mounted) {
                                  setState(() => _isTogglingVideo = false);
                                }
                              }
                            },
                          ),
                          SizedBox(
                              width: Responsive.responsiveSpacing(context, 12)),
                          _buildControlButton(
                            context,
                            icon: Icons.call_end,
                            label: 'Leave',
                            isDestructive: true,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.responsiveSpacing(context, 16),
                        vertical: Responsive.responsiveSpacing(context, 8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RoomControls(
                            room: currentRoom,
                            currentUserId: currentUser?.uid ?? '',
                            onEndRoom: _handleEndRoom,
                            onLockRoom: _handleLockRoom,
                            onRaiseHand: _handleRaiseHand,
                            isListener: isListener,
                            hasRaisedHand: hasRaisedHand,
                          ),
                          if (isHost || isModerator)
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _showSidebar = !_showSidebar),
                              icon: Icon(
                                _showSidebar
                                    ? Icons.close_fullscreen
                                    : Icons.open_in_full,
                                color: Colors.white70,
                              ),
                              label: Text(
                                _showSidebar ? 'Hide Panel' : 'Show Panel',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: Responsive.responsiveSpacing(context, 16)),
                  ],

                  // Chat section
                  Expanded(
                    flex: 2,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2F).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4C4C)
                                  .withValues(alpha: 0.1),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.chat,
                                    color: Color(0xFFFF4C4C), size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Room Chat',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                if (agoraService.remoteUsers.isNotEmpty)
                                  Text(
                                    '${agoraService.remoteUsers.length + 1} online',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: StreamBuilder<List<room_message.Message>?>(
                              stream: _messagingService
                                  .getRoomMessages(widget.room.id),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                        color: Color(0xFFFF4C4C)),
                                  );
                                }

                                if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'No messages yet. Say hello! ðŸ‘‹',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  );
                                }

                                final messages = snapshot.data!;
                                return ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(12),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final message = messages[index];
                                    final isMe =
                                        message.senderId == currentUser?.uid;
                                    final displayName =
                                        message.senderName.isNotEmpty
                                            ? message.senderName
                                            : 'Unknown User';

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment: isMe
                                            ? MainAxisAlignment.end
                                            : MainAxisAlignment.start,
                                        children: [
                                          if (!isMe) ...[
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor:
                                                  const Color(0xFFFF4C4C),
                                              child: Text(
                                                displayName[0].toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Flexible(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isMe
                                                    ? const Color(0xFFFF4C4C)
                                                        .withValues(alpha: 0.2)
                                                    : Colors.white
                                                        .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    displayName,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    message.content,
                                                    style: const TextStyle(
                                                        color: Colors.white70),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatTimestamp(
                                                        message.timestamp),
                                                    style: const TextStyle(
                                                      color: Colors.white38,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
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
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Type a message...',
                                      hintStyle: const TextStyle(
                                          color: Colors.white54),
                                      filled: true,
                                      fillColor:
                                          Colors.white.withValues(alpha: 0.06),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFFF4C4C)),
                                      ),
                                    ),
                                    onSubmitted: (_) {
                                      if (currentUser != null) {
                                        _sendMessage(currentUser);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF4C4C),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (currentUser != null) {
                                      _sendMessage(currentUser);
                                    }
                                  },
                                  child: const Icon(Icons.send),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sidebar for host/moderator
            if (_showSidebar && (isHost || isModerator)) ...[
              const SizedBox(width: 16),
              Column(
                children: [
                  Expanded(
                    child: ParticipantListSidebar(
                      room: currentRoom,
                      currentUserId: currentUser.uid,
                      onPromote: _handlePromote,
                      onDemote: _handleDemote,
                      onMakeModerator: _handleMakeModerator,
                      onRemoveModerator: _handleRemoveModerator,
                      onKick: _handleKick,
                      onBan: _handleBan,
                      onMute: _handleMute,
                      onUnmute: _handleUnmute,
                      onDisableVideo: _handleDisableVideo,
                      onEnableVideo: _handleEnableVideo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RaisedHandsPanel(
                    room: currentRoom,
                    currentUserId: currentUser.uid,
                    onApprove: _handleApproveHand,
                    onDecline: _handleDeclineHand,
                  ),
                ],
              ),
              const SizedBox(width: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideoView(AgoraVideoService agoraService) {
    if (_videoInitError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFFF4C4C)),
            const SizedBox(height: 16),
            const GlowText(
              text: 'Video initialization failed',
              fontSize: 18,
              glowColor: Color(0xFFFF4C4C),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _videoInitError!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _videoInitError = null;
                  _hasInitializedVideo = false;
                });
                _initializeVideo();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4C4C),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isVideoInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFFF4C4C)),
            SizedBox(height: 16),
            GlowText(
              text: 'Connecting to room...',
              fontSize: 16,
              glowColor: Color(0xFFFF4C4C),
            ),
          ],
        ),
      );
    }

    // Deduplicate remote users using Set to prevent ghost tiles
    final remoteUsers = List<int>.from(agoraService.remoteUsers);
    final uniqueRemoteUsers =
        remoteUsers.toSet().toList(); // Atomic deduplication
    final hasRemoteUsers = uniqueRemoteUsers.isNotEmpty;

    return Stack(
      children: [
        if (hasRemoteUsers && agoraService.engine != null)
          _buildRemoteVideoGrid(agoraService, uniqueRemoteUsers)
        else
          _buildEmptyRoomView(),
        if (agoraService.engine != null && !agoraService.isVideoMuted)
          Positioned(
            top: 10,
            right: 10,
            width: 120,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFF4C4C), width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: agoraService.engine!,
                        canvas: const VideoCanvas(uid: 0),
                        useFlutterTexture: true,
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF4C4C).withValues(alpha: 0.8),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people, color: Color(0xFFFF4C4C), size: 16),
                const SizedBox(width: 4),
                Text(
                  '${uniqueRemoteUsers.length + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteVideoGrid(
      AgoraVideoService agoraService, List<int> remoteUsers) {
    if (remoteUsers.length == 1) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: agoraService.engine!,
          canvas: VideoCanvas(uid: remoteUsers.first),
          connection: RtcConnection(channelId: widget.room.id),
        ),
      );
    } else if (remoteUsers.length == 2) {
      return Row(
        children: [
          Expanded(
              child: RepaintBoundary(
                  child: _buildRemoteVideoTile(agoraService, remoteUsers[0]))),
          Expanded(
              child: RepaintBoundary(
                  child: _buildRemoteVideoTile(agoraService, remoteUsers[1]))),
        ],
      );
    } else {
      // Optimize grid layout based on participant count
      int crossAxisCount = 2;
      double childAspectRatio = 1.0;

      if (remoteUsers.length > 10) {
        // For 10+ participants, use 3 columns for better GPU utilization
        crossAxisCount = 3;
        childAspectRatio = 1.2;
      } else if (remoteUsers.length > 6) {
        // For 6-10 participants, use 2 columns but adjust height
        crossAxisCount = 2;
        childAspectRatio = 1.1;
      }

      return GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: remoteUsers.length,
        itemBuilder: (context, index) {
          return RepaintBoundary(
            child: _buildRemoteVideoTile(agoraService, remoteUsers[index]),
          );
        },
      );
    }
  }

  Widget _buildRemoteVideoTile(AgoraVideoService agoraService, int uid) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border:
              Border.all(color: const Color(0xFFFF4C4C).withValues(alpha: 0.3)),
        ),
        child: Stack(
          children: [
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: agoraService.engine!,
                canvas: VideoCanvas(uid: uid),
                connection: RtcConnection(channelId: widget.room.id),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'User $uid',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRoomView() {
    return Container(
      color: const Color(0xFF1E1E2F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: const Color(0xFFFF4C4C).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const GlowText(
              text: 'Waiting for others to join...',
              fontSize: 18,
              glowColor: Color(0xFFFF4C4C),
            ),
            const SizedBox(height: 8),
            Text(
              'Share the room link to invite friends',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = true,
    bool isLoading = false,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? Colors.red
        : isActive
            ? const Color(0xFFFF4C4C)
            : Colors.grey.shade700;

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.responsiveSpacing(context, 12),
          vertical: Responsive.responsiveSpacing(context, 12),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: isActive ? 4 : 2,
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: Responsive.responsiveIconSize(context, 24)),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: Responsive.responsiveFontSize(context, 10),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _sendMessage(User currentUser) async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();

    try {
      final userProfile =
          await ref.read(profileServiceProvider).getCurrentUserProfile();
      final displayName =
          userProfile?.displayName ?? currentUser.email ?? 'User';

      await _messagingService.sendRoomMessage(
        senderId: currentUser.uid,
        senderName: displayName,
        senderAvatarUrl: userProfile?.photoUrl ?? currentUser.photoURL ?? '',
        roomId: widget.room.id,
        content: content,
      );

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint('âŒ Failed to send message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}

// ── Room Type Badge chip shown in app bar ─────────────────────────────────────
class _RoomTypeBadge extends StatelessWidget {
  final RoomType roomType;
  const _RoomTypeBadge({required this.roomType});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String label) = switch (roomType) {
      RoomType.video => (const Color(0xFFFF4D8B), Icons.videocam_outlined, 'Video'),
      RoomType.text =>
        (const Color(0xFF4A90FF), Icons.chat_bubble_outline, 'Text'),
      RoomType.voice => (const Color(0xFF00E5CC), Icons.mic_outlined, 'Voice'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 6)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'package:mixvy/features/room/room_controller.dart';
import 'package:mixvy/features/room/providers/room_live_state_provider.dart';
import 'package:mixvy/features/room/providers/rtc_service_provider.dart';
import 'package:mixvy/services/rtc_room_service.dart';
import 'package:mixvy/features/room/controllers/live_room_media_controller.dart';
import 'package:mixvy/features/room/widgets/chat_panel.dart';
import 'package:mixvy/core/velvet_noir_constants.dart';
import 'package:mixvy/features/room/providers/message_providers.dart';
import 'package:mixvy/features/room/providers/participant_providers.dart';
import 'package:mixvy/models/room_participant_model.dart';

// ignore_for_file: unused_element, unused_import

// Loopback testing mode for multi-instance video rendering verification
final loopbackModeProvider = StateProvider<bool>((ref) => false);

// ─────────────────────────────────────────────────────────────────────────────
// RoomHeaderWidget — Persistent header with room metadata and wine red accent
// ─────────────────────────────────────────────────────────────────────────────
class RoomHeaderWidget extends StatelessWidget {
  final String? roomTitle;
  final String? hostName;
  final int? participantCount;

  const RoomHeaderWidget({
    super.key,
    this.roomTitle,
    this.hostName,
    this.participantCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: kVelvetJet,
        border: Border(
          bottom: BorderSide(
            color: kVelvetWine.withValues(alpha: 0.6),
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: kVelvetGold.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Wine-red accent bar
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: kVelvetWine,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // Room metadata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  roomTitle ?? 'Live Lounge',
                  style: const TextStyle(
                    color: kVelvetGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Hosted by ${hostName ?? 'MixVy Host'}',
                  style: TextStyle(
                    color: kVelvetGold.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Participant count badge
          if (participantCount != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kVelvetWine.withValues(alpha: 0.3),
                border: Border.all(color: kVelvetWine, width: 1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$participantCount listening',
                style: const TextStyle(
                  color: kVelvetGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _VideoTile — Granular self-refreshing video tile to isolate rebuilds
// ─────────────────────────────────────────────────────────────────────────────
class _VideoTile extends ConsumerStatefulWidget {
  final String title;
  final Widget child;
  final bool isLocal;
  final int? uid; // null for local
  final String roomId;
  final bool isLoopback;

  const _VideoTile({
    super.key,
    required this.title,
    required this.child,
    required this.isLocal,
    required this.uid,
    required this.roomId,
    this.isLoopback = false,
  });

  @override
  ConsumerState<_VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends ConsumerState<_VideoTile> {
  Timer? _metricsTimer;
  bool _isSpeaking = false;
  double _audioLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _startMetricsPolling();
  }

  @override
  void didUpdateWidget(_VideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.roomId != widget.roomId ||
        oldWidget.isLocal != widget.isLocal) {
      _metricsTimer?.cancel();
      _startMetricsPolling();
    }
  }

  void _startMetricsPolling() {
    _metricsTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final rtcService = ref.read(rtcServiceProvider(widget.roomId));
      if (rtcService == null) return;

      bool nowSpeaking = false;
      double nowLevel = 0.0;

      if (widget.isLocal) {
        nowSpeaking = rtcService.localSpeaking;
        nowLevel = rtcService.localAudioLevel;
      } else if (widget.uid != null) {
        nowSpeaking = rtcService.isRemoteSpeaking(widget.uid!);
        nowLevel = rtcService.remoteAudioLevelForUid(widget.uid!);
      }

      if (_isSpeaking != nowSpeaking || (_audioLevel - nowLevel).abs() > 0.02) {
        if (mounted) {
          setState(() {
            _isSpeaking = nowSpeaking;
            _audioLevel = nowLevel;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isRemoteSpeaking = !widget.isLocal && widget.uid != null
        ? ref.watch(isRemoteSpeakingProvider((roomId: widget.roomId, uid: widget.uid!)))
        : false;
    final bool speaking = widget.isLocal ? _isSpeaking : isRemoteSpeaking;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: speaking ? kVelvetGold : kVelvetWine.withValues(alpha: 0.4),
          width: speaking ? 2 : 1,
        ),
        boxShadow: speaking
            ? [
                BoxShadow(
                  color: kVelvetGold.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            // Bottom overlay with title and audio indicator
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: speaking ? kVelvetGold : Colors.white,
                          fontSize: 10,
                          fontWeight:
                              speaking ? FontWeight.bold : FontWeight.normal,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Small active-speaking or volume wave meter next to name
                    if (speaking)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: kVelvetGold,
                          shape: BoxShape.circle,
                        ),
                      )
                    else if (_audioLevel > 0.0)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Loopback flag watermark if testing
            if (widget.isLoopback)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LOOPBACK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// VideoFeedWidget — 70% Grid-Based Video Engine (Paltalk-Style Tiled Matrix)
// ─────────────────────────────────────────────────────────────────────────────
class VideoFeedWidget extends ConsumerWidget {
  final String roomId;

  const VideoFeedWidget({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rtcService = ref.watch(rtcServiceProvider(roomId));

    if (rtcService == null || !rtcService.isJoinedChannel) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: kVelvetJet,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam,
                size: 64,
                color: kVelvetGold.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Video Feed Grid',
                style: TextStyle(
                  color: kVelvetGold.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Waiting for room connection...',
                style: TextStyle(
                  color: kVelvetWine.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final remoteUids = rtcService.remoteUids;
    final showLocal = rtcService.isLocalVideoCapturing;
    final isDegraded = rtcService.isNetworkDegraded;
    final isLoopback = ref.watch(loopbackModeProvider);

    // Build the grid list of tiles
    final List<Widget> gridTiles = [];

    // 1. Local video preview
    if (showLocal) {
      gridTiles.add(
        _VideoTile(
          key: const ValueKey('video_tile_local'),
          title: 'You (Local)',
          child: rtcService.getLocalView(),
          isLocal: true,
          uid: null,
          roomId: roomId,
        ),
      );

      // 2. LOOPBACK mode duplicate tile
      if (isLoopback) {
        gridTiles.add(
          _VideoTile(
            key: const ValueKey('video_tile_loopback'),
            title: 'You (Loopback Test)',
            child: rtcService.getLocalView(),
            isLocal: true,
            uid: null,
            roomId: roomId,
            isLoopback: true,
          ),
        );
      }
    }

    // 3. Remote video streams
    for (final uid in remoteUids) {
      final String? peerUserId = rtcService.userIdForUid(uid);
      gridTiles.add(
        _VideoTile(
          key: ValueKey('video_tile_remote_$uid'),
          title: peerUserId != null ? 'User $peerUserId' : 'User $uid',
          child: rtcService.getRemoteView(uid, roomId),
          isLocal: false,
          uid: uid,
          roomId: roomId,
        ),
      );
    }

    // 4. Fill in the remaining slots with beautiful dark-mode placeholders to preserve Paltalk matrix structure (up to 6 total slots)
    const int targetSlots = 6;
    while (gridTiles.length < targetSlots) {
      gridTiles.add(
        Container(
          key: ValueKey('video_tile_placeholder_${gridTiles.length}'),
          decoration: BoxDecoration(
            color: const Color(0xFF16161A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: kVelvetWine.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam_off_outlined,
                  color: kVelvetGold.withValues(alpha: 0.12),
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  'Empty Slot',
                  style: TextStyle(
                    color: kVelvetGold.withValues(alpha: 0.15),
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: kVelvetJet,
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          GridView.builder(
            itemCount: gridTiles.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridTiles.length <= 2
                  ? 1
                  : 2, // 2 tiles? Stack vertically. 4+? 2x2.
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 4 / 3,
            ),
            itemBuilder: (context, index) => gridTiles[index],
          ),
          // Connection status warning cue overlay (floating over the whole grid)
          if (isDegraded)
            Positioned(
              left: 16,
              top: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(
                      alpha: 0.9), // 8-digit ARGB Color hex compliant
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFBBF24), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    const Text(
                      'Connection Unstable (Video Paused/Throttled)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _ControlIconButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effColor = isActive ? Colors.white : Colors.white54;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: effColor),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: effColor)),
      ],
    );
  }
}

class _FloatingControlBar extends ConsumerWidget {
  final String roomId;
  final dynamic
      controllerState; // Swapped to dynamic to match structural scope if type isn't exported here

  const _FloatingControlBar(
      {required this.roomId, required this.controllerState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rtcService = ref.watch(rtcServiceProvider(roomId));
    final mediaState = ref.watch(liveRoomMediaControllerProvider(roomId));
    final isLoopback = ref.watch(loopbackModeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 15, spreadRadius: 2)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlIconButton(
            icon: mediaState.isMicMuted ? Icons.mic_off : Icons.mic,
            label: mediaState.isMicMuted ? 'Mic Off' : 'Mic On',
            isActive: !mediaState.isMicMuted,
            onPressed: () async {
              final newMuteState = !mediaState.isMicMuted;
              await rtcService?.mute(newMuteState);
              ref
                  .read(liveRoomMediaControllerProvider(roomId).notifier)
                  .syncFromService(
                    isVideoEnabled: rtcService?.isLocalVideoCapturing ??
                        mediaState.isVideoEnabled,
                    isMicMuted: newMuteState,
                    isSharingSystemAudio: rtcService?.isSharingSystemAudio ??
                        mediaState.isSharingSystemAudio,
                  );
            },
          ),
          const SizedBox(width: 24),
          _ControlIconButton(
            icon:
                mediaState.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: mediaState.isVideoEnabled ? 'Cam On' : 'Cam Off',
            isActive: mediaState.isVideoEnabled,
            onPressed: () async {
              final newVideoEnabled = !mediaState.isVideoEnabled;
              await rtcService?.enableVideo(newVideoEnabled,
                  publishMicrophoneTrack: !mediaState.isMicMuted);
              ref
                  .read(liveRoomMediaControllerProvider(roomId).notifier)
                  .syncFromService(
                    isVideoEnabled:
                        rtcService?.isLocalVideoCapturing ?? newVideoEnabled,
                    isMicMuted:
                        rtcService?.isLocalAudioMuted ?? mediaState.isMicMuted,
                    isSharingSystemAudio: rtcService?.isSharingSystemAudio ??
                        mediaState.isSharingSystemAudio,
                  );
            },
          ),
          const SizedBox(width: 24),
          _ControlIconButton(
            icon: isLoopback ? Icons.loop : Icons.sync_disabled,
            label: isLoopback ? 'Loop On' : 'Loop Off',
            isActive: isLoopback,
            onPressed: () {
              ref.read(loopbackModeProvider.notifier).update((state) => !state);
            },
          ),
        ],
      ),
    );
  }
}

class LiveRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final RoomModel? previewRoom;

  const LiveRoomScreen({super.key, required this.roomId, this.previewRoom});

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> {
  late RoomController _roomController;

  @override
  void initState() {
    super.initState();
    _roomController = ref.read(roomControllerProvider(widget.roomId).notifier);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bool isPortrait = mediaQuery.orientation == Orientation.portrait;

    final bool isNetworkDegraded = ref.watch(isNetworkDegradedProvider(widget.roomId));

    return Scaffold(
      backgroundColor: kVelvetJet,
      body: Column(
        children: [
          // ── Persistent Header with Room Metadata ──
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rooms')
                .doc(widget.roomId)
                .snapshots(),
            builder: (context, roomSnap) {
              final data =
                  (roomSnap.data?.data() as Map<String, dynamic>?) ?? {};
              return RoomHeaderWidget(
                roomTitle: data['name'] ?? data['title'] ?? 'Live Lounge',
                hostName: data['hostUsername'] ?? 'MixVy Host',
                participantCount: (data['memberCount'] as int?) ?? 0,
              );
            },
          ),
          if (isNetworkDegraded)
            Container(
              width: double.infinity,
              color: kVelvetWine,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: kVelvetGold, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Connection unstable. Adjusting stream quality...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          // ── Responsive Layout: Grid & Sidebar ──
          Expanded(
            child: isPortrait
                ? Column(
                    children: [
                      // Video Grid Area (Top)
                      Expanded(
                        flex: 11,
                        child: VideoFeedWidget(roomId: widget.roomId),
                      ),
                      // Divider matching our velvet wine accent
                      Container(
                        height: 2,
                        color: kVelvetGold.withValues(alpha: 0.3),
                      ),
                      // Tabbed Sidebar Area (Bottom)
                      Expanded(
                        flex: 9,
                        child: _LiveRoomSidebarSection(
                          roomId: widget.roomId,
                          roomController: _roomController,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      // 70% Video Grid Area (Left)
                      Expanded(
                        flex: 7,
                        child: Container(
                          decoration: BoxDecoration(
                            color: kVelvetJet,
                            border: Border(
                              right: BorderSide(
                                color: kVelvetGold.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                          ),
                          child: VideoFeedWidget(roomId: widget.roomId),
                        ),
                      ),
                      // 30% Tabbed Sidebar Area (Right)
                      Expanded(
                        flex: 3,
                        child: _LiveRoomSidebarSection(
                          roomId: widget.roomId,
                          roomController: _roomController,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LiveRoomChatSection — Locally subscribed chat consumer for maximum performance
// ─────────────────────────────────────────────────────────────────────────────
class _LiveRoomChatSection extends ConsumerStatefulWidget {
  final String roomId;
  final RoomController roomController;

  const _LiveRoomChatSection({
    required this.roomId,
    required this.roomController,
  });

  @override
  ConsumerState<_LiveRoomChatSection> createState() =>
      _LiveRoomChatSectionState();
}

class _LiveRoomChatSectionState extends ConsumerState<_LiveRoomChatSection> {
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  bool _showEmojiTray = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(roomMessageStreamProvider(widget.roomId));
    final participantsAsync =
        ref.watch(participantsStreamProvider(widget.roomId));
    final typingIdsAsync = ref.watch(roomTypingUserIdsProvider(widget.roomId));
    final currentUser = ref.watch(userProvider);

    final participants = participantsAsync.valueOrNull ?? const [];
    final messages = messagesAsync.valueOrNull ?? const [];
    final typingIds = typingIdsAsync.valueOrNull ?? const [];

    // Map typingIds to display names
    final typingNames = typingIds.map((id) {
      final p = participants.firstWhere(
        (p) => p.userId == id,
        orElse: () => RoomParticipantModel(
          userId: id,
          role: 'audience',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
      );
      return p.displayName ?? p.userId;
    }).toList();

    // Resolvers for sender details
    String senderLabelResolver(String senderId) {
      if (senderId == currentUser?.id) return currentUser?.username ?? 'You';
      final p = participants.firstWhere(
        (p) => p.userId == senderId,
        orElse: () => RoomParticipantModel(
          userId: senderId,
          role: 'audience',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
      );
      return p.displayName ?? senderId;
    }

    int senderVipLevelResolver(String senderId) {
      final p = participants.firstWhere(
        (p) => p.userId == senderId,
        orElse: () => RoomParticipantModel(
          userId: senderId,
          role: 'audience',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
      );
      if (p.role == 'host') return 5;
      if (p.role == 'cohost') return 3;
      return 0;
    }

    String senderAvatarResolver(String senderId) {
      if (senderId == currentUser?.id) return currentUser?.photoUrl ?? '';
      final p = participants.firstWhere(
        (p) => p.userId == senderId,
        orElse: () => RoomParticipantModel(
          userId: senderId,
          role: 'audience',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
      );
      return p.photoUrl ?? '';
    }

    return ChatPanel(
      messages: messages,
      isLoadingMessages: messagesAsync.isLoading,
      currentUserId: currentUser?.id ?? '',
      currentUsername: currentUser?.username ?? 'Anonymous',
      isSending: false,
      cooldownMessage: '',
      isMuted: false,
      isBanned: false,
      allowChat: true,
      hasBlockedRelationship: false,
      showEmojiTray: _showEmojiTray,
      onToggleEmojiTray: () {
        setState(() {
          _showEmojiTray = !_showEmojiTray;
        });
      },
      onSendMessage: (text) async {
        await widget.roomController.sendMessage(text);
        _messageController.clear();
      },
      onTyping: () {
        // Handle typing notifier if needed
      },
      messageController: _messageController,
      scrollController: _scrollController,
      senderLabelResolver: senderLabelResolver,
      senderVipLevelResolver: senderVipLevelResolver,
      senderAvatarResolver: senderAvatarResolver,
      typingNames: typingNames,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LiveRoomSidebarSection — Tabbed right sidebar toggling Chat and Directory
// ─────────────────────────────────────────────────────────────────────────────
class _LiveRoomSidebarSection extends ConsumerWidget {
  final String roomId;
  final RoomController roomController;

  const _LiveRoomSidebarSection({
    required this.roomId,
    required this.roomController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Elegant TabBar matching velvet theme
          Container(
            color: kVelvetJet,
            child: const TabBar(
              indicatorColor: kVelvetGold,
              labelColor: kVelvetGold,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(
                  icon: Icon(Icons.chat_bubble_outline, size: 18),
                  text: 'Chat',
                ),
                Tab(
                  icon: Icon(Icons.people_alt_outlined, size: 18),
                  text: 'Talking Now',
                ),
              ],
            ),
          ),
          // Expanded TabBarView
          Expanded(
            child: TabBarView(
              physics:
                  const NeverScrollableScrollPhysics(), // Prevent horizontal swipe conflicts
              children: [
                // Tab 1: Chat Section
                _LiveRoomChatSection(
                  roomId: roomId,
                  roomController: roomController,
                ),
                // Tab 2: Participant Directory Section
                _LiveRoomParticipantDirectory(roomId: roomId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LiveRoomParticipantDirectory — Participant list with VIP status & levels
// ─────────────────────────────────────────────────────────────────────────────
class _LiveRoomParticipantDirectory extends ConsumerWidget {
  final String roomId;

  const _LiveRoomParticipantDirectory({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync = ref.watch(participantsStreamProvider(roomId));
    final rtcService = ref.watch(rtcServiceProvider(roomId));

    return Container(
      color: const Color(0xFF121214), // Zero-trust deep black background
      child: participantsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: kVelvetGold),
        ),
        error: (err, _) => const Center(
          child: Text(
            'Error loading participants',
            style: TextStyle(color: kVelvetWine, fontSize: 12),
          ),
        ),
        data: (participants) {
          if (participants.isEmpty) {
            return const Center(
              child: Text(
                'No participants in this room',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: participants.length,
            separatorBuilder: (context, index) => Divider(
              color: kVelvetWine.withValues(alpha: 0.15),
              height: 1,
            ),
            itemBuilder: (context, index) {
              final p = participants[index];
              final isHost = p.role == 'host';
              final isCohost = p.role == 'cohost';
              final isStage = p.role == 'stage';

              // Resolve active speaking status from RTC service stats or fallback from Firestore micOn
              final int? userRtcUid = rtcService?.remoteUids.firstWhere(
                (uid) => rtcService.userIdForUid(uid) == p.userId,
                orElse: () => 0,
              );
              final bool isSpeaking = (userRtcUid != null && userRtcUid > 0)
                  ? (rtcService?.isRemoteSpeaking(userRtcUid) ?? false)
                  : p.micOn;

              // Render VIP Level / Badges like image_d72785.jpg
              Widget vipBadge;
              if (isHost) {
                vipBadge = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.diamond, color: kVelvetGold, size: 14),
                    SizedBox(width: 2),
                    Text('HOST',
                        style: TextStyle(
                            color: kVelvetGold,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ],
                );
              } else if (isCohost) {
                vipBadge = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.star, color: Color(0xFFE2E8F0), size: 14),
                    SizedBox(width: 2),
                    Text('ADMIN',
                        style: TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ],
                );
              } else if (isStage) {
                vipBadge =
                    const Icon(Icons.star_half, color: kVelvetGold, size: 14);
              } else {
                vipBadge = const SizedBox.shrink();
              }

              // Status Icons (Microphone, Camera, and Music Note indicator for active voice)
              final List<Widget> statusIcons = [];
              if (p.micOn) {
                statusIcons.add(
                  Icon(
                    isSpeaking ? Icons.music_note : Icons.mic,
                    color: isSpeaking ? kVelvetGold : Colors.green,
                    size: 14,
                  ),
                );
              }
              if (p.camOn) {
                statusIcons.add(const SizedBox(width: 6));
                statusIcons.add(
                  const Icon(
                    Icons.videocam,
                    color: kVelvetGold,
                    size: 14,
                  ),
                );
              }
              if (p.isMuted) {
                statusIcons.add(const SizedBox(width: 6));
                statusIcons.add(
                  const Icon(
                    Icons.mic_off,
                    color: Colors.redAccent,
                    size: 14,
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSpeaking
                      ? kVelvetWine.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    // Avatar image with glowing frame if speaking
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSpeaking ? kVelvetGold : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: isSpeaking
                            ? [
                                BoxShadow(
                                    color: kVelvetGold.withValues(alpha: 0.3),
                                    blurRadius: 6)
                              ]
                            : null,
                      ),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: kVelvetWine.withValues(alpha: 0.5),
                        backgroundImage:
                            (p.photoUrl != null && p.photoUrl!.isNotEmpty)
                                ? NetworkImage(p.photoUrl!)
                                : null,
                        child: (p.photoUrl == null || p.photoUrl!.isEmpty)
                            ? Text(
                                (p.displayName ?? p.userId)
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: kVelvetGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Participant Details (Name and status text)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                p.displayName ?? p.userId,
                                style: TextStyle(
                                  color:
                                      isSpeaking ? kVelvetGold : Colors.white,
                                  fontWeight: isSpeaking
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 6),
                              vipBadge,
                            ],
                          ),
                          if (p.customStatus != null &&
                              p.customStatus!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              p.customStatus!,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Status Icons Panel
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: statusIcons,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

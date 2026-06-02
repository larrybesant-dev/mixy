import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'package:mixvy/features/room/room_controller.dart';
import 'package:mixvy/features/room/providers/room_live_state_provider.dart';
import 'package:mixvy/features/room/providers/rtc_service_provider.dart';
import 'package:mixvy/features/room/controllers/live_room_media_controller.dart';
import 'package:mixvy/features/room/widgets/chat_panel.dart';
import 'package:mixvy/core/velvet_noir_constants.dart';

// ignore_for_file: unused_element, unused_import

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
            color: kVelvetWine.withOpacity(0.6),
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: kVelvetGold.withOpacity(0.1),
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
                    color: kVelvetGold.withOpacity(0.7),
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
                color: kVelvetWine.withOpacity(0.3),
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
// VideoFeedWidget — 70% video area with WebRTC stream (placeholder for now)
// ─────────────────────────────────────────────────────────────────────────────
class VideoFeedWidget extends StatelessWidget {
  final String roomId;

  const VideoFeedWidget({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
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
              color: kVelvetGold.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Video Feed',
              style: TextStyle(
                color: kVelvetGold.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'WebRTC stream active',
              style: TextStyle(
                color: kVelvetWine.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
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
            icon:
                mediaState.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            isActive: mediaState.isVideoEnabled,
            onPressed: () async {
              await rtcService?.enableVideo(!mediaState.isVideoEnabled);
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
    final snapshot = ref.watch(roomLiveStateProvider(widget.roomId));

    return snapshot.when(
      data: (liveState) => Scaffold(
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
                final data = (roomSnap.data?.data() as Map<String, dynamic>?) ?? {};
                return RoomHeaderWidget(
                  roomTitle: data['name'] ?? data['title'] ?? 'Live Lounge',
                  hostName: data['hostUsername'] ?? 'MixVy Host',
                  participantCount: (data['memberCount'] as int?) ?? 0,
                );
              },
            ),
            // ── 70/30 Split Layout ──
            Expanded(
              child: Row(
                children: [
                  // 70% Video Feed
                  Expanded(
                    flex: 7,
                    child: Container(
                      decoration: BoxDecoration(
                        color: kVelvetJet,
                        border: Border(
                          right: BorderSide(
                            color: kVelvetGold.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      ),
                      child: VideoFeedWidget(roomId: widget.roomId),
                    ),
                  ),
                  // 30% Chat Panel
                  Expanded(
                    flex: 3,
                    child: Container(
                      color: kVelvetJet.withOpacity(0.98),
                      child: ChatPanel(
                        messages: liveState.message,
                        isLoadingMessages: false,
                        currentUserId: ref.watch(userProvider)?.id ?? '',
                        currentUsername:
                            ref.watch(userProvider)?.username ?? 'Anonymous',
                        isSending: false,
                        cooldownMessage: '',
                        isMuted: false,
                        isBanned: false,
                        allowChat: true,
                        hasBlockedRelationship: false,
                        showEmojiTray: false,
                        onToggleEmojiTray: () {},
                        onSendMessage: (t) => _roomController.sendMessage(t),
                        onTyping: () {},
                        messageController: TextEditingController(),
                        scrollController: ScrollController(),
                        senderLabelResolver: (id) => '',
                        senderVipLevelResolver: (id) => 0,
                        senderAvatarResolver: (id) => '',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      loading: () => Scaffold(
        backgroundColor: kVelvetJet,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kVelvetGold),
          ),
        ),
      ),
      error: (e, stack) => Scaffold(
        backgroundColor: kVelvetJet,
        body: Center(
          child: Text(
            'Error: $e',
            style: const TextStyle(color: kVelvetGold),
          ),
        ),
      ),
    );
  }
}

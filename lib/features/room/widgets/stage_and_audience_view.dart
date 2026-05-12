import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/contracts/room_contract.dart';
import 'package:mixvy/models/room_participant_model.dart';
import 'package:mixvy/services/rtc_room_service.dart';
import '../../../presentation/providers/user_provider.dart';
import '../controllers/live_room_media_controller.dart';
import '../providers/rtc_service_provider.dart';
import '../room_controller.dart';
import 'room_user_tile.dart';
import 'live_stage_spotlight.dart';
import 'camera_wall.dart';

/// STAGE AND AUDIENCE VIEW
/// 
/// This is the primary rendering engine for the Live Room.
/// Logic:
/// 1. Stage (Top): Renders CameraWall (if video exists) or Spotlight (if audio only).
/// 2. Audience (Bottom): Renders a bandwidth-optimized Avatar grid.
/// 3. Bandwidth Governor: Automatically sets High/Low quality bitrates for RTC.

class StageAndAudienceView extends ConsumerWidget {
  const StageAndAudienceView({
    super.key,
    required this.roomId,
    required this.roomState,
  });

  final String roomId;
  final RoomLiveState roomState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RtcRoomService? rtcService = ref.watch(rtcServiceProvider(roomId));
    // CRITICAL: Watch media controller for reactive local-video updates
    final mediaState = ref.watch(liveRoomMediaControllerProvider(roomId));
    
    final hasVideoStreams = (rtcService?.remoteUids.isNotEmpty ?? false) ||
        (rtcService?.isLocalVideoCapturing ?? false) ||
        mediaState.isVideoEnabled;
    final currentUserId = ref.watch(userProvider)?.id ?? '';
    final isHost = roomState.roomDoc['hostId'] == currentUserId;
    final controller = ref.read(roomControllerProvider(roomId).notifier);

    final filteredAudience = roomState.audience.where((p) {
      if (p.userId == currentUserId) {
        // If current user is on mic or has video, hide from audience list
        return !((rtcService?.isLocalVideoCapturing ?? false) || 
               (ref.read(roomControllerProvider(roomId)).isOnMicByAuthority(currentUserId)));
      }
      return true;
    }).toList();

    return CustomScrollView(
      slivers: [
        // ── STAGE AREA (The 4-Mic Priority Zone) ────────────────────────
        SliverToBoxAdapter(
          child: Container(
            constraints: const BoxConstraints(minHeight: 320),
            child: hasVideoStreams
                ? CameraWall(
                    roomId: roomId,
                    roomName: roomState.title,
                    localLabel: 'You',
                    localSpeaking: rtcService?.localSpeaking ?? false,
                    showLocalTile: rtcService?.isLocalVideoCapturing ?? false,
                    localTile: rtcService?.getLocalView() ?? const SizedBox.shrink(),
                    remoteTiles: _buildRemoteTiles(rtcService, roomState),
                    remoteTileBuilder: (tile) =>
                        rtcService?.getRemoteView(tile.uid, roomId) ??
                        const SizedBox.shrink(),
                    
                    // ── BANDWIDTH GOVERNOR ───────────────────────────
                    // Tells the RTC engine which streams to prioritize in HD
                    onSubscriptionPlanChanged: (highQualityUids, lowQualityUids) {
                      if (rtcService == null) return;
                      for (final uid in highQualityUids) {
                        rtcService.setRemoteVideoSubscription(uid, subscribe: true, highQuality: true);
                      }
                      for (final uid in lowQualityUids) {
                        rtcService.setRemoteVideoSubscription(uid, subscribe: true, highQuality: false);
                      }
                    },
                    
                    // ── HOST MODERATION ──────────────────────────────
                    isHost: isHost,
                    onDropUser: (targetId) => controller.dropFromMic(targetId),
                    onMuteUser: (targetId, mute) => controller.muteUserToggle(targetId, mute),
                  )
                : LiveStageSpotlight(
                    roomId: roomId,
                    roomName: roomState.title,
                    displayNameById: {for (final p in roomState.speakers) p.userId: p.displayName ?? 'User'},
                    avatarUrlById: {for (final p in roomState.speakers) p.userId: p.photoUrl},
                    viewerCount: roomState.memberCount,
                    primaryActionLabel: roomState.speakerIds.isEmpty ? 'Take the Mic' : null,
                    onPrimaryAction: () => controller.requestMic(userId: currentUserId),
                  ),
          ),
        ),

        // ── AUDIENCE GRID (Optimized for 100+ Users) ─────────────────────
        if (filteredAudience.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 32, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.people_outline, size: 14, color: Color(0xFFAD9585)),
                  SizedBox(width: 8),
                  Text(
                    'AUDIENCE',
                    style: TextStyle(
                      color: Color(0xFFAD9585),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final p = filteredAudience[index];
                  return RoomUserTile(
                    displayName: p.displayName ?? 'User',
                    avatarUrl: p.photoUrl,
                    role: p.role,
                    isMicOn: false, 
                    isMuted: p.isMuted,
                    isMe: p.userId == currentUserId,
                    layout: RoomUserTileLayout.grid,
                    compact: true,
                  );
                },
                childCount: filteredAudience.length,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  List<CameraWallRemoteTileData> _buildRemoteTiles(
    RtcRoomService? rtcService,
    RoomLiveState state,
  ) {
    if (rtcService == null) return const [];
    final List<int> remoteUids = rtcService.remoteUids;
    final onMicUserIds = state.speakers.map((s) => s.userId).toSet();
    
    return remoteUids.map((uid) {
      final userId = rtcService.userIdForUid(uid);
      final participant = state.speakers.firstWhere(
        (p) => p.userId == userId,
        orElse: () => RoomParticipantModel(
          userId: userId ?? '',
          role: 'audience',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
      );
      return CameraWallRemoteTileData(
        uid: uid,
        userId: userId,
        label: participant.displayName ?? 'User',
        canView: true,
        isSpeaking: rtcService.isRemoteSpeaking(uid),
        hasMic: onMicUserIds.contains(userId),
        avatarUrl: participant.photoUrl,
      );
    }).toList();
  }
}

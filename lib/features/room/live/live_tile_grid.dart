// lib/features/room/live/live_tile_grid.dart
//
// Video tile grid for the cost-optimized multi-user video room.
//
// Behaviour:
//   • Renders up to 8 broadcaster tiles in a responsive grid.
//   • Notifies the controller whenever the visible tile set changes so
//     subscriptions are added/removed accordingly.
//   • Shows avatar + "CAM" badge for participants marked isOnCam=true in
//     Firestore even before the actual video stream begins — this creates the
//     "always-on illusion" of the architecture.
//   • Shows live video via AgoraVideoView only for participants whose
//     agoraUid is known and whose tile is in the visible set.
// ───────────────────────────────────────────────────────────────────────────

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'live_room_schema.dart';
import 'live_room_controller.dart';

class LiveTileGrid extends ConsumerStatefulWidget {
  const LiveTileGrid({super.key, required this.args});

  final LiveRoomArgs args;

  @override
  ConsumerState<LiveTileGrid> createState() => _LiveTileGridState();
}

class _LiveTileGridState extends ConsumerState<LiveTileGrid> {
  List<int> _lastVisibleUids = [];

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(liveRoomControllerProvider);
    final ctrl = ref.read(liveRoomControllerProvider.notifier);

    // Always show grid participants (they ARE the visible set in a fixed grid)
    final gridParts = roomState.gridParticipants;

    // Compute currently-visible engine uids and notify controller when changed
    final visibleUids = gridParts
        .where((p) => p.agoraUid != null)
        .map((p) => p.agoraUid!)
        .toList();

    if (!_listEquals(visibleUids, _lastVisibleUids)) {
      _lastVisibleUids = visibleUids;
      // Schedule after build to avoid setState-during-build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ctrl.setVisibleEngineUids(visibleUids);
      });
    }

    if (gridParts.isEmpty) {
      return _EmptyGridPlaceholder(
        message: roomState.isJoining ? 'Connecting…' : 'No one on cam yet.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = gridParts.length <= 2 ? gridParts.length : 2;
        final rows = (gridParts.length / cols).ceil();
        final tileW = constraints.maxWidth / cols;
        final tileH = rows > 0
            ? (constraints.maxHeight / rows).clamp(80.0, 240.0)
            : 180.0;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: tileW / tileH,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: gridParts.length,
          itemBuilder: (ctx, i) => _TileCard(
            participant: gridParts[i],
            isLocal: gridParts[i].userId == roomState.localUserId,
            isHost: roomState.isHost,
            engine: kIsWeb ? null : ctrl.videoEngine,
            channelId: widget.args.roomId,
            activeSpeakerUid: roomState.activeSpeakerUid,
            onDemote: (roomState.isHost &&
                    gridParts[i].userId != roomState.localUserId)
                ? () async {
                    final err =
                        await ctrl.demoteParticipant(gridParts[i].userId);
                    if (err != null && ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(err),
                          backgroundColor: const Color(0xFFFF4C4C),
                        ),
                      );
                    }
                  }
                : null,
          ),
        );
      },
    );
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ── Single tile card ───────────────────────────────────────────────────────

class _TileCard extends StatelessWidget {
  const _TileCard({
    required this.participant,
    required this.isLocal,
    required this.isHost,
    required this.engine,
    required this.channelId,
    this.activeSpeakerUid,
    this.onDemote,
  });

  final RoomParticipant participant;
  final bool isLocal;
  final bool isHost;
  final RtcEngine? engine;
  final String channelId;
  final int? activeSpeakerUid;
  final VoidCallback? onDemote;

  bool get _isSpeaking =>
      participant.agoraUid != null && participant.agoraUid == activeSpeakerUid;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              _isSpeaking ? const Color(0xFF00FF88) : const Color(0xFF3A1A5E),
          width: _isSpeaking ? 2.5 : 1,
        ),
        boxShadow: _isSpeaking
            ? [
                BoxShadow(
                  color: const Color(0xFF00FF88).withAlpha(80),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video layer ───────────────────────────────────────────────
            _buildVideoLayer(),

            // ── Name tag ──────────────────────────────────────────────────
            Positioned(
              bottom: 6,
              left: 6,
              right: 6,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        participant.displayName + (isLocal ? ' (you)' : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (participant.isMicActive)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child:
                          Icon(Icons.mic, color: Color(0xFF00FF88), size: 14),
                    ),
                ],
              ),
            ),

            // ── CAM-on badge (logical state, before stream starts) ────────
            if (participant.isOnCam && !participant.isStreaming)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4C4C).withAlpha(200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'CAM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // ── LIVE badge ────────────────────────────────────────────────
            if (participant.isStreaming)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0040),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '● LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // ── Host demotion button (top-left, host-only) ────────────────
            if (onDemote != null)
              Positioned(
                top: 4,
                left: 4,
                child: GestureDetector(
                  onTap: onDemote,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCC0022).withAlpha(220),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoLayer() {
    final uid = participant.agoraUid;

    // No engine (web) or no uid yet — show avatar
    if (engine == null || uid == null || !participant.isOnCam) {
      return _AvatarPlaceholder(
        displayName: participant.displayName,
        avatarUrl: participant.avatarUrl,
      );
    }

    // Local user
    if (isLocal) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine!,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }

    // Remote user
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine!,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: channelId),
      ),
    );
  }
}

// ── Avatar placeholder ─────────────────────────────────────────────────────

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.displayName, this.avatarUrl});

  final String displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D1A),
      child: Center(
        child: avatarUrl != null
            ? CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(avatarUrl!),
                onBackgroundImageError: (_, __) {},
              )
            : CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF3A1A5E),
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Empty grid placeholder ─────────────────────────────────────────────────

class _EmptyGridPlaceholder extends StatelessWidget {
  const _EmptyGridPlaceholder({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF3A1A5E).withAlpha(120),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Color(0xFF5A3A7E), size: 40),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9A7ABE),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

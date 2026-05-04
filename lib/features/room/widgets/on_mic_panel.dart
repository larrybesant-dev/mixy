import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/room_participant_model.dart';
import '../../../presentation/providers/user_provider.dart';
import '../controllers/live_room_controller.dart';
import '../providers/participant_providers.dart';
import 'room_user_tile.dart';

/// Panel shown above the chat that displays everyone currently on the mic
/// (roles: host, cohost, stage). Shows a small placeholder when empty.
///
/// Renders a [RoomUserTile] per participant in a horizontally-scrollable row,
/// with the host appearing first and larger, followed by co-hosts and stage
/// speakers. Each tile shows the role badge, mic state, and (for stage users)
/// a live countdown badge when a mic-time limit is active.
class OnMicPanel extends ConsumerWidget {
  const OnMicPanel({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.displayNameById,
  });

  final String roomId;
  final String currentUserId;

  /// Display-name lookup keyed by userId (same map used by UserListPanel).
  final Map<String, String> displayNameById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Derive the ordered speaker list from the single-authority controller,
    // then hydrate with participant models. This eliminates the duplicate
    // onMicParticipantsProvider computation path.
    final speakerIds = ref.watch(
      liveRoomControllerProvider(roomId).select((s) => s.speakerIds),
    );
    final participantsAsync = ref.watch(participantsStreamProvider(roomId));

    final participants = participantsAsync.valueOrNull ?? const [];
    final participantByUser = {
      for (final p in participants) p.userId.trim(): p,
    };
    // Preserve controller-determined order; skip IDs without a loaded model.
    final sorted = speakerIds
        .map((id) => participantByUser[id.trim()])
        .whereType<RoomParticipantModel>()
        .toList(growable: false);

    return _buildPanel(context, sorted);
  }

  Widget _buildPanel(BuildContext context, List<RoomParticipantModel> sorted) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF0B0A12),
        border: Border(top: BorderSide(color: Color(0x207C5FFF))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────
          Container(
            height: 30,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF16122A), Color(0xFF0B0A12)],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const _PulsingMicIcon(),
                const SizedBox(width: 6),
                const Text(
                  'ON STAGE',
                  style: TextStyle(
                    color: Color(0xFFD4A853),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(width: 6),
                if (sorted.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x509B2535),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${sorted.length}',
                      style: const TextStyle(
                        color: Color(0xFFFF6E84),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  Icon(Icons.mic_none, color: Color(0x60D4A853), size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Stage is open',
                    style: TextStyle(
                      color: Color(0x80D4A853),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final p = sorted[index];
                  final name =
                      displayNameById[p.userId] ??
                      resolvePublicUsername(uid: p.userId);
                  final isMe = p.userId == currentUserId;
                  return RoomUserTile(
                    displayName: name,
                    role: p.role,
                    isMicOn: p.micOn,
                    isMuted: p.isMuted,
                    isMe: isMe,
                    micExpiresAt: p.micExpiresAt,
                    layout: RoomUserTileLayout.grid,
                    compact: true,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
// _roleOrder() removed — speaker ordering is owned by RoomController

/// Pulsing mic icon to draw attention to the "On Mic" header.
class _PulsingMicIcon extends StatefulWidget {
  const _PulsingMicIcon();

  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: const Icon(Icons.mic, color: Color(0xFFC45E7A), size: 14),
    );
  }
}

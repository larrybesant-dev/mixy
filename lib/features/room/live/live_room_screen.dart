// lib/features/room/live/live_room_screen.dart
//
// Main room screen for the cost-optimized multi-user video room architecture.
//
// This screen:
//   • Mounts the controller via liveRoomControllerProvider
//   • Handles app lifecycle (background/foreground) via WidgetsBindingObserver
//   • Renders the tile grid, audience row, chat input, and controls
//   • Enforces leave-on-pop (calls leaveRoom before Navigator.pop)
// ───────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/messaging_providers.dart';
import '../../../services/chat/messaging_service.dart';
import '../../../shared/models/message.dart';
import 'live_room_schema.dart';
import 'live_room_state.dart';
import 'live_room_controller.dart';
import 'live_tile_grid.dart';
import '../widgets/reaction_bar.dart';
import '../../../shared/widgets/pop_out_avatar.dart';

class LiveRoomScreen extends ConsumerStatefulWidget {
  const LiveRoomScreen({
    super.key,
    required this.roomId,
    required this.displayName,
    this.avatarUrl,
  });

  final String roomId;
  final String displayName;
  final String? avatarUrl;

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen>
    with WidgetsBindingObserver {
  late final LiveRoomArgs _args;
  final _chatController = TextEditingController();
  final _chatScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _args = LiveRoomArgs(
      roomId: widget.roomId,
      displayName: widget.displayName,
      avatarUrl: widget.avatarUrl,
    );
    WidgetsBinding.instance.addObserver(this);
    // Defer enterRoom so the provider is fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(liveRoomControllerProvider.notifier).enterRoom(_args);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatController.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  // ── Lifecycle observer ────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = ref.read(liveRoomControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        ctrl.onSuspended();
      case AppLifecycleState.resumed:
        ctrl.onResumed();
      case AppLifecycleState.inactive:
        break;
    }
  }

  // ── Leave handling ────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    final ctrl = ref.read(liveRoomControllerProvider.notifier);
    final state = ref.read(liveRoomControllerProvider);
    if (!state.isLeft && !state.isLeaving) {
      await ctrl.leaveRoom();
    }
    return true;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(liveRoomControllerProvider);

    // Listen for forced-exit events (room deleted / closed)
    ref.listen<LiveRoomState>(liveRoomControllerProvider, (prev, next) {
      if (!mounted) return;
      // When we reach "left" and there's an error message, surface it as a banner
      if (next.isLeft && next.error != null && (prev == null || !prev.isLeft)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: const Color(0xFFCC4400),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // When local role changes from broadcaster → audience (demoted by host)
      if (prev != null &&
          prev.isBroadcaster &&
          !next.isBroadcaster &&
          next.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have been removed from the stage.'),
            backgroundColor: Color(0xFF663300),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    // Auto-pop once we have fully left
    if (roomState.isLeft) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final nav = Navigator.of(context);
          if (await _onWillPop()) nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A18),
        appBar: _buildAppBar(roomState),
        body: _buildBody(roomState),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(LiveRoomState s) {
    return AppBar(
      backgroundColor: const Color(0xFF12082A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 18),
        onPressed: () async {
          if (await _onWillPop() && mounted) Navigator.of(context).pop();
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.roomMeta?.name ?? widget.roomId,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${s.participants.length} in room  •  ${s.onCamCount} on cam',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
      actions: [
        // Invite friends button
        IconButton(
          icon: const Icon(Icons.person_add_alt_1_outlined,
              color: Colors.white70, size: 20),
          tooltip: 'Invite friends',
          onPressed: () => _showInviteSheet(s),
        ),
        if (s.isActive || s.isSuspended)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              backgroundColor: s.isSuspended
                  ? const Color(0xFF444444)
                  : const Color(0xFF1A8A4A),
              label: Text(
                s.isSuspended ? 'PAUSED' : 'LIVE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(LiveRoomState s) {
    if (s.isJoining) return _buildLoadingView(s.statusMessage ?? 'Loading…');
    if (s.hasError) return _buildErrorView(s.error ?? 'Unknown error');

    return Column(
      children: [
        // ── Tile grid ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.42,
              minHeight: (MediaQuery.of(context).size.height * 0.42).clamp(0.0, 180.0),
            ),
            child: LiveTileGrid(args: _args),
          ),
        ),

        // ── Audience row ────────────────────────────────────────────────
        if (s.audienceParticipants.isNotEmpty)
          _AudienceRow(participants: s.audienceParticipants),

        // ── Controls ────────────────────────────────────────────────────
        _ControlBar(args: _args, state: s),

        // ── Reaction bar ────────────────────────────────────────────────
        ReactionBarWidget(onReact: _sendReaction),

        // ── Host: pending cam requests ──────────────────────────────────────
        if (s.isHost && s.pendingRequests.isNotEmpty)
          _PendingRequestsPanel(pendingRequests: s.pendingRequests),
        // ── Divider ─────────────────────────────────────────────────────
        const Divider(color: Color(0xFF2A1A3E), height: 1),

        // ── Chat ────────────────────────────────────────────────────────
        Expanded(
          child: _ChatArea(
            scrollController: _chatScroll,
            roomId: widget.roomId,
          ),
        ),

        // ── Chat input ──────────────────────────────────────────────────
        _ChatInputBar(
          controller: _chatController,
          onSend: () {
            final text = _chatController.text.trim();
            if (text.isEmpty) return;
            _chatController.clear();
            _sendChatMessage(text);
          },
        ),
      ],
    );
  }

  // ── Invite friends bottom sheet ────────────────────────────────────

  void _showInviteSheet(LiveRoomState s) {
    final roomId = widget.roomId;
    final roomName = s.roomMeta?.name ?? roomId;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12082A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InviteFriendsSheet(
        roomId: roomId,
        roomName: roomName,
      ),
    );
  }

  // ── Reaction helper ─────────────────────────────────────────────────────────

  Future<void> _sendReaction(String emoji) async {
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;
      await ref.read(messagingServiceProvider).sendRoomMessage(
            senderId: user.id,
            senderName: user.displayName ?? user.username,
            senderAvatarUrl: user.avatarUrl,
            roomId: widget.roomId,
            content: emoji,
          );
    } catch (e) {
      debugPrint('[ROOM_SCREEN] reaction error: $e');
    }
  }

  // ── Chat helpers ────────────────────────────────────────────────────────────

  Future<void> _sendChatMessage(String text) async {
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;
      await ref.read(messagingServiceProvider).sendRoomMessage(
            senderId: user.id,
            senderName: user.displayName ?? user.username,
            senderAvatarUrl: user.avatarUrl,
            roomId: widget.roomId,
            content: text,
          );
    } catch (e) {
      debugPrint('[ROOM_SCREEN] send error: $e');
    }
  }

  Widget _buildLoadingView(String message) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFF4C4C)),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );

  Widget _buildErrorView(String error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFFF4C4C), size: 48),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4C4C),
                ),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      );
}

// ── Audience row ───────────────────────────────────────────────────────────

class _AudienceRow extends StatelessWidget {
  const _AudienceRow({required this.participants});
  final List<RoomParticipant> participants;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFF0D0D1A),
      child: Row(
        children: [
          const Icon(Icons.people, color: Colors.white38, size: 16),
          const SizedBox(width: 6),
          Text(
            '${participants.length} watching',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: participants.length.clamp(0, 12),
              itemBuilder: (ctx, i) {
                final p = participants[i];
                final pending = p.camRequestPending;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PopOutAvatar(
                        uid: p.userId,
                        tooltip: p.displayName,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: pending
                              ? const Color(0xFF7A5200)
                              : const Color(0xFF3A1A5E),
                          backgroundImage: p.avatarUrl != null
                              ? NetworkImage(p.avatarUrl!)
                              : null,
                          child: p.avatarUrl == null
                              ? Text(
                                  p.displayName.isNotEmpty
                                      ? p.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      // Raised-hand badge for pending requests
                      if (pending)
                        const Positioned(
                          right: -2,
                          bottom: -2,
                          child: Icon(
                            Icons.front_hand,
                            size: 11,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Control bar ────────────────────────────────────────────────────────────

class _ControlBar extends ConsumerWidget {
  const _ControlBar({required this.args, required this.state});
  final LiveRoomArgs args;
  final LiveRoomState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(liveRoomControllerProvider.notifier);
    // Detect whether the local user has a pending cam request
    final myParticipant = state.participants
        .where((p) => p.userId == state.localUserId)
        .firstOrNull;
    final isRequestPending = myParticipant?.camRequestPending ?? false;

    return Container(
      color: const Color(0xFF12082A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Cam toggle (broadcasters + host) OR Go Live (audience)
          if (state.isBroadcaster)
            _ControlButton(
              icon: state.isCamOn ? Icons.videocam : Icons.videocam_off,
              label: state.isCamOn ? 'Cam on' : 'Cam off',
              active: state.isCamOn,
              onTap: () async {
                final err = await ctrl.toggleCam();
                if (err != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err),
                      backgroundColor: const Color(0xFFFF4C4C),
                    ),
                  );
                }
              },
            )
          else
            _ControlButton(
              icon: isRequestPending ? Icons.hourglass_top : Icons.live_tv,
              label: isRequestPending ? 'Requested' : 'Go Live',
              active: isRequestPending,
              activeColor: const Color(0xFFFFAA00),
              onTap: () async {
                if (isRequestPending) {
                  await ctrl.cancelCamRequest();
                } else {
                  final err = await ctrl.requestCam();
                  if (err != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err),
                        backgroundColor: const Color(0xFFFF4C4C),
                      ),
                    );
                  }
                }
              },
            ),

          // Mic toggle
          _ControlButton(
            icon: state.isMicOn ? Icons.mic : Icons.mic_off,
            label: state.isMicOn ? 'Mic on' : 'Mic off',
            active: state.isMicOn,
            onTap: () async {
              final err = await ctrl.toggleMic();
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(err),
                    backgroundColor: const Color(0xFFFF4C4C),
                  ),
                );
              }
            },
          ),

          // Mic count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E0E3A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF5A3A7E)),
            ),
            child: Text(
              '${state.activeMicCount}/${state.maxActiveMics} mics',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),

          // Leave button
          _ControlButton(
            icon: Icons.call_end,
            label: 'Leave',
            active: false,
            activeColor: const Color(0xFFFF1744),
            onTap: () async {
              await ctrl.leaveRoom();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (activeColor ?? const Color(0xFF00FF88))
        : (activeColor ?? Colors.white38);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active ? color.withAlpha(30) : const Color(0xFF1E0E3A),
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(120)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Chat area ──────────────────────────────────────────────────────────────

class _ChatArea extends ConsumerWidget {
  const _ChatArea({required this.scrollController, required this.roomId});
  final ScrollController scrollController;
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(roomMessagesProvider(roomId));

    return messagesAsync.when(
      loading: () => const Center(
        child:
            CircularProgressIndicator(color: Color(0xFF5A3A7E), strokeWidth: 2),
      ),
      error: (e, _) => const Center(
        child: Text(
          'Chat unavailable',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ),
      data: (messages) {
        if (messages.isEmpty) {
          return const Center(
            child: Text(
              'Be the first to say something!',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          );
        }

        // Scroll to bottom when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (ctx, i) => _ChatBubble(message: messages[i]),
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PopOutAvatar(
            uid: message.senderId,
            tooltip: message.senderName,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFF3A1A5E),
              backgroundImage: message.senderAvatarUrl.isNotEmpty
                  ? NetworkImage(message.senderAvatarUrl)
                  : null,
              child: message.senderAvatarUrl.isEmpty
                  ? Text(
                      message.senderName.isNotEmpty
                          ? message.senderName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${message.senderName}  ',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: message.content,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
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

// ── Pending cam requests panel (host only) ────────────────────────────────

class _PendingRequestsPanel extends ConsumerWidget {
  const _PendingRequestsPanel({required this.pendingRequests});
  final List<RoomParticipant> pendingRequests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(liveRoomControllerProvider.notifier);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0E30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                const Icon(Icons.live_tv, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 6),
                Text(
                  '${pendingRequests.length} cam request${pendingRequests.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF3A2A5E), height: 1),
          ...pendingRequests.map(
            (p) => _PendingRequestRow(
              participant: p,
              onApprove: () async {
                final err = await ctrl.approveRequest(p.userId);
                if (err != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err),
                      backgroundColor: const Color(0xFFFF4C4C),
                    ),
                  );
                }
              },
              onDeny: () => ctrl.denyRequest(p.userId),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingRequestRow extends StatelessWidget {
  const _PendingRequestRow({
    required this.participant,
    required this.onApprove,
    required this.onDeny,
  });
  final RoomParticipant participant;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          PopOutAvatar(
            uid: participant.userId,
            tooltip: participant.displayName,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF3A1A5E),
              backgroundImage: participant.avatarUrl != null
                  ? NetworkImage(participant.avatarUrl!)
                  : null,
              child: participant.avatarUrl == null
                  ? Text(
                      participant.displayName.isNotEmpty
                          ? participant.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              participant.displayName,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onApprove,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1A8A4A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Let in',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDeny,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF3A1A5E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Deny',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat input bar ─────────────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF12082A),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Say something…',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1A0A2A),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFFF4C4C),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Invite Friends Sheet ───────────────────────────────────────────────────

class _InviteFriendsSheet extends StatefulWidget {
  final String roomId;
  final String roomName;
  const _InviteFriendsSheet(
      {required this.roomId, required this.roomName});

  @override
  State<_InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<_InviteFriendsSheet> {
  final Set<String> _invited = {};

  Future<void> _sendInvite(String toUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(toUid)
        .collection('roomInvites')
        .add({
      'fromUid': myUid,
      'roomId': widget.roomId,
      'roomName': widget.roomName,
      'sentAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    if (mounted) setState(() => _invited.add(toUid));
  }

  Stream<List<_RoomFriend>> _onlineFriendsStream() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .collection('following')
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isEmpty) return <_RoomFriend>[];
      final uids = snap.docs.map((d) => d.id).take(30).toList();
      final res = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: uids)
          .where('isOnline', isEqualTo: true)
          .get();
      return res.docs
          .map((d) => _RoomFriend(
                uid: d.id,
                name: (d.data()['displayName'] as String?) ?? 'User',
                photo: d.data()['photoUrl'] as String?,
              ))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          const Text('Invite Online Friends',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(widget.roomName,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF2A1A3E), height: 1),
          Flexible(
            child: StreamBuilder<List<_RoomFriend>>(
              stream: _onlineFriendsStream(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFFF4C4C), strokeWidth: 2)),
                  );
                }
                final friends = snap.data!;
                if (friends.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No online friends right now',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 13),
                        textAlign: TextAlign.center),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: friends.length,
                  itemBuilder: (_, i) {
                    final f = friends[i];
                    final sent = _invited.contains(f.uid);
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF3A1A5E),
                        backgroundImage: f.photo != null
                            ? NetworkImage(f.photo!)
                            : null,
                        child: f.photo == null
                            ? Text(f.name[0].toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13))
                            : null,
                      ),
                      title: Text(f.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                      subtitle: const Text('Online',
                          style: TextStyle(
                              color: Color(0xFF00E676), fontSize: 11)),
                      trailing: sent
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF00E676), size: 20)
                          : TextButton(
                              onPressed: () => _sendInvite(f.uid),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFFF4C4C)
                                    .withValues(alpha: 0.15),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14)),
                              ),
                              child: const Text('Invite',
                                  style: TextStyle(
                                      color: Color(0xFFFF4C4C),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomFriend {
  final String uid;
  final String name;
  final String? photo;
  const _RoomFriend({required this.uid, required this.name, this.photo});
}

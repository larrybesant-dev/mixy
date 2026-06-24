import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/design_system/design_constants.dart' hide JoinPhase;
import '../controllers/agora_room_controller.dart';
import '../controllers/join_flow_controller.dart';
import '../../../shared/models/participant.dart';
import '../widgets/room_header_widget.dart';
import '../widgets/participant_list_widget.dart';
import '../widgets/media_controls_widget.dart';
import '../widgets/host_controls_widget.dart';
import '../widgets/chat_overlay_widget.dart';
import 'join_room_screen.dart';
import 'leave_room_screen.dart';
import '../../../shared/models/chat_message.dart';
import '../../../shared/providers/room_chat_presence_providers.dart';

class PolishedRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;
  final String agoraToken;
  final String hostId;
  final VoidCallback? onLeaveRoom;

  const PolishedRoomScreen({
    required this.roomId,
    required this.roomName,
    required this.agoraToken,
    this.hostId = '',
    this.onLeaveRoom,
    super.key,
  });

  @override
  ConsumerState<PolishedRoomScreen> createState() => _PolishedRoomScreenState();
}

class _PolishedRoomScreenState extends ConsumerState<PolishedRoomScreen>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _initializeRoom();
  }

  bool _showJoinScreen = true;
  bool _showLeaveScreen = false;
  bool _showChat = false;
  bool _showParticipants = false;
  int _unreadMessages = 0;

  bool get _isHost {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;
    // Check both the widget param and the live state (handles late-loaded rooms)
    final stateHostId = ref.read(agoraRoomProvider).hostId;
    return uid == widget.hostId ||
        (stateHostId.isNotEmpty && uid == stateHostId);
  }

  Future<void> _initializeRoom() async {
    final notifier = ref.read(agoraRoomProvider.notifier);
    final currentUser = FirebaseAuth.instance.currentUser;
    notifier.setRoomContext(
      roomId: widget.roomId,
      userId: currentUser?.uid ?? 'anonymous',
      userName: currentUser?.displayName ??
          currentUser?.email?.split('@').first ??
          'Guest',
      hostId: widget.hostId,
    );
  }

  void _handleJoin() async {
    setState(() => _showJoinScreen = false);
    try {
      await ref
          .read(agoraRoomProvider.notifier)
          .joinRoom(agoraToken: widget.agoraToken);
    } catch (e) {
      _showError('Failed to join room: $e');
      setState(() => _showJoinScreen = true);
    }
  }

  void _handleLeaveAttempt() {
    setState(() => _showLeaveScreen = true);
  }

  void _handleLeaveConfirm() async {
    setState(() => _showLeaveScreen = false);
    try {
      await ref.read(agoraRoomProvider.notifier).leaveRoom();
      widget.onLeaveRoom?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Failed to leave room: $e');
    }
  }

  void _handleLeaveCancel() {
    setState(() => _showLeaveScreen = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: DesignColors.error,
      ),
    );
  }

  void _toggleChat() {
    setState(() {
      _showChat = !_showChat;
      if (_showChat) {
        _unreadMessages = 0;
      }
    });
  }

  void _toggleParticipants() {
    setState(() => _showParticipants = !_showParticipants);
  }

  void _sendMessage(String content) {
    final currentUser = FirebaseAuth.instance.currentUser;
    ref.read(roomMessagesProvider(widget.roomId).notifier).sendMessage(
          content,
          currentUser?.displayName ??
              currentUser?.email?.split('@').first ??
              'Guest',
          currentUser?.uid ?? 'anonymous',
        );
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(agoraRoomProvider);
    return Scaffold(
      backgroundColor: DesignColors.background,
      body: Builder(builder: (context) {
        // Show join screen
        if (_showJoinScreen) {
          return JoinRoomScreen(
            roomName: widget.roomName,
            roomId: widget.roomId,
            onJoin: _handleJoin,
            onCancel: () => Navigator.pop(context),
          );
        }

        // Show leave confirmation
        if (_showLeaveScreen) {
          return LeaveRoomScreen(
            roomName: widget.roomName,
            participantCount: roomState.participants.length,
            timeInRoom: const Duration(minutes: 15),
            onLeave: _handleLeaveConfirm,
            onCancel: _handleLeaveCancel,
          );
        }

        // Main room view
        return Stack(
          children: [
            Container(color: DesignColors.background),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: RoomHeader(
                roomName: widget.roomName,
                roomId: widget.roomId,
                participantCount: roomState.participants.length,
                isHost: _isHost,
                onLeave: _handleLeaveAttempt,
                onSettings: () {},
                onInvite: () {},
              ),
            ),
            Positioned(
              top: 140,
              left: 0,
              right: _showParticipants
                  ? MediaQuery.of(context).size.width * 0.3
                  : 0,
              bottom: 120,
              child: _buildMainContent(roomState),
            ),
            if (_showParticipants)
              Positioned(
                top: 140,
                right: 0,
                width: MediaQuery.of(context).size.width * 0.3,
                bottom: 120,
                child: Container(
                  color: DesignColors.surface,
                  child: ParticipantListWidget(
                    participants: roomState.participants,
                    hostId: widget.hostId.isNotEmpty
                        ? widget.hostId
                        : roomState.hostId,
                    onParticipantTap: (participant) {
                      _showParticipantActionsMenu(context, participant);
                    },
                  ),
                ),
              ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: MediaControlsWidget(
                  isMicEnabled: !roomState.isMicMuted,
                  isCameraEnabled: !roomState.isVideoMuted,
                  onMicToggle: (_) =>
                      ref.read(agoraRoomProvider.notifier).toggleMicrophone(),
                  onCameraToggle: (_) =>
                      ref.read(agoraRoomProvider.notifier).toggleVideo(),
                  onMoreOptions: _toggleParticipants,
                ),
              ),
            ),
            HostControlsOverlay(
              controls: HostControlsWidget(
                  isHost: _isHost, onEndRoom: _handleLeaveAttempt),
              child: const SizedBox.shrink(),
            ),
            Builder(builder: (context) {
              final messagesState =
                  ref.watch(roomMessagesProvider(widget.roomId));
              final chatMessages = messagesState.messages
                  .map((rm) => ChatMessage(
                        id: rm.id,
                        senderId: rm.senderId,
                        senderName: rm.senderName,
                        content: rm.text,
                        timestamp: rm.createdAt,
                        context: MessageContext.room,
                        roomId: widget.roomId,
                        contentType: rm.type == 'system'
                            ? MessageContentType.system
                            : MessageContentType.text,
                      ))
                  .toList();
              return ChatOverlayWidget(
                messages: chatMessages,
                isVisible: _showChat,
                unreadCount: _unreadMessages,
                onSendMessage: _sendMessage,
                onToggleVisibility: _toggleChat,
                currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
              );
            }),
            Positioned(
              top: 160,
              right: 20,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    onPressed: _toggleChat,
                    backgroundColor: DesignColors.accent,
                    child: Badge(
                      label: _unreadMessages > 0
                          ? Text(_unreadMessages.toString())
                          : null,
                      child: const Icon(Icons.chat),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.small(
                    onPressed: _toggleParticipants,
                    backgroundColor: DesignColors.surface,
                    child: const Icon(Icons.people),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMainContent(AgoraRoomState roomState) {
    if (!roomState.isInRoom) {
      return _buildJoinFlowOverlay();
    }
    final participants = roomState.participants;
    if (participants.isEmpty) {
      return _buildWaitingForParticipants();
    }

    // Use the multi-cam video grid here
    // TODO: Integrate with VideoTileWidget and GridWindowWidget
    return Container(
      color: Colors.grey[900],
      child: GridView.builder(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          mainAxisSpacing: DesignSpacing.lg,
          crossAxisSpacing: DesignSpacing.lg,
          childAspectRatio: 1.2,
        ),
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final participant = participants[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: DesignColors.accent.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.videocam,
                    size: 48,
                    color: DesignColors.accent,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    participant.name,
                    style: const TextStyle(color: DesignColors.white),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJoinFlowOverlay() {
    final joinFlow = ref.watch(joinFlowProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(DesignColors.accent),
          ),
          const SizedBox(height: DesignSpacing.xl),
          Text(
            joinFlow.phase.displayText,
            style: DesignTypography.heading.copyWith(
              color: DesignColors.white,
            ),
            textAlign: TextAlign.center,
          ),
          if (joinFlow.phase == JoinPhase.error &&
              joinFlow.errorMessage != null) ...[
            const SizedBox(height: DesignSpacing.md),
            Text(
              joinFlow.errorMessage!,
              style: DesignTypography.body.copyWith(color: DesignColors.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaitingForParticipants() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: DesignColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: DesignSpacing.lg),
          Text(
            'Waiting for participants...',
            style: DesignTypography.heading.copyWith(
              color: DesignColors.white,
            ),
          ),
          const SizedBox(height: DesignSpacing.md),
          Text(
            'Share the room link to invite others',
            style: DesignTypography.body.copyWith(
              color: DesignColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showParticipantActionsMenu(
      BuildContext context, Participant participant) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading:
                Icon(participant.isMuted ? Icons.volume_up : Icons.volume_off),
            title: Text(participant.isMuted ? 'Unmute for me' : 'Mute for me'),
            onTap: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(participant.isMuted
                        ? 'Unmuted ${participant.name}'
                        : 'Muted ${participant.name}')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('View Profile'),
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.of(context)
                  .pushNamed('/profile/user', arguments: participant.uid);
            },
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('Spotlight'),
            onTap: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Spotlighting ${participant.name}')),
              );
            },
          ),
        ],
      ),
    );
  }
}

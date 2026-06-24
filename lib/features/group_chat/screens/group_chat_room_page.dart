import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_chat_message.dart';
import '../models/group_chat_participant.dart';
import '../providers/group_chat_providers.dart';
import 'package:mixvy/shared/widgets/async_value_view_enhanced.dart';
import 'package:mixvy/shared/widgets/skeleton_loaders.dart';
import 'package:mixvy/shared/providers/user_providers.dart';

class GroupChatRoomPage extends ConsumerStatefulWidget {
  final String roomId;

  const GroupChatRoomPage({super.key, required this.roomId});

  @override
  ConsumerState<GroupChatRoomPage> createState() => _GroupChatRoomPageState();
}

class _GroupChatRoomPageState extends ConsumerState<GroupChatRoomPage> {
  final _messageController = TextEditingController();
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinRoom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _leaveRoom();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _joining = true);

    // Fetch user's displayName from Firestore UserProfile
    final userProfile =
        await ref.read(profileServiceProvider).getCurrentUserProfile();
    final displayName = userProfile?.displayName ?? user.email ?? 'Guest';

    final chatService = ref.read(groupChatServiceProvider);
    await chatService.joinRoom(
      widget.roomId,
      username: displayName,
      avatarUrl: userProfile?.photoUrl ?? user.photoURL,
    );

    await chatService.updateMediaState(widget.roomId,
        isMuted: false, isCameraOn: true);
    await ref
        .read(groupCallControllerProvider.notifier)
        .initializeAndJoin(widget.roomId);
    if (mounted) {
      setState(() => _joining = false);
    }
  }

  Future<void> _leaveRoom() async {
    await ref.read(groupCallControllerProvider.notifier).leaveRoom();
    await ref.read(groupChatServiceProvider).leaveRoom(widget.roomId);
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(groupRoomProvider(widget.roomId));
    final participantsAsync =
        ref.watch(groupParticipantsProvider(widget.roomId));
    final messagesAsync = ref.watch(groupMessagesProvider(widget.roomId));
    final callState = ref.watch(groupCallControllerProvider);

    final engine = ref.read(groupCallControllerProvider.notifier).engine;

    return Scaffold(
      appBar: AppBar(
        title: Text(roomAsync.when(
          data: (room) => room?.name ?? widget.roomId,
          loading: () => 'Joining... ',
          error: (_, __) => 'Room',
        )),
        actions: [
          IconButton(
            icon: Icon(callState.isMicMuted ? Icons.mic_off : Icons.mic),
            onPressed: () => ref
                .read(groupCallControllerProvider.notifier)
                .toggleMic(roomId: widget.roomId),
          ),
          IconButton(
            icon: Icon(
                callState.isVideoMuted ? Icons.videocam_off : Icons.videocam),
            onPressed: () => ref
                .read(groupCallControllerProvider.notifier)
                .toggleVideo(roomId: widget.roomId),
          ),
          IconButton(
            icon: const Icon(Icons.call_end),
            onPressed: () async {
              await _leaveRoom();
              if (!mounted) return;
              if (!context.mounted) return;
              Navigator.of(context).maybePop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_joining) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Row(
              children: [
                // Video + chat stack
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _buildVideoGrid(callState, engine),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Card(
                          margin: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Expanded(
                                child: AsyncValueViewEnhanced<
                                    List<GroupChatMessage>>(
                                  value: messagesAsync,
                                  maxRetries: 3,
                                  skeleton: const Column(
                                    children: [
                                      SkeletonBubble(isUserMessage: false),
                                      SizedBox(height: 8),
                                      SkeletonBubble(isUserMessage: true),
                                      SizedBox(height: 8),
                                      SkeletonBubble(isUserMessage: false),
                                    ],
                                  ),
                                  screenName: 'GroupChatRoomPage',
                                  providerName: 'groupMessagesProvider',
                                  onRetry: () => ref.invalidate(
                                      groupMessagesProvider(widget.roomId)),
                                  data: (messages) =>
                                      _buildMessageList(messages),
                                ),
                              ),
                              _buildComposer(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Participants panel
                SizedBox(
                  width: 260,
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    child: participantsAsync.when(
                      data: (participants) =>
                          _buildParticipantList(participants),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) =>
                          Center(child: Text('Participants unavailable: $err')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid(GroupCallState callState, RtcEngine? engine) {
    final tiles = <Widget>[];

    if (engine != null) {
      tiles.add(AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      ));

      for (final uid in callState.remoteUids) {
        tiles.add(AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: engine,
            canvas: VideoCanvas(uid: uid),
            connection: RtcConnection(channelId: widget.roomId),
          ),
        ));
      }
    }

    if (tiles.isEmpty) {
      return const Center(
        child: Text(
          'Camera preview will appear here when joined',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final crossAxisCount = tiles.length <= 2 ? 1 : 2;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      physics: const NeverScrollableScrollPhysics(),
      children: tiles,
    );
  }

  Widget _buildParticipantList(List<GroupChatParticipant> participants) {
    return ListView.separated(
      itemCount: participants.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = participants[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage:
                p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
            child: p.avatarUrl == null
                ? Text(
                    p.username.isNotEmpty ? p.username[0].toUpperCase() : '?')
                : null,
          ),
          title: Text(p.username),
          subtitle: Row(
            children: [
              Icon(p.isMuted ? Icons.mic_off : Icons.mic, size: 16),
              const SizedBox(width: 6),
              Icon(p.isCameraOn ? Icons.videocam : Icons.videocam_off,
                  size: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageList(List<GroupChatMessage> messages) {
    return ListView.builder(
      reverse: true,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        final currentUser = FirebaseAuth.instance.currentUser;
        final isCurrentUser = message.senderId == currentUser?.uid;

        return Align(
          alignment:
              isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.all(8),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.8)
                  : Colors.grey[700],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isCurrentUser)
                  Text(
                    message.senderName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400],
                    ),
                  ),
                if (!isCurrentUser) const SizedBox(height: 2),
                Text(
                  message.text,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(hintText: 'Message'),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await ref
        .read(groupChatServiceProvider)
        .sendTextMessage(widget.roomId, text);
  }
}


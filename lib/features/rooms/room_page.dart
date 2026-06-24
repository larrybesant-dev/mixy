import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../providers/room_members_provider.dart';
import '../../providers/messages_provider.dart';
import '../../providers/agora_engine_provider.dart';
import '../../models/room_member_model.dart';

class RoomPage extends ConsumerWidget {
  final String roomId;
  const RoomPage({super.key, required this.roomId});

  final String agoraAppId = 'YOUR_AGORA_APP_ID'; // Replace with your actual Agora App ID
  final String token = 'YOUR_AGORA_TOKEN'; // Replace with your actual token logic
  final int localUid = 0; // Replace with actual user ID logic

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(roomMembersProvider(roomId));
    final messagesAsync = ref.watch(messagesProvider(roomId));
    final agoraEngine = ref.read(agoraEngineProvider);

    // Initialize and join channel on first build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await agoraEngine.initialize(agoraAppId);
      await agoraEngine.joinChannel(token, roomId, localUid);
      agoraEngine.setEventHandlers(RtcEngineEventHandler(
        onUserJoined: (RtcConnection conn, int remoteUid, int elapsed) {
          // Handle remote user joined
        },
        onUserOffline: (RtcConnection conn, int remoteUid, UserOfflineReasonType reason) {
          // Handle remote user left
        },
      ));
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Room')),
      body: Column(
        children: [
          // Audio/video controls
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.mic),
                onPressed: () => agoraEngine.muteLocalAudio(false),
              ),
              IconButton(
                icon: const Icon(Icons.mic_off),
                onPressed: () => agoraEngine.muteLocalAudio(true),
              ),
              IconButton(
                icon: const Icon(Icons.videocam),
                onPressed: () => agoraEngine.enableLocalVideo(true),
              ),
              IconButton(
                icon: const Icon(Icons.videocam_off),
                onPressed: () => agoraEngine.enableLocalVideo(false),
              ),
            ],
          ),
          // Video grid
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                // Local video placeholder
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: Text('Your Video', style: TextStyle(color: Colors.white)),
                  ),
                ),
                // Remote videos placeholder
                Positioned(
                  left: 120,
                  child: Container(
                    width: 100,
                    height: 150,
                    color: Colors.grey[800],
                    child: const Center(
                      child: Text('Remote', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Stage & Audience layout
          Expanded(
            child: membersAsync.when(
              data: (members) {
                if (members.isEmpty) {
                  return const Center(child: Text('No members in this room'));
                }
                final stage = members.where((m) => m.role == RoomMemberRole.host || m.role == RoomMemberRole.coHost).toList();
                final audience = members.where((m) => m.role == RoomMemberRole.listener).toList();
                return ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: Text('Stage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ...stage.map((m) => Card(
                      color: Colors.amber[50],
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.emoji_events, color: Colors.orange),
                        title: Text(m.userId, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(m.role.toString().split('.').last),
                        trailing: _HostControls(member: m, roomId: roomId),
                      ),
                    )),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: Text('Audience', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ...audience.map((m) => Card(
                      color: Colors.blue[50],
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.person, color: Colors.blue),
                        title: Text(m.userId),
                        subtitle: Text(m.role.toString().split('.').last),
                        // No host controls for audience
                      ),
                    )),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading members: $e')),
            ),
          ),
          const Divider(),
          Expanded(
            child: messagesAsync.when(
              data: (messages) => messages.isEmpty
                  ? const Center(child: Text('No messages yet'))
                  : ListView(
                      children: messages.map((msg) => ListTile(
                        title: Text(msg.senderId),
                        subtitle: Text(msg.text),
                      )).toList(),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading messages: $e')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _MessageInput(roomId: roomId),
          ),
        ],
      ),
    );
  }
}

/// Host controls widget for room members
class _HostControls extends ConsumerWidget {
  final RoomMember member;
  final String roomId;

  const _HostControls({
    required this.member,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.mic_off, size: 18),
          onPressed: () {
            // TODO: Mute member
          },
        ),
        IconButton(
          icon: const Icon(Icons.videocam_off, size: 18),
          onPressed: () {
            // TODO: Disable member's video
          },
        ),
      ],
    );
  }
}

/// Message input widget for rooms
class _MessageInput extends ConsumerWidget {
  final String roomId;

  const _MessageInput({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    return Container(
      color: Colors.grey[900],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blue),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                // TODO: Send message
                controller.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}

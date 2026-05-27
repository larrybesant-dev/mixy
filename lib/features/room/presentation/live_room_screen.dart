// ignore_for_file: unused_element, unused_import
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/room_model.dart';
import '../controllers/live_room_media_controller.dart';
import '../providers/room_live_state_provider.dart';
import '../room_controller.dart';
import '../providers/rtc_service_provider.dart';
import '../widgets/chat_panel.dart';
import '../../../presentation/providers/user_provider.dart';

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
  final dynamic controllerState; // Swapped to dynamic to match structural scope if type isn't exported here

  const _FloatingControlBar({required this.roomId, required this.controllerState});

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
            icon: mediaState.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
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
        body: Row(
          children: [
            Expanded(
              child: ChatPanel(
                messages: liveState.message,
                isLoadingMessages: false,
                currentUserId: ref.watch(userProvider)?.id ?? '',
                currentUsername: ref.watch(userProvider)?.username ?? 'Anonymous',
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
          ],
        ),
      ),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, stack) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}
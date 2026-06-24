import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../shared/providers/all_providers.dart';
import '../../shared/models/room.dart';
import 'message_bubble.dart';
import '../../shared/club_background.dart';
import '../../shared/glow_text.dart';
import '../../shared/neon_button.dart';
import '../../shared/gift_selector.dart';
import '../../core/design_system/design_constants.dart';
import '../../core/design_system/app_layout.dart';

class RoomPage extends ConsumerStatefulWidget {
  final Room room;

  const RoomPage({super.key, required this.room});

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends ConsumerState<RoomPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isAgoraInitialized = false;
  bool _hasInitializedAgora = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAgora();
    });
  }

  Future<void> _initializeAgora() async {
    if (_hasInitializedAgora) return;

    // Guard: do not attempt join when offline
    if (connectivityNotifier.isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection — cannot join video room.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final agoraService = ref.read(agoraVideoServiceProvider);

      // Initialize Agora engine if needed
      if (!agoraService.isInitialized) {
        await agoraService.initialize();
      }

      // Join the room channel
      await agoraService.joinRoom(widget.room.id);

      AnalyticsService.instance.logEvent(
        name: 'room_join_success',
        parameters: {'room_id': widget.room.id},
      );

      if (mounted) {
        setState(() {
          _isAgoraInitialized = true;
          _hasInitializedAgora = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize Agora: $e');
      AnalyticsService.instance.logEvent(
        name: 'room_join_failed',
        parameters: {'room_id': widget.room.id, 'error': e.toString()},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to join video: ${e.toString()}')));
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Leave room if we were in one
    if (_isAgoraInitialized) {
      AnalyticsService.instance.logEvent(
        name: 'room_leave',
        parameters: {'room_id': widget.room.id},
      );
      try {
        ref.read(agoraVideoServiceProvider).leaveRoom();
      } catch (e) {
        debugPrint('Error leaving room: $e');
      }
    }
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      await ref.read(
        sendRoomMessageProvider({
          'content': _messageController.text.trim(),
          'roomId': widget.room.id
        }).future,
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send message: ${e.toString()}')));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.room.id));

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: GlowText(
            text: widget.room.name ?? widget.room.title,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: DesignColors.gold,
            glowColor: DesignColors.accent,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.card_giftcard, color: Colors.white),
              onPressed: () => _showGiftSelector(context),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () => _showRoomMenu(context),
            ),
          ],
        ),
        body: Column(
          children: [
            // Video area with Agora video views
            Padding(
              padding: const EdgeInsets.all(AppSpacing.spaceLG),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: DesignColors.accent.withValues(alpha: 0.5),
                        width: 2),
                    borderRadius:
                        BorderRadius.circular(AppSizes.cardBorderRadius),
                    boxShadow: [
                      BoxShadow(
                          color: DesignColors.accent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppSizes.cardBorderRadius - 2),
                    child: _isAgoraInitialized &&
                            ref.read(agoraVideoServiceProvider).engine != null
                        ? Stack(
                            children: [
                              // Remote video (full screen background)
                              if (ref
                                  .read(agoraVideoServiceProvider)
                                  .remoteUsers
                                  .isNotEmpty)
                                AgoraVideoView(
                                  controller: VideoViewController.remote(
                                    rtcEngine: ref
                                        .read(agoraVideoServiceProvider)
                                        .engine!,
                                    canvas: VideoCanvas(
                                        uid: ref
                                            .read(agoraVideoServiceProvider)
                                            .remoteUsers
                                            .first),
                                    connection: RtcConnection(
                                        channelId: widget.room.id),
                                  ),
                                ),
                              // Local video (small overlay)
                              Positioned(
                                top: AppSpacing.spaceSM + 2,
                                right: AppSpacing.spaceSM + 2,
                                width: 100,
                                height: 133,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: DesignColors.white, width: 2),
                                    borderRadius: BorderRadius.circular(
                                        AppSpacing.spaceSM),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: AgoraVideoView(
                                      controller: VideoViewController(
                                        rtcEngine: ref
                                            .read(agoraVideoServiceProvider)
                                            .engine!,
                                        canvas: VideoCanvas(
                                          uid: ref
                                                  .read(
                                                      agoraVideoServiceProvider)
                                                  .localUid ??
                                              0,
                                          renderMode:
                                              RenderModeType.renderModeHidden,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            color: DesignColors.surfaceDefault,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                      color: DesignColors.accent),
                                  SizedBox(height: AppSpacing.spaceLG),
                                  GlowText(
                                      text: 'Initializing video...',
                                      fontSize: 16,
                                      glowColor: DesignColors.accent),
                                ],
                              ),
                            )), // closes loading Container / Center
                  ), // ClipRRect
                ), // Container(decoration)
              ), // AspectRatio
            ), // Padding
            // Messages area
            Expanded(
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLG),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppSizes.cardBorderRadius),
                  border: Border.all(
                      color: DesignColors.accent.withValues(alpha: 0.3),
                      width: 1),
                ),
                child: messagesAsync.when(
                  data: (messages) {
                    final currentUser = ref.watch(currentUserProvider);
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSpacing.spaceLG),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return MessageBubble(
                            message: messages[index],
                            currentUserId: currentUser.value?.id ?? '');
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(DesignColors.accent)),
                  ),
                  error: (error, stack) => Center(
                    child: GlowText(
                      text: 'Error loading messages: ${error.toString()}',
                      fontSize: 14,
                      color: DesignColors.accent,
                    ),
                  ),
                ),
              ),
            ),
            // Video controls
            if (_isAgoraInitialized) ...[
              Container(
                height: AppSizes.controlBarHeight,
                margin:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLG),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildVideoControlButton(
                      icon: ref.watch(agoraVideoServiceProvider).isMicMuted
                          ? Icons.mic_off
                          : Icons.mic,
                      label: ref.watch(agoraVideoServiceProvider).isMicMuted
                          ? 'Unmute'
                          : 'Mute',
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref.read(agoraVideoServiceProvider).toggleMic();
                          if (mounted) {
                            setState(() {});
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(SnackBar(
                                content:
                                    Text('Failed to toggle microphone: $e')));
                          }
                        }
                      },
                    ),
                    const SizedBox(width: AppSpacing.spaceLG),
                    _buildVideoControlButton(
                      icon: ref.watch(agoraVideoServiceProvider).isVideoMuted
                          ? Icons.videocam_off
                          : Icons.videocam,
                      label: ref.watch(agoraVideoServiceProvider).isVideoMuted
                          ? 'Camera On'
                          : 'Camera Off',
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref
                              .read(agoraVideoServiceProvider)
                              .toggleVideo();
                          if (mounted) {
                            setState(() {});
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(SnackBar(
                                content: Text('Failed to toggle camera: $e')));
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.spaceLG),
            ],
            // Message input with nightclub styling
            Container(
              margin: const EdgeInsets.all(AppSpacing.spaceLG),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppSizes.buttonBorderRadius + 10),
                border: Border.all(
                    color: DesignColors.accent.withValues(alpha: 0.3),
                    width: 1),
                boxShadow: [
                  BoxShadow(
                      color: DesignColors.accent.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 1),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.spaceXL,
                            vertical: AppSpacing.spaceLG),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: AppSpacing.spaceSM),
                    child: NeonButton(
                      onPressed: _sendMessage,
                      padding: const EdgeInsets.all(AppSpacing.spaceMD),
                      child:
                          const Icon(Icons.send, size: AppSizes.iconStandard),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGiftSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => GiftSelector(
        receiverId: widget.room.hostId,
        receiverName: widget.room.hostName ?? 'Host',
        roomId: widget.room.id,
      ),
    );
  }

  void _showRoomMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('View Participants'),
            onTap: () {
              Navigator.of(context).pop();
              // TODO: Show participants list
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share Room'),
            onTap: () {
              Navigator.of(context).pop();
              // TODO: Share room link
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Leave Room'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to home
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoControlButton(
      {required IconData icon,
      required String label,
      required VoidCallback onPressed}) {
    return Container(
      width: 88,
      height: AppSizes.controlBarHeight - 12,
      decoration: BoxDecoration(
        color: DesignColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSizes.buttonBorderRadius + 4),
        border: Border.all(
            color: DesignColors.gold.withValues(alpha: 0.3), width: 2),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSizes.buttonBorderRadius + 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: AppSizes.iconLarge),
            const SizedBox(height: AppSpacing.spaceXS),
            Text(
              label,
              style: AppTypography.captionSm
                  .copyWith(color: DesignColors.textGray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

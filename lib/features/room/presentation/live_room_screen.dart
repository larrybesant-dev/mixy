import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/config/agora_constants.dart';

import '../../../models/room_model.dart';
import '../controllers/live_room_media_controller.dart';
import '../controllers/webrtc_controller.dart';
import '../providers/message_providers.dart';
import '../repository/room_repository.dart';
import '../providers/room_live_state_provider.dart';
import '../../../models/room_participant_model.dart';
import '../room_controller.dart';
import '../providers/rtc_service_provider.dart';
import '../widgets/stage_and_audience_view.dart';
import '../widgets/chat_panel.dart';
import '../widgets/user_list_panel.dart';
import '../widgets/floating_gift_overlay.dart';
import '../providers/room_gift_provider.dart';
import '../../../dev/room_inspector_panel.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../services/rtc_room_service.dart';

// Wide-screen cap — prevents the chat from stretching across a 1440px monitor.


// ─────────────────────────────────────────────────────────────────────────────
// ROOT SCREEN
// Owns the Riverpod watch and routes to one of three scaffold variants.
// ─────────────────────────────────────────────────────────────────────────────

class LiveRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final RoomModel? previewRoom;

  const LiveRoomScreen({super.key, required this.roomId, this.previewRoom});

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> {
  late RoomController _roomController;
  late LiveRoomMediaController _mediaController;
  RtcRoomService? _rtcService;

  bool _connectedBannerVisible = false;
  bool _connectedShown = false;
  bool _isAutoJoining = false;

  @override
  void initState() {
    super.initState();
    _roomController = ref.read(roomControllerProvider(widget.roomId).notifier);
    _mediaController = ref.read(
      liveRoomMediaControllerProvider(widget.roomId).notifier,
    );

    ref.listenManual(userProvider, (previous, next) {
      if (next != null && previous == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _autoJoin();
          }
        });
      }
    }, fireImmediately: true);
  }

  Future<void> _autoJoin() async {
    if (!mounted || _isAutoJoining) return;
    _isAutoJoining = true;

    final user = ref.read(userProvider);
    if (user == null) return;
    final mediaController = ref.read(
      liveRoomMediaControllerProvider(widget.roomId).notifier,
    );
    mediaController.beginConnecting();

    final joinResult = await _roomController.joinRoom(
      user.id,
      displayName: user.username,
      avatarUrl: user.avatarUrl,
    );
    if (!mounted) return;
    if (!joinResult.isSuccess) {
      final reason = joinResult.errormessage ?? 'Room joining unavailable.';
      mediaController.markConnectionFailed(callError: reason, cameraStatus: 'Join blocked');
      return;
    }

    // --- Fix: Wait for room document to load ---
    // Ensure the app waits for the Firestore snapshot before initializing the WebRTC session.
    // This prevents "Untitled Room" or null-doc errors during RTC handshakes.
    try {
      debugPrint('LOG: [Web] Waiting for room document for widget.roomId...');
      await ref.read(roomLiveStateProvider(widget.roomId).future).timeout(const Duration(seconds: 10));
      debugPrint('LOG: [Web] Room document loaded for ${widget.roomId}');
    } catch (e) {
      debugPrint('LOG: [Web] Timeout or error waiting for room snapshot: $e');
      // Proceed anyway, but we logged the delay.
    }

    try {
      final webrtcCtrl = ref.read(webrtcControllerProvider);
      List<Map<String, dynamic>>? iceServers;
      try {
        debugPrint('LOG: [Web] Fetching ICE servers...');
        iceServers = await ref.read(roomRepositoryProvider).fetchIceServers();
        debugPrint('LOG: [Web] ICE servers fetched.');
      } catch (e) {
        debugPrint('LOG: [Web] ICE server fetch failed: $e');
      }
      
      debugPrint('LOG: [Web] Creating transport...');
      final service = await webrtcCtrl.createTransport(
        userId: user.id,
        iceServers: iceServers,
      );
      debugPrint('LOG: [Web] Transport created. Initializing...');
      await service.initialize(AgoraConstants.appId.trim());
      debugPrint('LOG: [Web] RTC Service initialized. Joining room...');
      await service.joinRoom('', widget.roomId, _stableUid(user.id));
      debugPrint('LOG: [Web] RTC Service joined.');
      
      // Hook up media status sync
      service.onLocalVideoCaptureChanged = () {
        _mediaController.syncFromService(
          isVideoEnabled: service.isLocalVideoCapturing,
          isMicMuted: service.isLocalAudioMuted,
          isSharingSystemAudio: service.isSharingSystemAudio,
        );
      };
      service.onSpeakerActivityChanged = () {
         _mediaController.syncFromService(
          isVideoEnabled: service.isLocalVideoCapturing,
          isMicMuted: service.isLocalAudioMuted,
          isSharingSystemAudio: service.isSharingSystemAudio,
        );
      };

      if (!mounted) {
        debugPrint('LOG: [Web] Screen unmounted during RTC join.');
        await service.dispose();
        return;
      }
      _rtcService = service;
      ref.read(rtcServiceProvider(widget.roomId).notifier).state = service;
      mediaController.markReady(
        rtcUid: _stableUid(user.id),
        cameraStatus: 'RTC connected.',
        isMicMuted: service.isLocalAudioMuted,
        isVideoEnabled: service.isLocalVideoCapturing,
      );
      if (mounted && !_connectedShown) {
        _connectedShown = true;
        setState(() => _connectedBannerVisible = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _connectedBannerVisible = false);
        });
      }
    } catch (e) {
      debugPrint('LOG: [Web] RTC media setup failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('RTC Connection Failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
      mediaController.markConnectionFailed(callError: 'RTC media failed: $e', cameraStatus: 'RTC degraded');
    } finally {
      _isAutoJoining = false;
    }
  }

  static int _stableUid(String userId) {
    int h = 0;
    for (final c in userId.codeUnits) { h = (h * 31 + c) & 0x7FFFFFFF; }
    return h == 0 ? 1 : h;
  }

  @override
  void dispose() {
    _rtcService?.dispose().ignore();
    scheduleMicrotask(() => _mediaController.resetDisconnected());
    RoomContractGuard.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Watch the room controller state to keep the provider alive.
    // This prevents the controller from being auto-disposed and losing the 'joined' phase
    // while the screen is still active.
    final roomState = ref.watch(roomControllerProvider(widget.roomId));
    
    final snapshot = ref.watch(roomLiveStateProvider(widget.roomId));
    final liveState = snapshot.valueOrNull;

    if (liveState != null && liveState.title != 'Loading...') {
      return _RoomScaffold(
        roomId: widget.roomId,
        roomState: liveState,
        controllerState: roomState,
        reconnecting: snapshot.isLoading || snapshot.hasError,
        showConnectedBanner: _connectedBannerVisible,
      );
    }

    return snapshot.when(
      loading: () => _LoadingScaffold(roomId: widget.roomId, previewRoom: widget.previewRoom),
      error: (e, _) => _ErrorScaffold(error: e, onBack: () => Navigator.of(context).maybePop()),
      data: (_) => const SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingScaffold extends ConsumerWidget {
  final String roomId;
  final RoomModel? previewRoom;
  const _LoadingScaffold({required this.roomId, this.previewRoom});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorScaffold extends StatelessWidget {
  final Object error;
  final VoidCallback onBack;
  const _ErrorScaffold({required this.error, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error: $error', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onBack, child: const Text('Go Back')),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOM SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────

class _RoomScaffold extends StatefulWidget {
  final String roomId;
  final RoomLiveState roomState;
  final RoomState controllerState;
  final bool reconnecting;
  final bool showConnectedBanner;

  const _RoomScaffold({
    required this.roomId,
    required this.roomState,
    required this.controllerState,
    required this.reconnecting,
    this.showConnectedBanner = false,
  });

  @override
  State<_RoomScaffold> createState() => _RoomScaffoldState();
}

class _RoomScaffoldState extends State<_RoomScaffold> {
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  final GlobalKey<FloatingGiftOverlayState> _giftOverlayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _RoomScaffoldView(
      roomId: widget.roomId,
      roomState: widget.roomState,
      controllerState: widget.controllerState,
      reconnecting: widget.reconnecting,
      showConnectedBanner: widget.showConnectedBanner,
      messageController: _messageController,
      scrollController: _scrollController,
      giftOverlayKey: _giftOverlayKey,
    );
  }
}

class _RoomScaffoldView extends ConsumerWidget {
  final String roomId;
  final RoomLiveState roomState;
  final RoomState controllerState;
  final bool reconnecting;
  final bool showConnectedBanner;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final GlobalKey<FloatingGiftOverlayState> giftOverlayKey;

  const _RoomScaffoldView({
    required this.roomId,
    required this.roomState,
    required this.controllerState,
    required this.reconnecting,
    required this.showConnectedBanner,
    required this.messageController,
    required this.scrollController,
    required this.giftOverlayKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(userProvider)?.id ?? '';
    final isHost = roomState.roomDoc['hostId'] == currentUserId;

    ref.listen(roomGiftStreamProvider(roomId), (prev, next) {
      next.whenData((events) {
        if (events.isNotEmpty && prev?.valueOrNull?.first.id != events.first.id) {
          giftOverlayKey.currentState?.spawnGift('🪙');
        }
      });
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        elevation: 0,
        leading: const BackButton(),
        title: Text(roomState.title.isEmpty ? 'Live Room' : roomState.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [RoomInspectorButton(roomId: roomId)],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              // ── MAIN STAGE AREA (Left, Flex 7) ──────────────────────────
              Expanded(
                flex: 7,
                child: Stack(
                  children: [
                    StageAndAudienceView(roomId: roomId, roomState: roomState),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _FloatingControlBar(roomId: roomId, controllerState: controllerState),
                      ),
                    ),
                  ],
                ),
              ),

              // ── SIDEBAR AREA (Right, Flex 3) ────────────────────────────
              Container(
                width: 350,
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.white10, width: 1)),
                  color: Color(0xFF111111),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(-2, 0))],
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 1,
                      child: UserListPanel(
                        participants: (roomState.speakers + roomState.audience),
                        currentUserId: currentUserId,
                        presenceList: roomState.presence,
                        displayNameById: {for (final p in (roomState.speakers + roomState.audience)) p.userId: p.displayName ?? 'User'},
                        avatarUrlById: {for (final p in (roomState.speakers + roomState.audience)) p.userId: p.photoUrl},
                        isCurrentUserHost: isHost,
                        onKick: (p) => ref.read(roomControllerProvider(roomId).notifier).removeUser(p.userId),
                        onMute: (p) => ref.read(roomControllerProvider(roomId).notifier).muteUserToggle(p.userId, !p.isMuted),
                        onDropFromMic: (p) => ref.read(roomControllerProvider(roomId).notifier).dropFromMic(p.userId),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    Expanded(
                      flex: 1,
                      child: ChatPanel(
                        messages: roomState.message,
                        isLoadingMessages: false,
                        currentUserId: currentUserId,
                        currentUsername: ref.watch(userProvider)?.username ?? '',
                        isSending: false,
                        cooldownMessage: '',
                        isMuted: (roomState.speakers + roomState.audience).any((p) => p.userId == currentUserId && p.isMuted),
                        isBanned: false,
                        allowChat: true,
                        hasBlockedRelationship: false,
                        showEmojiTray: false,
                        onToggleEmojiTray: () {},
                        onSendMessage: (text) async {
                          await ref.read(roomControllerProvider(roomId).notifier).sendMessage(text);
                          messageController.clear();
                        },
                        onTyping: () => ref.read(roomControllerProvider(roomId).notifier).setTyping(userId: currentUserId, isTyping: true),
                        messageController: messageController,
                        scrollController: scrollController,
                        senderLabelResolver: (id) => (roomState.speakers + roomState.audience).firstWhere((p) => p.userId == id, orElse: () => RoomParticipantModel(userId: id, role: 'audience', joinedAt: DateTime.now(), lastActiveAt: DateTime.now())).displayName ?? 'User',
                        senderVipLevelResolver: (id) => 0,
                        senderAvatarResolver: (id) => (roomState.speakers + roomState.audience).firstWhere((p) => p.userId == id, orElse: () => RoomParticipantModel(userId: id, role: 'audience', joinedAt: DateTime.now(), lastActiveAt: DateTime.now())).photoUrl,
                        typingNames: ref.watch(roomTypingUserIdsProvider(roomId)).valueOrNull ?? [],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showConnectedBanner)
            Positioned(top: 0, left: 0, right: 0, child: _JoinedRoomBanner(title: roomState.title.isEmpty ? 'the room' : roomState.title)),
          if (reconnecting)
            const Positioned(top: 0, left: 0, right: 0, child: _ReconnectingBanner()),
          FloatingGiftOverlay(key: giftOverlayKey),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.errorContainer,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
          SizedBox(width: 8),
          Text('Reconnecting…', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _JoinedRoomBanner extends StatelessWidget {
  final String title;
  const _JoinedRoomBanner({required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.green, Colors.blue])),
      child: Text('You joined $title', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

class _FloatingControlBar extends ConsumerWidget {
  final String roomId;
  final RoomState controllerState;
  const _FloatingControlBar({required this.roomId, required this.controllerState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rtcService = ref.watch(rtcServiceProvider(roomId));
    final isCamOn = rtcService?.isLocalVideoCapturing ?? false;
    final isMicOn = rtcService != null ? !rtcService.isLocalAudioMuted : false;
    final isSharing = rtcService?.isSharingSystemAudio ?? false;

    // Helper to ensure controller is joined before performing actions
    Future<bool> ensureJoined() async {
      if (controllerState.phase == LiveRoomPhase.joined) return true;
      
      debugPrint('LOG: [Web] Action attempted while controller in phase: ${controllerState.phase}. Attempting re-join...');
      final user = ref.read(userProvider);
      if (user == null) return false;
      
      final result = await ref.read(roomControllerProvider(roomId).notifier).joinRoom(
        user.id,
        displayName: user.username,
        avatarUrl: user.avatarUrl,
      );
      return result.isSuccess;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white10),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15, spreadRadius: 2)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlIconButton(
            icon: isCamOn ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            isActive: isCamOn,
            onPressed: () async {
              if (rtcService == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('RTC Connection not ready.')),
                  );
                }
                return;
              }
              
              if (!await ensureJoined()) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wait for room to join...')),
                  );
                }
                return;
              }

              if (kIsWeb && !isCamOn) {
                debugPrint('LOG: [Web] Requesting Camera Access...');
                try {
                  // Ensure we have permissions before attempting to enable video
                  await rtcService.ensureDeviceAccess(video: true, audio: true);
                } catch (e) {
                  debugPrint('LOG: [Web] Camera access failed: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Camera Access Error: ${e.toString()}'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                  return;
                }
              }
              try {
                await rtcService.enableVideo(!isCamOn);
              } catch (e) {
                debugPrint('LOG: Failed to toggle video: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to toggle video: $e')),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 20),
          _ControlIconButton(
            icon: isMicOn ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            isActive: isMicOn,
            activeColor: Colors.blueAccent,
            onPressed: () async {
              if (rtcService == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('RTC Connection not ready.')),
                  );
                }
                return;
              }
              
              if (!await ensureJoined()) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wait for room to join...')),
                  );
                }
                return;
              }

              try {
                if (isMicOn) {
                  await rtcService.mute(true);
                  await rtcService.setBroadcaster(false);
                } else {
                  if (kIsWeb) {
                    debugPrint('LOG: [Web] Requesting Microphone Access...');
                    try {
                      // Ensure we have permissions before requesting mic from controller/service
                      await rtcService.ensureDeviceAccess(video: false, audio: true);
                    } catch (e) {
                      debugPrint('LOG: [Web] Microphone access failed: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Microphone Access Error: ${e.toString()}'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                      return;
                    }
                  }
                  final user = ref.read(userProvider);
                  if (user != null) {
                    await ref.read(roomControllerProvider(roomId).notifier).requestMic(userId: user.id);
                  }
                  await rtcService.setBroadcaster(true);
                  await rtcService.mute(false);
                }
              } catch (e) {
                debugPrint('LOG: Failed to toggle microphone: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Microphone Error: $e')),
                  );
                }
              }
            },
          ),
          if (kIsWeb) ...[
            const SizedBox(width: 20),
            _ControlIconButton(
              icon: isSharing ? Icons.stop_screen_share : Icons.screen_share,
              label: 'Share',
              isActive: isSharing,
              activeColor: Colors.greenAccent,
              onPressed: () async {
                if (rtcService == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('RTC Connection not ready.')),
                    );
                  }
                  return;
                }

                if (!await ensureJoined()) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Wait for room to join...')),
                    );
                  }
                  return;
                }

                debugPrint('LOG: [Web] Requesting Screen Share...');
                try {
                  await rtcService.shareSystemAudio(!isSharing);
                } catch (e) {
                  debugPrint('LOG: [Web] Screen share error/denied: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Screen share failed: ${e.toString()}'),
                        backgroundColor: Colors.orangeAccent,
                      ),
                    );
                  }
                }
              },
            ),
          ],
          const SizedBox(width: 20),
          _ControlIconButton(
            icon: Icons.logout,
            label: 'Leave',
            isActive: false,
            color: Colors.redAccent,
            onPressed: () async {
              await ref.read(roomControllerProvider(roomId).notifier).leaveRoom();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;
  final Color? color;
  final Color? activeColor;

  const _ControlIconButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
    this.color,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final effColor = isActive ? (activeColor ?? Colors.white) : (color ?? Colors.white54);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(onPressed: onPressed, icon: Icon(icon, color: effColor)),
        Text(label, style: TextStyle(fontSize: 10, color: effColor)),
      ],
    );
  }
}

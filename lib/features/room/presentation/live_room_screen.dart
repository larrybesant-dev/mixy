import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/live_room_media_controller.dart';
import '../controllers/webrtc_controller.dart';
import '../providers/message_providers.dart';
import '../repository/room_repository.dart';
import '../providers/room_live_state_provider.dart';
import 'package:mixvy/features/messaging/models/message_model.dart';
import '../providers/rtc_service_provider.dart';
import '../room_controller.dart';
import '../../../dev/room_inspector_panel.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../services/rtc_room_service.dart';

// Wide-screen cap — prevents the chat from stretching across a 1440px monitor.
const double _kMaxBodyWidth = 720;

// ─────────────────────────────────────────────────────────────────────────────
// ROOT SCREEN
// Owns the Riverpod watch and routes to one of three scaffold variants.
//
// Reconnect rule:
//   If we have a previous emission (valueOrNull != null), always show the room
//   — never go blank because of a transient stream error or refresh.
// ─────────────────────────────────────────────────────────────────────────────

class LiveRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  const LiveRoomScreen({super.key, required this.roomId});

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> {
  // Cached so lifecycle calls are safe after widget deactivation.
  late RoomController _roomController;
  late LiveRoomMediaController _mediaController;
  RtcRoomService? _rtcService;

  // "Connected to Room" one-shot banner.
  bool _connectedBannerVisible = false;
  bool _connectedShown = false;

  @override
  void initState() {
    super.initState();
    _roomController =
        ref.read(roomControllerProvider(widget.roomId).notifier);
    _mediaController = ref.read(
      liveRoomMediaControllerProvider(widget.roomId).notifier,
    );

    // ── Reactive Auto-Join ───────────────────────────────────────────────
    // Listen for the user profile to arrive. This ensures we join with the
    // correct name and prevents redundant calls if the user state changes.
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
    if (!mounted) return;
    final user = ref.read(userProvider);
    if (user == null) return;
    final mediaController = ref.read(
      liveRoomMediaControllerProvider(widget.roomId).notifier,
    );
    mediaController.beginConnecting();

    // ── 1. Firestore presence join ──────────────────────────────────────────
    await _roomController.joinRoom(
      user.id,
      displayName: user.username,
      avatarUrl: user.avatarUrl,
    );
    if (!mounted) return;

    // ── 2. RTC audio channel join ───────────────────────────────────────────
    // Web: WebRtcRoomService (Firestore signaling, no SDK download).
    // Native: AgoraService (needs real token — handled by platform flag inside
    //         createTransport).  Start muted / audience; user enables mic.
    try {
      final webrtcCtrl = ref.read(webrtcControllerProvider);
      // Fetch TURN credentials from Cloud Function so P2P works across
      // different networks and NAT types. Falls back to STUN-only on error.
      List<Map<String, dynamic>>? iceServers;
      try {
        iceServers = await ref
            .read(roomRepositoryProvider)
            .fetchIceServers();
      } catch (e) {
        // Keep RTC join alive even when TURN credential fetch fails.
        // WebRtcRoomService can still run on browser default/STUN behavior.
        developer.log(
          'TURN credential fetch failed, continuing with fallback ICE config: $e',
          name: 'LiveRoomScreen',
        );
        iceServers = null;
      }
      final service = await webrtcCtrl.createTransport(
        userId: user.id,
        iceServers: iceServers,
      );
      // appId is empty-string for WebRtcRoomService (ignored); Agora path
      // requires a real appId from Firebase Functions (not web target).
      await service.initialize('');
      await service.joinRoom(
        '',             // token — WebRtcRoomService ignores it
        widget.roomId,
        _stableUid(user.id),
        publishMicrophoneTrackOnJoin: false, // start muted; user unmutes
        publishCameraTrackOnJoin: false,
      );
      if (!mounted) {
        await service.dispose();
        return;
      }
      _rtcService = service;
      _rtcServiceNotifier.state = service;
      mediaController.markReady(
        rtcUid: _stableUid(user.id),
        cameraStatus: 'RTC connected.',
        isMicMuted: service.isLocalAudioMuted,
        isVideoEnabled: service.isLocalVideoCapturing,
      );
      // ── Show "Connected to Room" banner (once per room entry) ───────────
      if (mounted && !_connectedShown) {
        _connectedShown = true;
        setState(() => _connectedBannerVisible = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _connectedBannerVisible = false);
        });
      }
    } catch (e) {
      // RTC failure is non-fatal: Firestore presence + chat still work.
      developer.log('RTC join failed: $e', name: 'LiveRoomScreen');
      mediaController.markConnectionFailed(
        callError:
            'Live media is degraded. Chat still works, and controls will retry when media reconnects.',
        cameraStatus: 'RTC degraded',
      );
    }
  }

  /// Deterministic positive int UID from a userId string.
  /// Must be stable within a session. On Flutter Web, Dart2JS String.hashCode
  /// is deterministic; this helper makes the intent explicit.
  static int _stableUid(String userId) {
    var h = 0;
    for (final c in userId.codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    return h == 0 ? 1 : h;
  }

  @override
  void dispose() {
    // ── RTC teardown (safe: uses cached references) ─────────────────────────
    final rtcService = _rtcService;
    rtcService?.dispose().ignore();
    // Riverpod rejects provider writes during widget disposal. Defer room
    // controller cleanup to a microtask while using cached notifiers.
    scheduleMicrotask(() async {
      _mediaController.resetDisconnected();
      await _roomController.leaveRoom();
    });
    // Reset diff tracker so the next room starts with a clean baseline.
    RoomContractGuard.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(roomLiveStateProvider(widget.roomId));
    final liveState = snapshot.valueOrNull;

    // Previous data exists → show room; reconnecting banner if stream is
    // currently loading (provider refresh) or has errored (connection drop).
    if (liveState != null) {
      return _RoomScaffold(
        roomId: widget.roomId,
        roomState: liveState,
        reconnecting: snapshot.isLoading || snapshot.hasError,
        showConnectedBanner: _connectedBannerVisible,
      );
    }

    // No previous data yet — pure initial states.
    return snapshot.when(
      loading: () => _LoadingScaffold(roomId: widget.roomId),
      error: (e, _) => _ErrorScaffold(
        error: e,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      data: (_) => _LoadingScaffold(roomId: widget.roomId), // unreachable
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING SCAFFOLD
// Shown only on first load before the first stream emission arrives.
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  final String roomId;
  const _LoadingScaffold({required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Loading room…'),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR SCAFFOLD
// Shown only when the stream errors with no previous emission.
// Distinguishes schema failures (bad data) from connection failures.
// Debug mode shows the raw error detail; release shows a clean message.
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorScaffold extends StatelessWidget {
  final Object error;
  final VoidCallback onBack;
  const _ErrorScaffold({required this.error, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final isSchema = error is RoomSchemaException;
    final heading = isSchema ? 'Room data error' : 'Unable to load room';
    final icon =
        isSchema ? Icons.warning_amber_rounded : Icons.wifi_off_rounded;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: Text(heading),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  heading,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isSchema
                      ? 'This room has an unexpected data format. '
                          'Please try again or contact support.'
                      : 'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onBack,
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOM SCAFFOLD
// The live view. Width-constrained for large screens.
// Shows a reconnecting banner at the top when the stream is temporarily
// unavailable but we still have the last known state.
// ─────────────────────────────────────────────────────────────────────────────

class _RoomScaffold extends StatelessWidget {
  final String roomId;
  final RoomLiveState roomState;
  final bool reconnecting;
  final bool showConnectedBanner;

  const _RoomScaffold({
    required this.roomId,
    required this.roomState,
    required this.reconnecting,
    this.showConnectedBanner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(roomState.title.isEmpty ? 'Room' : roomState.title),
        actions: [
          // Inspector button is a no-op in release builds — gated inside
          // RoomInspectorButton by kEnableVisibilityDiagnostics.
          RoomInspectorButton(roomId: roomId),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxBodyWidth),
          child: Column(
            children: [
              // ── "Connected to Room" one-shot banner ─────────────────────
              AnimatedOpacity(
                opacity: showConnectedBanner ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: showConnectedBanner
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        color: Colors.green.shade800.withValues(alpha: 0.92),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 10,
                              color: Colors.greenAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '🟢  Connected to room',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (reconnecting) const _ReconnectingBanner(),
              Expanded(
                child: _MessageList(message: roomState.message),
              ),
              _TypingIndicator(
                typingUsers: roomState.typingUsers.keys.toList(),
              ),
              _RoomActionBar(roomId: roomId),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECONNECTING BANNER
// Shown at the top of the room when the stream is loading/erroring but we
// still have a previous state to display. Never blank, always informative.
// ─────────────────────────────────────────────────────────────────────────────

class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(cs.onErrorContainer),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Reconnecting…',
              style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// message LIST
// Shows an empty-state prompt when there are no message yet — never blank.
// ─────────────────────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  final List<MessageModel> message;
  const _MessageList({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No message yet.\nBe the first to say something!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      itemCount: message.length,
      itemBuilder: (_, i) {
        final msg = message[i];
        return ListTile(
          title: Text(msg.content),
          subtitle: Text(msg.senderId),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPING INDICATOR
// ─────────────────────────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  final List<String> typingUsers;
  const _TypingIndicator({required this.typingUsers});

  @override
  Widget build(BuildContext context) {
    if (typingUsers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        '${typingUsers.join(", ")} typing…',
        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// message INPUT
// OutlineInputBorder for clear tap target. Responds to keyboard Enter/Done.
// Controller is disposed in dispose() to prevent memory leaks.
// ─────────────────────────────────────────────────────────────────────────────

class _MessageInput extends ConsumerStatefulWidget {
  final String roomId;
  const _MessageInput({required this.roomId});

  @override
  ConsumerState<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<_MessageInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Send a message…',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(sendmessageProvider(widget.roomId))(text).catchError((_) {});
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOM ACTION BAR
// Mic and screen-share controls. Wired to RtcRoomService via rtcServiceProvider.
// Mic button is disabled until the RTC channel connects (service != null).
// Screen share remains a no-op until getDisplayMedia integration lands.
// ─────────────────────────────────────────────────────────────────────────────

class _RoomActionBar extends ConsumerStatefulWidget {
  final String roomId;
  const _RoomActionBar({required this.roomId});

  @override
  ConsumerState<_RoomActionBar> createState() => _RoomActionBarState();
}

class _RoomActionBarState extends ConsumerState<_RoomActionBar> {
  /// Ensure RTC is initialized before attempting media actions.
  /// This is the tap-time resolution entry point that guarantees RTC readiness.
  Future<void> ensureRtcInitialized() async {
    developer.log('[DEBUG-RTC] ensureRtcInitialized() called', name: 'RTC-Pipeline');
    
    final mediaController = ref.read(
      liveRoomMediaControllerProvider(widget.roomId).notifier,
    );
    final mediaState = ref.read(
      liveRoomMediaControllerProvider(widget.roomId),
    );

    developer.log('[DEBUG-RTC] Current state: ${mediaState.rtcState}', name: 'RTC-Pipeline');

    // Already ready or initializing — no need to do anything.
    if (mediaState.rtcState == RtcState.ready ||
        mediaState.rtcState == RtcState.initializing) {
      developer.log('[DEBUG-RTC] Already ready or initializing, skipping', name: 'RTC-Pipeline');
      return;
    }

    // Mark as initializing
    developer.log('[DEBUG-RTC] Setting state to initializing', name: 'RTC-Pipeline');
    mediaController.setRtcState(RtcState.initializing);

    try {
      // Wait for the RTC service to become available (up to 10s)
      var attempts = 0;
      final maxAttempts = 20; // 20 × 500ms = 10s
      while (ref.read(rtcServiceProvider(widget.roomId)) == null &&
          attempts < maxAttempts) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      final service = ref.read(rtcServiceProvider(widget.roomId));
      if (service != null) {
        developer.log('[DEBUG-RTC] Service available after $attempts attempts, marking ready', name: 'RTC-Pipeline');
        mediaController.markRtcReady();
      } else {
        developer.log('[DEBUG-RTC] Service NOT available after $attempts attempts, marking degraded', name: 'RTC-Pipeline');
        mediaController.markRtcDegraded();
      }
    } catch (e) {
      developer.log(
        '[DEBUG-RTC] ensureRtcInitialized failed: $e',
        name: 'RTC-Pipeline',
      );
      mediaController.markRtcDegraded();
    }
  }

  Future<void> _toggleMic() async {
    developer.log('[DEBUG-BUTTON] Mic button tapped', name: 'RTC-Pipeline');
    
    await ensureRtcInitialized();

    final mediaState = ref.read(
      liveRoomMediaControllerProvider(widget.roomId),
    );

    developer.log('[DEBUG-BUTTON] After ensureRtcInitialized: rtcState=${mediaState.rtcState}', name: 'RTC-Pipeline');

    // If RTC failed, we cannot proceed
    if (mediaState.rtcState == RtcState.failed) {
      developer.log(
        '[DEBUG-BUTTON] RTC failed — cannot proceed',
        name: 'RTC-Pipeline',
      );
      return;
    }

    final service = ref.read(rtcServiceProvider(widget.roomId));
    if (service == null) {
      developer.log(
        '[DEBUG-BUTTON] RTC service not available',
        name: 'RTC-Pipeline',
      );
      return;
    }

    developer.log('[DEBUG-BUTTON] Service available, proceeding with mic toggle', name: 'RTC-Pipeline');

    final mediaController = ref.read(
      liveRoomMediaControllerProvider(widget.roomId).notifier,
    );
    final isCurrentlyMuted = service.isLocalAudioMuted;

    mediaController.beginMicAction();

    if (isCurrentlyMuted) {
      try {
        developer.log('[DEBUG-BUTTON] Enabling mic', name: 'RTC-Pipeline');
        await service.setBroadcaster(true);
        await service.mute(false);
        mediaController.finishMicAction(isMuted: service.isLocalAudioMuted);
        developer.log('[DEBUG-BUTTON] Mic enabled successfully', name: 'RTC-Pipeline');
      } catch (e) {
        developer.log('[DEBUG-BUTTON] Mic enable failed — $e', name: 'RTC-Pipeline');
        mediaController.endMicAction();
        mediaController.markRtcDegraded();
      }
    } else {
      try {
        developer.log('[DEBUG-BUTTON] Disabling mic', name: 'RTC-Pipeline');
        await service.mute(true);
        await service.setBroadcaster(false);
        mediaController.finishMicAction(isMuted: service.isLocalAudioMuted);
        developer.log('[DEBUG-BUTTON] Mic disabled successfully', name: 'RTC-Pipeline');
      } catch (e) {
        developer.log('[DEBUG-BUTTON] Mic disable failed — $e', name: 'RTC-Pipeline');
        mediaController.endMicAction();
        mediaController.markRtcDegraded();
      }
    }
  }

  Future<void> _toggleSystemAudio() async {
    developer.log('[DEBUG-BUTTON] Screen share button tapped', name: 'RTC-Pipeline');
    
    await ensureRtcInitialized();

    final mediaState = ref.read(
      liveRoomMediaControllerProvider(widget.roomId),
    );

    developer.log('[DEBUG-BUTTON] After ensureRtcInitialized: rtcState=${mediaState.rtcState}', name: 'RTC-Pipeline');

    if (mediaState.rtcState == RtcState.failed) {
      developer.log('[DEBUG-BUTTON] RTC failed, cannot share', name: 'RTC-Pipeline');
      return;
    }

    final service = ref.read(rtcServiceProvider(widget.roomId));
    final mediaController = ref.read(
      liveRoomMediaControllerProvider(widget.roomId).notifier,
    );

    if (service == null || !kIsWeb || mediaState.isSystemAudioActionInFlight) {
      developer.log('[DEBUG-BUTTON] Cannot proceed: service=$service, kIsWeb=$kIsWeb, inFlight=${mediaState.isSystemAudioActionInFlight}', name: 'RTC-Pipeline');
      return;
    }

    final target = !service.isSharingSystemAudio;
    developer.log('[DEBUG-BUTTON] Toggling system audio to: $target', name: 'RTC-Pipeline');
    
    mediaController.beginSystemAudioAction();
    try {
      await service.shareSystemAudio(target);
      developer.log('[DEBUG-BUTTON] System audio toggled successfully', name: 'RTC-Pipeline');
      mediaController.finishSystemAudioAction(
        isSharing: service.isSharingSystemAudio,
      );
    } catch (e) {
      developer.log(
        '[DEBUG-BUTTON] System audio toggle failed — $e',
        name: 'RTC-Pipeline',
      );
      mediaController.endSystemAudioAction();
      mediaController.markRtcDegraded();
    }
  }

  Future<void> _stopScreenShare() async {
    await ensureRtcInitialized();

    final mediaState = ref.read(
      liveRoomMediaControllerProvider(widget.roomId),
    );

    if (mediaState.rtcState == RtcState.failed) {
      return;
    }

    final service = ref.read(rtcServiceProvider(widget.roomId));
    final mediaController = ref.read(
      liveRoomMediaControllerProvider(widget.roomId).notifier,
    );
    if (service == null) return;
    mediaController.beginSystemAudioAction();
    try {
      await service.shareSystemAudio(false);
      mediaController.finishSystemAudioAction(
        isSharing: service.isSharingSystemAudio,
      );
    } catch (e) {
      developer.log('_stopScreenShare failed — $e', name: 'LiveRoomScreen');
      mediaController.endSystemAudioAction();
      mediaController.markRtcDegraded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final service = ref.watch(rtcServiceProvider(widget.roomId));
    final mediaState = ref.watch(liveRoomMediaControllerProvider(widget.roomId));
    
    // Get actual media state from service if available, otherwise use defaults
    final sharingAudio = service?.isSharingSystemAudio ?? false;
    final micActive = service != null ? !service.isLocalAudioMuted : false;
    final micActionInFlight = mediaState.isMicActionInFlight;
    final systemAudioActionInFlight = mediaState.isSystemAudioActionInFlight;
    
    // Buttons are ALWAYS enabled now — they resolve at tap-time via ensureRtcInitialized()
    // No more silent disabling based on hasRtcService
    final micButtonEnabled = !micActionInFlight;

    final statusLabel = mediaState.rtcState == RtcState.initializing
        ? 'Connecting audio…'
        : mediaState.rtcState == RtcState.degraded
        ? 'Limited connection'
        : mediaState.rtcState == RtcState.failed
        ? 'RTC failed'
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            // ── Mic ──────────────────────────────────────────────────────
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                micActionInFlight
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: cs.primary,
                          ),
                        ),
                      )
                    : IconButton.filledTonal(
                        tooltip: micActive ? 'Mute mic' : 'Unmute mic',
                        onPressed: micButtonEnabled ? () => _toggleMic() : null,
                        style: micButtonEnabled && micActive
                            ? IconButton.styleFrom(
                                backgroundColor: cs.error,
                                foregroundColor: cs.onError,
                              )
                            : micButtonEnabled && !micActive
                                ? IconButton.styleFrom(
                                    backgroundColor: cs.errorContainer,
                                    foregroundColor: cs.onErrorContainer,
                                  )
                                : null,
                        icon: Icon(
                          micActive
                              ? Icons.mic_rounded
                              : Icons.mic_off_rounded,
                        ),
                      ),
                Text(
                  micActionInFlight
                      ? 'Connecting…'
                      : micActive
                          ? 'You are speaking'
                          : 'Muted',
                  style: TextStyle(
                    fontSize: 10,
                    color: micActive ? cs.error : cs.onSurfaceVariant,
                    fontWeight: micActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            // ── Audio share (always enabled on web, resolves at tap-time) ────
            if (kIsWeb)
              IconButton.filledTonal(
                tooltip: sharingAudio ? 'Stop audio share' : 'Share audio',
                onPressed: systemAudioActionInFlight
                    ? null
                    : () async {
                        if (sharingAudio) {
                          await _stopScreenShare();
                        } else {
                          await _toggleSystemAudio();
                        }
                      },
                style: sharingAudio
                    ? IconButton.styleFrom(
                        backgroundColor: cs.primaryContainer,
                        foregroundColor: cs.onPrimaryContainer,
                      )
                    : null,
                icon: Icon(
                  sharingAudio
                      ? Icons.graphic_eq
                      : Icons.screen_share_outlined,
                ),
              ),
            if (statusLabel != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    // Show RTC state for debugging
                    Text(
                      '[RTC: ${mediaState.rtcState.toString().split('.').last}]',
                      style: TextStyle(
                        fontSize: 9,
                        color: cs.outline,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

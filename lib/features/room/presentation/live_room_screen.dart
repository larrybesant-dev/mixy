import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/utils/network_image_url.dart';
import 'package:mixvy/config/agora_constants.dart';

import '../../../core/services/feature_gate_service.dart';
import '../../../models/room_model.dart';
import '../../feed/providers/user_providers.dart' as feed_user;
import '../controllers/live_room_media_controller.dart';
import '../controllers/webrtc_controller.dart';
import '../providers/message_providers.dart';
import '../providers/room_render_selectors.dart';
import '../repository/room_repository.dart';
import '../providers/room_live_state_provider.dart';
import 'package:mixvy/features/messaging/models/message_model.dart';
import '../providers/rtc_service_provider.dart';
import '../room_controller.dart';
import '../widgets/message_bubble.dart';
import '../../../dev/room_inspector_panel.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../services/rtc_room_service.dart';
import '../../../shared/widgets/guest_auth_gate.dart';

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
  final RoomModel? previewRoom;

  const LiveRoomScreen({super.key, required this.roomId, this.previewRoom});

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
    _roomController = ref.read(roomControllerProvider(widget.roomId).notifier);
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
    final joinResult = await _roomController.joinRoom(
      user.id,
      displayName: user.username,
      avatarUrl: user.avatarUrl,
    );
    if (!mounted) return;
    if (!joinResult.isSuccess) {
      final reason =
          joinResult.errormessage ?? 'Room joining is temporarily unavailable.';
      developer.log(
        '[CONTROL_GATE] room_join_denied roomId=${widget.roomId} userId=${user.id} reason=$reason',
        name: 'LiveRoomScreen',
      );
      mediaController.markConnectionFailed(
        callError: reason,
        cameraStatus: 'Join blocked',
      );
      return;
    }

    var liveRoomsEnabled = true;
    try {
      liveRoomsEnabled = ref
          .read(featureGateControllerProvider)
          .enableLiveRooms;
    } on AssertionError {
      liveRoomsEnabled = true;
    }
    if (!liveRoomsEnabled) {
      developer.log(
        '[CONTROL_GATE] room_rtc_init_blocked roomId=${widget.roomId} userId=${user.id} reason=live_rooms_disabled',
        name: 'LiveRoomScreen',
      );
      mediaController.markConnectionFailed(
        callError: 'Live rooms are temporarily paused for maintenance.',
        cameraStatus: 'Join blocked',
      );
      return;
    }

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
        iceServers = await ref.read(roomRepositoryProvider).fetchIceServers();
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
      final resolvedAgoraAppId = AgoraConstants.appId.trim();
      // WebRtcRoomService ignores appId while Agora requires a real one.
      await service.initialize(resolvedAgoraAppId);
      await service.joinRoom(
        '', // token — WebRtcRoomService ignores it
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
      ref.read(rtcServiceProvider(widget.roomId).notifier).state = service;
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
    int h = 0;
    for (final c in userId.codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    return h == 0 ? 1 : h;
  }

  @override
  void dispose() {
    // ── RTC teardown (safe: uses cached references) ─────────────────────────
    final rtcService = _rtcService;
    rtcService?.dispose().catchError((Object e, StackTrace st) {
      // Log but do not rethrow — dispose must complete even if RTC cleanup
      // fails (e.g. RTCPeerConnection.close() throws on Flutter Web).
      developer.log(
        'RTC dispose failed: $e',
        name: 'LiveRoomScreen',
        error: e,
        stackTrace: st,
      );
    });
    // Riverpod rejects provider writes during widget disposal. Defer room
    // controller cleanup to a microtask while using cached notifiers.
    scheduleMicrotask(() {
      _mediaController.resetDisconnected();
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
      loading: () => _LoadingScaffold(
        roomId: widget.roomId,
        previewRoom: widget.previewRoom,
      ),
      error: (e, _) => _ErrorScaffold(
        error: e,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      data: (_) => _LoadingScaffold(
        roomId: widget.roomId,
        previewRoom: widget.previewRoom,
      ), // unreachable
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING SCAFFOLD
// Shown only on first load before the first stream emission arrives.
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingScaffold extends ConsumerWidget {
  final String roomId;
  final RoomModel? previewRoom;

  const _LoadingScaffold({required this.roomId, this.previewRoom});

  String _identityLabel(RoomModel? room) {
    final category = room?.category?.trim().toLowerCase();
    switch (category) {
      case 'music':
        return 'Music';
      case 'gaming':
        return 'Gaming';
      case 'dating':
        return 'Flirty';
      case 'talk':
        return 'Late Night';
      case 'tech':
        return 'Tech';
      case 'art':
        return 'Creative';
      case 'dance':
        return 'Dance';
    }
    if (room != null && room.tags.isNotEmpty) {
      final firstTag = room.tags.first.trim();
      if (firstTag.isNotEmpty) return firstTag;
    }
    return 'Live Room';
  }

  String _relativeSince(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'live since just now';
    if (diff.inMinutes < 60) return 'live since ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'live since ${diff.inHours}h ago';
    return 'live now';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = previewRoom?.name.trim().isNotEmpty == true
        ? previewRoom!.name.trim()
        : 'Joining room';
    final identity = _identityLabel(previewRoom);
    final shortRoomId = roomId.length > 8 ? roomId.substring(0, 8) : roomId;
    final hostId = previewRoom?.hostId;
    final hostAsync = hostId == null || hostId.isEmpty
        ? const AsyncValue.data(null)
        : ref.watch(feed_user.userProvider(hostId));

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(previewRoom == null ? 'Joining room' : title),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxBodyWidth),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _LoadingChip(
                        label: 'Connecting',
                        icon: Icons.graphic_eq_rounded,
                        color: colorScheme.primary,
                      ),
                      _LoadingChip(
                        label: identity,
                        icon: Icons.local_fire_department_rounded,
                        color: colorScheme.secondary,
                      ),
                      _LoadingChip(
                        label: 'Room $shortRoomId',
                        icon: Icons.meeting_room_rounded,
                        color: colorScheme.tertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stage, audience, and chat are loading so the room feels present before stream hydration finishes.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: hostAsync.when(
                      data: (host) {
                        final hostName =
                            host?.username.trim().isNotEmpty == true
                            ? host!.username.trim()
                            : 'Host';
                        final hostAvatar = host?.avatarUrl;
                        return Row(
                          children: [
                            _LoadingHostAvatar(
                              imageUrl: hostAvatar,
                              fallbackColor: colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hostName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _relativeSince(
                                      previewRoom?.createdAt?.toDate(),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => Row(
                        children: [
                          _LoadingHostAvatar(
                            fallbackColor: colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              _LoadingBar(width: 120, height: 12),
                              SizedBox(height: 6),
                              _LoadingBar(width: 90, height: 10),
                            ],
                          ),
                        ],
                      ),
                      error: (_, _) => Row(
                        children: [
                          _LoadingHostAvatar(
                            fallbackColor: colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Host',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.42,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _LoadingAvatar(color: colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _LoadingBar(
                                  width: double.infinity,
                                  height: 14,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _LoadingBar(width: 220, height: 22),
                          const SizedBox(height: 10),
                          _LoadingBar(width: 168, height: 12),
                          const SizedBox(height: 22),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: List.generate(
                                      3,
                                      (_) => const Padding(
                                        padding: EdgeInsets.only(bottom: 12),
                                        child: _LoadingSeat(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    children: List.generate(
                                      3,
                                      (_) => const Padding(
                                        padding: EdgeInsets.only(bottom: 12),
                                        child: _LoadingSeat(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: const [
                              Expanded(
                                child: _LoadingControl(
                                  icon: Icons.mic_off_rounded,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _LoadingControl(
                                  icon: Icons.chat_bubble_outline_rounded,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _LoadingControl(
                                  icon: Icons.people_outline_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingChip extends StatelessWidget {
  const _LoadingChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

class _LoadingAvatar extends StatelessWidget {
  const _LoadingAvatar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
    );
  }
}

class _LoadingHostAvatar extends StatelessWidget {
  const _LoadingHostAvatar({this.imageUrl, required this.fallbackColor});

  final String? imageUrl;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final sanitized = sanitizeNetworkImageUrl(imageUrl);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fallbackColor.withValues(alpha: 0.18),
        border: Border.all(color: fallbackColor.withValues(alpha: 0.26)),
      ),
      child: ClipOval(
        child: sanitized == null
            ? const SizedBox.shrink()
            : Image.network(
                sanitized,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
      ),
    );
  }
}

class _LoadingSeat extends StatelessWidget {
  const _LoadingSeat();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _LoadingControl extends StatelessWidget {
  const _LoadingControl({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Icon(icon, color: colorScheme.onSurfaceVariant),
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
    final icon = isSchema
        ? Icons.warning_amber_rounded
        : Icons.wifi_off_rounded;

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
                FilledButton(onPressed: onBack, child: const Text('Go back')),
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
                    ? _JoinedRoomBanner(
                        title: roomState.title.isEmpty
                            ? 'the room'
                            : roomState.title,
                      )
                    : const SizedBox.shrink(),
              ),
              if (reconnecting) const _ReconnectingBanner(),
              Expanded(child: _MessageList(roomId: roomId)),
              _TypingIndicator(roomId: roomId),
              _FirstThirtySecondsCoach(
                key: ValueKey('coach-$roomId'),
                roomId: roomId,
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

class _JoinedRoomBanner extends StatelessWidget {
  const _JoinedRoomBanner({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade800.withValues(alpha: 0.94),
            colorScheme.primary.withValues(alpha: 0.78),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You joined $title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Audio and chat are live. You are inside now.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// message LIST
// Shows an empty-state prompt when there are no message yet — never blank.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// message LIST
// Shows an empty-state prompt when there are no message yet — never blank.
// Watches messagetreamProvider directly so it only rebuilds on message
// changes, not on typing or presence events.
// ─────────────────────────────────────────────────────────────────────────────

class _MessageList extends ConsumerWidget {
  final String roomId;
  const _MessageList({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message =
        ref.watch(roomMessageStreamProvider(roomId)).valueOrNull ??
        const <MessageModel>[];

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

    final currentUserId = ref.watch(userProvider)?.id;

    return ListView.builder(
      itemCount: message.length,
      itemBuilder: (_, i) {
        final msg = message[i];
        return MessageBubble(message: msg, isMe: msg.senderId == currentUserId);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPING INDICATOR
// Watches the existing roomTypingUserIdsProvider (StreamProvider<List<String>>)
// so it only rebuilds when the set of actively-typing users changes, not on
// message or participant events.
// ─────────────────────────────────────────────────────────────────────────────

class _TypingIndicator extends ConsumerWidget {
  final String roomId;
  const _TypingIndicator({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typingIds =
        ref.watch(roomTypingUserIdsProvider(roomId)).valueOrNull ?? const [];
    if (typingIds.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        '${typingIds.join(', ')} typing…',
        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
      ),
    );
  }
}

enum _CoachActivityProfile { low, medium, high }

enum _RoomMood { calm, social, chaotic, intimate }

class _FirstThirtySecondsCoach extends ConsumerStatefulWidget {
  const _FirstThirtySecondsCoach({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<_FirstThirtySecondsCoach> createState() =>
      _FirstThirtySecondsCoachState();
}

class _FirstThirtySecondsCoachState
    extends ConsumerState<_FirstThirtySecondsCoach> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  late double _smoothedActivityScore;
  late _CoachActivityProfile _profile;
  late _RoomMood _stableMood;
  _RoomMood? _moodCandidate;
  int _moodCandidateSeconds = 0;

  // Latest metrics from the provider — updated each build before the timer
  // reads them. Safe to assign without setState because the timer calls
  // setState itself on every tick.
  RoomCoachMetrics _metrics = const RoomCoachMetrics.empty();

  static const double _smoothingAlpha = 0.28;
  static const int _moodMinHoldSeconds = 6;

  @override
  void initState() {
    super.initState();
    _smoothedActivityScore = _instantActivityScore();
    _profile = _resolveProfile(_smoothedActivityScore, current: null);
    _stableMood = _instantMood();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        final instant = _instantActivityScore();
        _smoothedActivityScore =
            (_smoothedActivityScore * (1 - _smoothingAlpha)) +
            (instant * _smoothingAlpha);
        _profile = _resolveProfile(_smoothedActivityScore, current: _profile);
        _applyMoodInertia(_instantMood());
      });
      if (_elapsedSeconds >= _maxWindowSeconds) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double _instantActivityScore() {
    final participants = _metrics.participantCount.clamp(0, 30).toDouble();
    final messages = _metrics.messageCount.clamp(0, 20).toDouble();
    final typing = _metrics.typingCount.clamp(0, 6).toDouble();
    final onMic = _metrics.onMicCount.clamp(0, 8).toDouble();

    // Host influence should anchor the early room tone, then hand off to
    // crowd dynamics as session evidence accumulates.
    final hostInfluenceScale = _elapsedSeconds <= 24
        ? (1.6 - ((_elapsedSeconds / 24) * 0.6))
        : 1.0;
    final hostBonus = _metrics.hostActive ? hostInfluenceScale : 0.0;

    // Weighted signal: typing implies immediacy, messages imply motion,
    // participants imply density, host/on-mic imply conversational gravity.
    return (participants * 0.35) +
        (messages * 0.5) +
        (typing * 1.8) +
        (onMic * 0.7) +
        hostBonus;
  }

  _RoomMood _instantMood() {
    if (_isHighActivity && _metrics.onMicCount >= 3) {
      return _RoomMood.chaotic;
    }
    if (_isLowActivity && _metrics.participantCount <= 3) {
      return _RoomMood.intimate;
    }
    if (_metrics.hostActive ||
        _metrics.typingCount > 0 ||
        _metrics.messageCount >= 2) {
      return _RoomMood.social;
    }
    return _RoomMood.calm;
  }

  void _applyMoodInertia(_RoomMood next) {
    if (next == _stableMood) {
      _moodCandidate = null;
      _moodCandidateSeconds = 0;
      return;
    }

    // Avoid early flip-flops while users are still orienting.
    if (_elapsedSeconds < _moodMinHoldSeconds) {
      return;
    }

    if (_moodCandidate != next) {
      _moodCandidate = next;
      _moodCandidateSeconds = 1;
      return;
    }

    _moodCandidateSeconds++;

    // Chaotic <-> non-chaotic transitions need stronger evidence.
    final requiredSeconds =
        (_stableMood == _RoomMood.chaotic || next == _RoomMood.chaotic) ? 5 : 3;

    if (_moodCandidateSeconds >= requiredSeconds) {
      _stableMood = next;
      _moodCandidate = null;
      _moodCandidateSeconds = 0;
    }
  }

  _CoachActivityProfile _resolveProfile(
    double score, {
    required _CoachActivityProfile? current,
  }) {
    // Hysteresis prevents noisy state-flips around thresholds.
    if (current == _CoachActivityProfile.high) {
      if (score >= 4.2) return _CoachActivityProfile.high;
      if (score <= 2.4) return _CoachActivityProfile.low;
      return _CoachActivityProfile.medium;
    }
    if (current == _CoachActivityProfile.low) {
      if (score <= 2.8) return _CoachActivityProfile.low;
      if (score >= 5.0) return _CoachActivityProfile.high;
      return _CoachActivityProfile.medium;
    }

    if (score >= 5.0) return _CoachActivityProfile.high;
    if (score <= 2.4) return _CoachActivityProfile.low;
    return _CoachActivityProfile.medium;
  }

  bool get _isHighActivity => _profile == _CoachActivityProfile.high;

  bool get _isLowActivity => _profile == _CoachActivityProfile.low;

  int get _maxWindowSeconds {
    if (_isHighActivity) return 18;
    if (_isLowActivity) return 36;
    return 30;
  }

  _RoomMood get _mood => _stableMood;

  String _icebreakerSuggestion() {
    switch (_mood) {
      case _RoomMood.intimate:
        return 'Try: "hey, mind if I join in?"';
      case _RoomMood.social:
        return 'Try: "what are we talking about right now?"';
      case _RoomMood.chaotic:
        return 'Try: "quick take: I agree with that point."';
      case _RoomMood.calm:
        return 'Try: "hey everyone, how is your night going?"';
    }
  }

  String _retentionFrame() {
    final title = _metrics.roomTitle.trim();
    switch (_mood) {
      case _RoomMood.chaotic:
        return 'Fast room right now. Catch one full exchange before switching.';
      case _RoomMood.intimate:
        return 'This room is intimate. A short hello can shift the vibe.';
      case _RoomMood.social:
        if (title.isNotEmpty) {
          return 'If this vibe fits, stay in $title for one full round.';
        }
        return 'If this vibe fits, stay for one full round.';
      case _RoomMood.calm:
        return 'Calm room. Stay a minute and let the rhythm build.';
    }
  }

  String? _messageForElapsed() {
    final maxWindow = _maxWindowSeconds;
    if (_elapsedSeconds < 3 || _elapsedSeconds >= maxWindow) {
      return null;
    }

    if (_elapsedSeconds < 10) {
      return 'Take 5 seconds to listen first, then tap mic when you are ready.';
    }

    // In active rooms, avoid over-guiding once flow is already obvious.
    if (_isHighActivity) {
      if (_mood == _RoomMood.chaotic) {
        return 'Fast room now. Jump in between turns for best timing.';
      }
      return 'Room is active now. Add one short thought when the timing feels right.';
    }

    if (_elapsedSeconds < 20) {
      if (_isLowActivity) {
        return _icebreakerSuggestion();
      }
      if (_mood == _RoomMood.social) {
        return _icebreakerSuggestion();
      }
      return 'Drop one short chat line to signal your presence.';
    }

    return _retentionFrame();
  }

  @override
  Widget build(BuildContext context) {
    // Update cached metrics before the timer reads them. This is a plain field
    // assignment — no setState needed; the timer drives rebuilds on its own
    // 1-second cadence. Provider equality (RoomCoachMetrics.operator==)
    // ensures we only enter build() when the numbers actually changed.
    _metrics = ref.watch(roomCoachMetricsProvider(widget.roomId));

    final maxWindow = _maxWindowSeconds;
    if (_elapsedSeconds >= maxWindow) {
      return const SizedBox.shrink();
    }

    final message = _messageForElapsed();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visible = message != null;
    return SizedBox(
      height: 52,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: visible ? 1 : 0,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.send), onPressed: _send),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final allowed = await GuestAuthGate.requireMessaging(context, ref);
    if (!allowed) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    unawaited(
      ref.read(sendMessageProvider(widget.roomId))(text).catchError((_) {}),
    );
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
    developer.log(
      '[DEBUG-RTC] ensureRtcInitialized() called',
      name: 'RTC-Pipeline',
    );

    final mediaController = ref.read(
      liveRoomMediaControllerProvider(widget.roomId).notifier,
    );
    final mediaState = ref.read(liveRoomMediaControllerProvider(widget.roomId));

    developer.log(
      '[DEBUG-RTC] Current state: ${mediaState.rtcState}',
      name: 'RTC-Pipeline',
    );

    // Already ready or initializing — no need to do anything.
    if (mediaState.rtcState == RtcState.ready ||
        mediaState.rtcState == RtcState.initializing) {
      developer.log(
        '[DEBUG-RTC] Already ready or initializing, skipping',
        name: 'RTC-Pipeline',
      );
      return;
    }

    // Mark as initializing
    developer.log(
      '[DEBUG-RTC] Setting state to initializing',
      name: 'RTC-Pipeline',
    );
    mediaController.setRtcState(RtcState.initializing);

    try {
      // Wait for the RTC service to become available (up to 10s)
      int attempts = 0;
      final maxAttempts = 20; // 20 × 500ms = 10s
      while (ref.read(rtcServiceProvider(widget.roomId)) == null &&
          attempts < maxAttempts) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      final service = ref.read(rtcServiceProvider(widget.roomId));
      if (service != null) {
        developer.log(
          '[DEBUG-RTC] Service available after $attempts attempts, marking ready',
          name: 'RTC-Pipeline',
        );
        mediaController.markRtcReady();
      } else {
        developer.log(
          '[DEBUG-RTC] Service NOT available after $attempts attempts, marking degraded',
          name: 'RTC-Pipeline',
        );
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

    final mediaState = ref.read(liveRoomMediaControllerProvider(widget.roomId));

    developer.log(
      '[DEBUG-BUTTON] After ensureRtcInitialized: rtcState=${mediaState.rtcState}',
      name: 'RTC-Pipeline',
    );

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

    developer.log(
      '[DEBUG-BUTTON] Service available, proceeding with mic toggle',
      name: 'RTC-Pipeline',
    );

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
        developer.log(
          '[DEBUG-BUTTON] Mic enabled successfully',
          name: 'RTC-Pipeline',
        );
      } catch (e) {
        developer.log(
          '[DEBUG-BUTTON] Mic enable failed — $e',
          name: 'RTC-Pipeline',
        );
        mediaController.endMicAction();
        mediaController.markRtcDegraded();
      }
    } else {
      try {
        developer.log('[DEBUG-BUTTON] Disabling mic', name: 'RTC-Pipeline');
        await service.mute(true);
        await service.setBroadcaster(false);
        mediaController.finishMicAction(isMuted: service.isLocalAudioMuted);
        developer.log(
          '[DEBUG-BUTTON] Mic disabled successfully',
          name: 'RTC-Pipeline',
        );
      } catch (e) {
        developer.log(
          '[DEBUG-BUTTON] Mic disable failed — $e',
          name: 'RTC-Pipeline',
        );
        mediaController.endMicAction();
        mediaController.markRtcDegraded();
      }
    }
  }

  Future<void> _toggleSystemAudio() async {
    developer.log(
      '[DEBUG-BUTTON] Screen share button tapped',
      name: 'RTC-Pipeline',
    );

    await ensureRtcInitialized();

    final mediaState = ref.read(liveRoomMediaControllerProvider(widget.roomId));

    developer.log(
      '[DEBUG-BUTTON] After ensureRtcInitialized: rtcState=${mediaState.rtcState}',
      name: 'RTC-Pipeline',
    );

    if (mediaState.rtcState == RtcState.failed) {
      developer.log(
        '[DEBUG-BUTTON] RTC failed, cannot share',
        name: 'RTC-Pipeline',
      );
      return;
    }

    final service = ref.read(rtcServiceProvider(widget.roomId));
    final mediaController = ref.read(
      liveRoomMediaControllerProvider(widget.roomId).notifier,
    );

    if (service == null || !kIsWeb || mediaState.isSystemAudioActionInFlight) {
      developer.log(
        '[DEBUG-BUTTON] Cannot proceed: service=$service, kIsWeb=$kIsWeb, inFlight=${mediaState.isSystemAudioActionInFlight}',
        name: 'RTC-Pipeline',
      );
      return;
    }

    final target = !service.isSharingSystemAudio;
    developer.log(
      '[DEBUG-BUTTON] Toggling system audio to: $target',
      name: 'RTC-Pipeline',
    );

    mediaController.beginSystemAudioAction();
    try {
      await service.shareSystemAudio(target);
      developer.log(
        '[DEBUG-BUTTON] System audio toggled successfully',
        name: 'RTC-Pipeline',
      );
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

    final mediaState = ref.read(liveRoomMediaControllerProvider(widget.roomId));

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
    final mediaState = ref.watch(
      liveRoomMediaControllerProvider(widget.roomId),
    );

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
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
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
                          micActive ? Icons.mic_rounded : Icons.mic_off_rounded,
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
                  sharingAudio ? Icons.graphic_eq : Icons.screen_share_outlined,
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

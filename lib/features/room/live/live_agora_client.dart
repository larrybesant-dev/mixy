// lib/features/room/live/live_agora_client.dart
//
// Smart video engine client for the cost-optimized multi-user video room
// architecture.
//
// Key rules enforced here:
//   • Never auto-subscribe to all streams — only visible tiles.
//   • Drop ALL subscriptions and publishing when the app is backgrounded.
//   • Only publish video when: foregrounded + cam on + ≥1 subscriber.
//   • Low-bitrate encoder profiles for group rooms (240p/360p, 15 FPS).
//   • Downgrade to audience client role when not publishing (saves bandwidth).
//   • All subscription changes flow through setVisibleUids().
// ───────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants.dart';
import '../../../services/agora/agora_platform_service.dart';
import 'live_room_schema.dart';

// ── Events emitted to the controller ──────────────────────────────────────

sealed class VideoEngineEvent {
  const VideoEngineEvent();
}

final class EngineJoinedEvent extends VideoEngineEvent {
  final int localUid;
  const EngineJoinedEvent(this.localUid);
}

final class EngineLeftEvent extends VideoEngineEvent {
  const EngineLeftEvent();
}

final class RemoteUserJoinedEvent extends VideoEngineEvent {
  final int remoteUid;
  const RemoteUserJoinedEvent(this.remoteUid);
}

final class RemoteUserLeftEvent extends VideoEngineEvent {
  final int remoteUid;
  const RemoteUserLeftEvent(this.remoteUid);
}

final class RemoteVideoToggleEvent extends VideoEngineEvent {
  final int remoteUid;
  final bool hasVideo;
  const RemoteVideoToggleEvent(this.remoteUid, this.hasVideo);
}

final class ActiveSpeakerEvent extends VideoEngineEvent {
  final int? speakerUid;
  const ActiveSpeakerEvent(this.speakerUid);
}

final class EngineErrorEvent extends VideoEngineEvent {
  final String message;
  const EngineErrorEvent(this.message);
}

// ── Client ─────────────────────────────────────────────────────────────────

class LiveAgoraClient {
  LiveAgoraClient({required this.roomType});

  final String roomType;

  // ── State ─────────────────────────────────────────────────────────────────
  RtcEngine? _engine;
  bool _initialized = false;
  bool _inChannel = false;
  String? _channelId;
  String? _lastUserId;
  int? _localUid;
  bool _publishingVideo = false;
  bool _publishingAudio = false;
  Timer? _tokenRefreshTimer;

  /// Uids currently in the video channel (not necessarily subscribed).
  final Set<int> _channelUids = {};

  /// Uids we are actively receiving video from.
  final Set<int> _subscribedUids = {};

  /// Hard cap: subscribe to at most this many tiles simultaneously.
  static const int _maxTileSubscriptions = 8;

  final _events = StreamController<VideoEngineEvent>.broadcast();

  // ── Public getters ────────────────────────────────────────────────────────

  Stream<VideoEngineEvent> get events => _events.stream;
  bool get isInitialized => _initialized;
  bool get isInChannel => _inChannel;
  int? get localUid => _localUid;
  String? get channelId => _channelId;
  Set<int> get channelUids => Set.unmodifiable(_channelUids);
  Set<int> get subscribedUids => Set.unmodifiable(_subscribedUids);

  /// Exposes the underlying engine for video rendering widgets.
  RtcEngine? get engine => kIsWeb ? null : _engine;

  // ── Initialize ────────────────────────────────────────────────────────────

  /// Loads App ID from Firestore, initialises native engine and encoder config.
  /// Returns the Agora App ID for reference.
  Future<String> initialize() async {
    if (_initialized) return _loadAppId();

    final appId = await _loadAppId();

    if (!kIsWeb) {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      // Low-bitrate video encoder profile for group rooms
      await _engine!.setVideoEncoderConfiguration(
        VideoEncoderConfiguration(
          dimensions: _dimensions(),
          frameRate: 15,
          bitrate: _bitrate(),
          orientationMode: OrientationMode.orientationModeAdaptive,
          degradationPreference: DegradationPreference.maintainFramerate,
        ),
      );

      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
      );

      // Speaking detection — 500 ms interval
      await _engine!.enableAudioVolumeIndication(
        interval: 500,
        smooth: 3,
        reportVad: false,
      );

      _registerEventHandlers();
    }

    _initialized = true;
    return appId;
  }

  // ── Join channel ──────────────────────────────────────────────────────────

  Future<void> joinChannel({
    required String channelId,
    required String userId,
    required bool isBroadcaster,
  }) async {
    if (!_initialized) throw StateError('Call initialize() first.');
    if (_inChannel) return;

    final token = await _fetchToken(channelId: channelId, userId: userId);
    _channelId = channelId;
    _lastUserId = userId;

    if (kIsWeb) {
      // Web path: join via AgoraPlatformService (web bridge v3)
      debugPrint('[VIDEO_ENGINE] Web join — using AgoraPlatformService / web bridge');
      final appId = await _loadAppId();
      final success = await AgoraPlatformService.joinChannel(
        appId: appId,
        channelName: channelId,
        token: token,
        uid: '0',
      );
      if (!success) {
        _emit(const EngineErrorEvent('Web bridge join failed'));
        return;
      }
      _inChannel = true;
      _emit(const EngineJoinedEvent(0));
      _startTokenRefreshTimer(channelId: channelId, userId: userId);
      return;
    }

    final role = isBroadcaster
        ? ClientRoleType.clientRoleBroadcaster
        : ClientRoleType.clientRoleAudience;

    await _engine!.setClientRole(role: role);

    // Start with local media disabled — only enable on explicit request
    await _engine!.enableLocalVideo(false);
    await _engine!.enableLocalAudio(false);

    await _engine!.joinChannel(
      token: token,
      channelId: channelId,
      uid: 0, // 0 = server-assigned uid
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: role,
        publishCameraTrack: false,
        publishMicrophoneTrack: false,
        autoSubscribeVideo: false, // ← never auto-subscribe
        autoSubscribeAudio: false, // ← never auto-subscribe
        enableAudioRecordingOrPlayout: true,
      ),
    );
    // _inChannel set to true inside onJoinChannelSuccess
  }

  // ── Leave channel ─────────────────────────────────────────────────────────

  Future<void> leaveChannel() async {
    if (!_inChannel) return;
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
    if (kIsWeb) {
      _inChannel = false;
      _channelUids.clear();
      _subscribedUids.clear();
      _emit(const EngineLeftEvent());
      return;
    }
    await _engine?.leaveChannel();
  }

  // ── Visibility-based subscription ─────────────────────────────────────────

  /// Primary subscription API — call whenever the set of visible tiles changes
  /// (scroll, layout change, backgrounding/foregrounding, etc.).
  ///
  /// Subscribes to newly visible uids, unsubscribes from off-screen ones.
  /// Hard-capped at [_maxTileSubscriptions].
  Future<void> setVisibleUids(List<int> visibleUids) async {
    if (!_inChannel || kIsWeb) return;

    final target = visibleUids.take(_maxTileSubscriptions).toSet();
    final toSubscribe = target.difference(_subscribedUids);
    final toUnsubscribe = _subscribedUids.difference(target);

    for (final uid in toUnsubscribe) {
      await _muteRemoteVideo(uid, mute: true);
      await _muteRemoteAudio(uid, mute: true);
      _subscribedUids.remove(uid);
    }

    for (final uid in toSubscribe) {
      if (_channelUids.contains(uid)) {
        await _muteRemoteVideo(uid, mute: false);
        await _muteRemoteAudio(uid, mute: false);
        _subscribedUids.add(uid);
      }
    }
  }

  /// Drop every active subscription without leaving the channel.
  /// Used when the app is backgrounded.
  Future<void> dropAllSubscriptions() async {
    if (!_inChannel || kIsWeb) return;
    for (final uid in List<int>.from(_subscribedUids)) {
      await _muteRemoteVideo(uid, mute: true);
      await _muteRemoteAudio(uid, mute: true);
    }
    _subscribedUids.clear();
  }

  // ── Publishing ─────────────────────────────────────────────────────────────

  Future<void> startPublishingVideo() async {
    if (_publishingVideo || kIsWeb || !_inChannel) return;
    await _engine?.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine?.enableLocalVideo(true);
    await _engine?.muteLocalVideoStream(false);
    await _engine?.updateChannelMediaOptions(
      const ChannelMediaOptions(publishCameraTrack: true),
    );
    _publishingVideo = true;
  }

  Future<void> stopPublishingVideo() async {
    if (!_publishingVideo || kIsWeb) return;
    await _engine?.muteLocalVideoStream(true);
    await _engine?.enableLocalVideo(false);
    await _engine?.updateChannelMediaOptions(
      const ChannelMediaOptions(publishCameraTrack: false),
    );
    _publishingVideo = false;
    if (!_publishingAudio) {
      await _engine?.setClientRole(role: ClientRoleType.clientRoleAudience);
    }
  }

  Future<void> startPublishingAudio() async {
    if (_publishingAudio || kIsWeb || !_inChannel) return;
    await _engine?.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine?.enableLocalAudio(true);
    await _engine?.muteLocalAudioStream(false);
    await _engine?.updateChannelMediaOptions(
      const ChannelMediaOptions(publishMicrophoneTrack: true),
    );
    _publishingAudio = true;
  }

  Future<void> stopPublishingAudio() async {
    if (!_publishingAudio || kIsWeb) return;
    await _engine?.muteLocalAudioStream(true);
    await _engine?.enableLocalAudio(false);
    await _engine?.updateChannelMediaOptions(
      const ChannelMediaOptions(publishMicrophoneTrack: false),
    );
    _publishingAudio = false;
    if (!_publishingVideo) {
      await _engine?.setClientRole(role: ClientRoleType.clientRoleAudience);
    }
  }

  /// Drop all publishing without leaving the channel (background state).
  Future<void> dropPublishing() async {
    await stopPublishingVideo();
    await stopPublishingAudio();
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
    if (_inChannel) await leaveChannel();
    _events.close();
    if (!kIsWeb) {
      await _engine?.release();
      _engine = null;
    }
    _initialized = false;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _muteRemoteVideo(int uid, {required bool mute}) async {
    try {
      await _engine?.muteRemoteVideoStream(uid: uid, mute: mute);
    } catch (e) {
      debugPrint('[VIDEO_ENGINE] muteRemoteVideo($uid, $mute): $e');
    }
  }

  Future<void> _muteRemoteAudio(int uid, {required bool mute}) async {
    try {
      await _engine?.muteRemoteAudioStream(uid: uid, mute: mute);
    } catch (e) {
      debugPrint('[VIDEO_ENGINE] muteRemoteAudio($uid, $mute): $e');
    }
  }

  void _emit(VideoEngineEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  // ── Native event handlers ─────────────────────────────────────────────────

  void _registerEventHandlers() {
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection conn, int elapsed) {
          _localUid = conn.localUid;
          _inChannel = true;
          debugPrint(
              '[VIDEO_ENGINE] Joined channel ${conn.channelId} uid=$_localUid');
          _emit(EngineJoinedEvent(_localUid!));
          // Start token refresh timer for long-running rooms
          if (_channelId != null && _lastUserId != null) {
            _startTokenRefreshTimer(
                channelId: _channelId!, userId: _lastUserId!);
          }
        },
        onLeaveChannel: (RtcConnection conn, RtcStats stats) {
          debugPrint('[VIDEO_ENGINE] Left channel');
          _inChannel = false;
          _localUid = null;
          _channelUids.clear();
          _subscribedUids.clear();
          _publishingVideo = false;
          _publishingAudio = false;
          _emit(const EngineLeftEvent());
        },
        onUserJoined: (RtcConnection conn, int remoteUid, int elapsed) {
          debugPrint('[VIDEO_ENGINE] Remote user joined: $remoteUid');
          _channelUids.add(remoteUid);
          _emit(RemoteUserJoinedEvent(remoteUid));
          // Do NOT subscribe here — only setVisibleUids() triggers subscriptions
        },
        onUserOffline: (
          RtcConnection conn,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          debugPrint('[VIDEO_ENGINE] Remote user left: $remoteUid');
          _channelUids.remove(remoteUid);
          _subscribedUids.remove(remoteUid);
          _emit(RemoteUserLeftEvent(remoteUid));
        },
        onRemoteVideoStateChanged: (
          RtcConnection conn,
          int remoteUid,
          RemoteVideoState state,
          RemoteVideoStateReason reason,
          int elapsed,
        ) {
          final hasVideo = state == RemoteVideoState.remoteVideoStateDecoding ||
              state == RemoteVideoState.remoteVideoStateStarting;
          _emit(RemoteVideoToggleEvent(remoteUid, hasVideo));
        },
        onActiveSpeaker: (RtcConnection conn, int uid) {
          _emit(ActiveSpeakerEvent(uid == 0 ? null : uid));
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[VIDEO_ENGINE] Error $err: $msg');
          _emit(EngineErrorEvent('$err: $msg'));
        },
        onTokenPrivilegeWillExpire: (RtcConnection conn, String token) {
          debugPrint('[VIDEO_ENGINE] Token will expire — refreshing...');
          if (_channelId != null && _lastUserId != null) {
            _refreshAndRenewToken(
                channelId: _channelId!, userId: _lastUserId!);
          }
        },
      ),
    );
  }

  // ── Token refresh ─────────────────────────────────────────────────────────

  /// Start a periodic timer that refreshes the token ~23 hours after joining.
  /// This covers long-running rooms (concerts, social rooms, etc.) where the
  /// default 24-hour Agora token would otherwise expire mid-session.
  void _startTokenRefreshTimer({
    required String channelId,
    required String userId,
  }) {
    _tokenRefreshTimer?.cancel();
    // Refresh 1 hour before the 24h token expires
    _tokenRefreshTimer = Timer(const Duration(hours: 23), () {
      _refreshAndRenewToken(channelId: channelId, userId: userId);
    });
    debugPrint('[VIDEO_ENGINE] Token refresh timer set for 23h');
  }

  /// Re-fetch a fresh token from Cloud Functions and renew it in the engine.
  Future<void> _refreshAndRenewToken({
    required String channelId,
    required String userId,
  }) async {
    try {
      debugPrint('[VIDEO_ENGINE] Refreshing token for channel: $channelId');
      final newToken = await _fetchToken(channelId: channelId, userId: userId);
      final ok = await AgoraPlatformService.renewToken(newToken);
      debugPrint('[VIDEO_ENGINE] Token renewed: $ok');
      // Reschedule for the next 23h cycle
      if (_inChannel) {
        _startTokenRefreshTimer(channelId: channelId, userId: userId);
      }
    } catch (e) {
      debugPrint('[VIDEO_ENGINE] Token refresh failed: $e');
    }
  }

  // ── App ID / Token ────────────────────────────────────────────────────────

  String? _cachedAppId;

  Future<String> _loadAppId() async {    if (_cachedAppId != null) return _cachedAppId!;

    // Try Firestore first, fall back to .env
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('agora')
          .get();
      final id = doc.data()?['appId'] as String?;
      if (id != null && id.isNotEmpty) {
        _cachedAppId = id;
        return id;
      }
    } catch (_) {
      // Firestore unavailable — fall through to .env fallback
    }

    // Fallback: read from .env (AppConstants)
    final envId = AppConstants.agoraAppId;
    if (envId.isNotEmpty) {
      _cachedAppId = envId;
      return envId;
    }

    throw Exception('Agora App ID not configured. Add to Firestore config/agora or .env.');
  }

  Future<String> _fetchToken({
    required String channelId,
    required String userId,
  }) async {
    final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
      .httpsCallable('generateAgoraToken')
      .call({'roomId': channelId, 'userId': userId}); // Endpoint: https://us-central1-mix-and-mingle-v2.cloudfunctions.net/generateAgoraToken
    final token = (result.data as Map<String, dynamic>)['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('generateAgoraToken returned an empty token.');
    }
    return token;
  }

  // ── Encoder quality helpers ───────────────────────────────────────────────

  VideoDimensions _dimensions() {
    switch (roomType) {
      case RoomType.broadcast:
      case RoomType.concert:
        return const VideoDimensions(width: 640, height: 360); // 360p
      default:
        return const VideoDimensions(width: 320, height: 240); // 240p (group)
    }
  }

  int _bitrate() {
    switch (roomType) {
      case RoomType.broadcast:
      case RoomType.concert:
        return 600; // kbps — 360p
      default:
        return 300; // kbps — 240p, cost-optimised for group rooms
    }
  }
}

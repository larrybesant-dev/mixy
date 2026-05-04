import 'dart:developer' as developer;
import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // For Widget, VoidCallback

import 'web_media_probe_stub.dart'
    if (dart.library.html) 'web_media_probe_web.dart'
    as web_media_probe;
import 'rtc_room_service.dart';

class AgoraServiceException implements Exception {
  const AgoraServiceException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'AgoraServiceException($code): $message';
}

class AgoraService extends RtcRoomService {
  static RtcEngine? _sharedEngine;
  static bool _sharedInitialized = false;
  // Serializes concurrent initialize() calls (e.g. pre-warm racing with cam-tap).
  static Completer<void>? _initInProgress;

  // List of remote user IDs
  final List<int> _remoteUids = [];
  final Set<int> _speakingUids = <int>{};
  final Map<int, VideoStreamType> _remoteStreamTypes = <int, VideoStreamType>{};
  bool _localSpeaking = false;
  double _localAudioLevel = 0.0;
  final Map<int, double> _remoteAudioLevels = <int, double>{};
  bool _joinedChannel = false;
  bool _broadcasterMode = false;
  bool _localVideoCapturing = false;
  bool _localAudioMuted = true;
  bool _previewRunning = false;
  // Stored join credentials used to rejoin as broadcaster on web.
  String? _lastToken;
  String? _lastChannelName;
  int? _lastUid;
  bool _enableVideoInFlight =
      false; // Track if we're actively enabling/disabling video
  /// True while rejoinAsBroadcaster is executing so the disconnect event
  /// fired by the intentional leaveChannel() does not trigger onConnectionLost.
  bool _isRejoinInProgress = false;
  Completer<void>? _localVideoCaptureCompleter;

  // Callbacks for UI updates
  @override
  VoidCallback? onRemoteUserJoined;
  @override
  VoidCallback? onRemoteUserLeft;
  @override
  VoidCallback? onSpeakerActivityChanged;
  @override
  VoidCallback? onLocalVideoCaptureChanged;

  /// Called when the token will expire — caller should fetch a fresh token
  /// and pass it to [renewToken].
  @override
  VoidCallback? onTokenWillExpire;

  /// Called when the SDK connection is lost so the screen can trigger a
  /// reconnect flow.
  @override
  VoidCallback? onConnectionLost;

  @override
  List<int> get remoteUids => List.unmodifiable(_remoteUids);
  @override
  bool get localSpeaking => _localSpeaking;
  @override
  double get localAudioLevel => _localAudioLevel;
  @override
  double remoteAudioLevelForUid(int uid) => _remoteAudioLevels[uid] ?? 0.0;
  @override
  bool get canRenderLocalView =>
      _initialized &&
      _joinedChannel &&
      _broadcasterMode &&
      (_localVideoCapturing || kIsWeb);
  @override
  bool get isBroadcaster => _broadcasterMode;
  @override
  bool get isJoinedChannel => _joinedChannel;
  @override
  bool get isLocalVideoCapturing => _localVideoCapturing;
  @override
  bool get isLocalAudioMuted => _localAudioMuted;

  // System-audio sharing is web-only (WebRtcRoomService); Agora is no-op.
  @override
  bool get isSharingSystemAudio => false;
  @override
  Future<void> shareSystemAudio(bool enabled) async {}

  @override
  bool isRemoteSpeaking(int uid) => _speakingUids.contains(uid);

  @override
  String? userIdForUid(int uid) => null; // Agora: caller falls back to hash lookup

  /// Get the local video view widget
  @override
  Widget getLocalView() {
    if (!canRenderLocalView) {
      return const ColoredBox(
        color: Colors.black12,
        child: Center(child: Icon(Icons.videocam_off, size: 36)),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  /// Get the remote video view widget for a given uid and channel
  @override
  Widget getRemoteView(int uid, String channelId) {
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: channelId),
      ),
    );
  }

  late RtcEngine _engine;
  bool _initialized = false;

  @override
  Future<void> publishLocalVideoStream(bool enabled) async {
    if (!_initialized || !_joinedChannel) {
      return;
    }
    await _engine.updateChannelMediaOptions(
      ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: _broadcasterMode
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        publishCameraTrack: enabled,
        publishMicrophoneTrack: _broadcasterMode,
      ),
    );
  }

  @override
  Future<void> publishLocalAudioStream(bool enabled) async {
    if (!_initialized || !_joinedChannel) {
      return;
    }
    _localAudioMuted = !enabled;
    await _engine.updateChannelMediaOptions(
      ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: _broadcasterMode
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        publishCameraTrack: _localVideoCapturing,
        publishMicrophoneTrack: enabled,
      ),
    );
  }

  Future<void> _startCameraCaptureAfterRoleUpgrade() async {
    try {
      await _engine.startCameraCapture(
        sourceType: VideoSourceType.videoSourceCameraPrimary,
        config: const CameraCapturerConfiguration(),
      );
      developer.log('startCameraCapture called', name: 'AgoraService');
    } catch (error, stackTrace) {
      developer.log(
        'startCameraCapture failed: $error',
        name: 'AgoraService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _startPreviewSafe() async {
    if (_previewRunning) {
      return;
    }
    try {
      await _engine.startPreview();
      _previewRunning = true;
      developer.log('startPreview called', name: 'AgoraService');
    } catch (error, stackTrace) {
      developer.log(
        'startPreview skipped: $error',
        name: 'AgoraService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _stopPreviewSafe() async {
    // On web, stale preview tracks can exist even when local state says
    // preview is not running, so always attempt stop as best effort.
    try {
      await _engine.stopPreview().timeout(const Duration(milliseconds: 500));
      developer.log('stopPreview called', name: 'AgoraService');
    } on TimeoutException {
      developer.log(
        'stopPreview timed out; continuing with best-effort cleanup',
        name: 'AgoraService',
      );
    } catch (error, stackTrace) {
      developer.log(
        'stopPreview skipped: $error',
        name: 'AgoraService',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _previewRunning = false;
    }
  }

  Future<void> _ensurePublishPipelineAfterRoleUpgrade({
    required bool publishAudio,
  }) async {
    await publishLocalVideoStream(true);
    await publishLocalAudioStream(publishAudio);
    await _startCameraCaptureAfterRoleUpgrade();
    await _engine.enableLocalVideo(true);
    await _engine.muteLocalVideoStream(false);
    await _engine.muteLocalAudioStream(!publishAudio);
    await _startPreviewSafe();
  }

  @override
  Future<void> setRemoteVideoSubscription(
    int uid, {
    required bool subscribe,
    bool highQuality = false,
  }) async {
    if (!_initialized || !_joinedChannel) {
      return;
    }
    await _engine.muteRemoteVideoStream(uid: uid, mute: !subscribe);
    if (!subscribe) {
      _remoteStreamTypes.remove(uid);
      return;
    }

    final targetStreamType = highQuality
        ? VideoStreamType.videoStreamHigh
        : VideoStreamType.videoStreamLow;
    if (_remoteStreamTypes[uid] == targetStreamType) {
      return;
    }

    try {
      await _engine.setRemoteVideoStreamType(
        uid: uid,
        streamType: targetStreamType,
      );
      _remoteStreamTypes[uid] = targetStreamType;
    } catch (error, stackTrace) {
      developer.log(
        'setRemoteVideoStreamType failed for uid=$uid highQuality=$highQuality',
        name: 'AgoraService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> ensureDeviceAccess({
    required bool video,
    required bool audio,
  }) async {
    try {
      await web_media_probe.ensureUserMediaAccess(video: video, audio: audio);
    } catch (error) {
      _throwMappedAgoraError(
        error,
        operation: video ? 'access camera' : 'access microphone',
      );
    }
  }

  Never _throwMappedAgoraError(Object error, {required String operation}) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    final operationCode = operation
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    if (lower.contains('notallowederror') ||
        lower.contains('permission denied') ||
        lower.contains('permission denied by system')) {
      throw AgoraServiceException(
        code: 'permission-denied',
        message:
            'Camera/microphone permission was denied. Please allow access and retry.',
        cause: error,
      );
    }

    if (lower.contains('notfounderror') ||
        lower.contains('requested device not found') ||
        lower.contains('no audio input') ||
        lower.contains('no video input') ||
        lower.contains('media devices are not available') ||
        lower.contains('devicesnotfound')) {
      throw AgoraServiceException(
        code: 'no-media-devices',
        message: 'No working camera or microphone was found on this device.',
        cause: error,
      );
    }

    if (lower.contains('notreadableerror') ||
        lower.contains('track is already in use') ||
        lower.contains('device in use')) {
      throw AgoraServiceException(
        code: 'device-in-use',
        message:
            'Camera or microphone is currently in use by another app or tab.',
        cause: error,
      );
    }

    if (lower.contains('notsupportederror') ||
        lower.contains('unsupported browser') ||
        lower.contains('webrtc is not supported') ||
        lower.contains('not supported on this browser')) {
      throw AgoraServiceException(
        code: 'unsupported-browser',
        message:
            'This browser does not fully support required WebRTC features. Use latest Chrome or Edge.',
        cause: error,
      );
    }

    if (lower.contains('secure context') ||
        lower.contains('only secure origins') ||
        lower.contains('insecure context')) {
      throw AgoraServiceException(
        code: 'insecure-context',
        message:
            'Camera/microphone requires HTTPS (or localhost). Open the app over a secure origin.',
        cause: error,
      );
    }

    if (lower.contains('v8breakiterator') ||
        lower.contains('segmenter') ||
        lower.contains('webassembly') ||
        lower.contains('wasm')) {
      throw AgoraServiceException(
        code: 'unsupported-browser',
        message:
            'Browser runtime compatibility issue detected. Update browser and reload the page.',
        cause: error,
      );
    }

    throw AgoraServiceException(
      code: 'agora-$operationCode-failed',
      message: 'Failed to $operation. Please retry.',
      cause: error,
    );
  }

  AgoraServiceException _mapLocalVideoReason(LocalVideoStreamReason reason) {
    switch (reason) {
      case LocalVideoStreamReason.localVideoStreamReasonDeviceNoPermission:
        return const AgoraServiceException(
          code: 'permission-denied',
          message: 'Camera permission was denied by browser or OS settings.',
        );
      case LocalVideoStreamReason.localVideoStreamReasonDeviceBusy:
        return const AgoraServiceException(
          code: 'device-in-use',
          message: 'Camera is busy in another app or browser tab.',
        );
      case LocalVideoStreamReason.localVideoStreamReasonDeviceNotFound:
        return const AgoraServiceException(
          code: 'no-media-devices',
          message: 'No camera device was found on this computer.',
        );
      case LocalVideoStreamReason.localVideoStreamReasonCaptureFailure:
      case LocalVideoStreamReason.localVideoStreamReasonDeviceInterrupt:
      case LocalVideoStreamReason.localVideoStreamReasonDeviceFatalError:
        return const AgoraServiceException(
          code: 'camera-start-failed',
          message:
              'Camera failed to start. Close other camera apps/tabs and retry.',
        );
      default:
        return const AgoraServiceException(
          code: 'camera-not-started',
          message: 'Camera did not start successfully.',
        );
    }
  }

  Future<void> _awaitLocalVideoCapturing({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_localVideoCapturing) {
      developer.log('Video already capturing', name: 'AgoraService');
      return;
    }
    final completer = Completer<void>();
    _localVideoCaptureCompleter = completer;
    developer.log(
      'Waiting for local video capturing with ${timeout.inSeconds}s timeout...',
      name: 'AgoraService',
    );
    try {
      await completer.future.timeout(timeout);
      developer.log(
        'Local video stream is ready (capturing started)',
        name: 'AgoraService',
      );
    } on TimeoutException catch (e) {
      // On web, the video state event may not fire reliably from Agora SDK.
      // Do not force local capture=true here; that can create false positives
      // where UI says camera is on while no stream is actually published.
      if (kIsWeb) {
        developer.log(
          'Local video capturing timeout after ${timeout.inSeconds}s on web; capture not confirmed yet',
          name: 'AgoraService',
          level: 701, // INFO level
        );
      } else {
        developer.log(
          'Local video capturing timeout on $kIsWeb platform',
          name: 'AgoraService',
          error: e,
        );
        rethrow;
      }
    } catch (e) {
      developer.log(
        'Local video capturing failed: $e',
        name: 'AgoraService',
        error: e,
      );
      rethrow;
    } finally {
      if (identical(_localVideoCaptureCompleter, completer)) {
        _localVideoCaptureCompleter = null;
      }
    }
  }

  /// Initialize Agora engine with your App ID
  @override
  Future<void> initialize(String appId) async {
    final normalizedAppId = appId.trim();
    if (normalizedAppId.isEmpty) {
      throw ArgumentError('Agora appId cannot be empty.');
    }

    if (_sharedEngine == null) {
      _sharedEngine = createAgoraRtcEngine();
      developer.log('ENGINE CREATED ONCE', name: 'AgoraService');
    }
    _engine = _sharedEngine!;

    if (_sharedInitialized) {
      developer.log(
        'INITIALIZE CALLED ONCE: already initialized',
        name: 'AgoraService',
      );
    } else if (_initInProgress != null) {
      // Another caller is already running initialize() — wait for it instead
      // of firing a second concurrent call that would conflict on the engine.
      developer.log(
        'INITIALIZE: waiting for in-progress init',
        name: 'AgoraService',
      );
      try {
        await _initInProgress!.future;
        developer.log(
          'INITIALIZE: in-progress init completed, reusing result',
          name: 'AgoraService',
        );
      } catch (error) {
        // The in-progress init failed; propagate so caller can retry.
        _throwMappedAgoraError(error, operation: 'initialize live media');
      }
    } else {
      final completer = Completer<void>();
      _initInProgress = completer;
      final attemptTimeout = kIsWeb
          ? const Duration(seconds: 75)
          : const Duration(seconds: 10);
      try {
        if (kIsWeb) {
          await _stopPreviewSafe();
          try {
            await _engine.disableVideo();
          } catch (_) {
            // Best effort stale track cleanup before initialize on web.
          }
        }
        developer.log(
          'Agora initialize attempt 1/1 starting',
          name: 'AgoraService',
        );
        await _engine
            .initialize(
              RtcEngineContext(
                appId: normalizedAppId,
                channelProfile:
                    ChannelProfileType.channelProfileLiveBroadcasting,
              ),
            )
            .timeout(
              attemptTimeout,
              onTimeout: () => throw TimeoutException(
                'Agora initialize attempt timed out after ${attemptTimeout.inSeconds}s',
              ),
            );
        _sharedInitialized = true;
        _initInProgress = null;
        completer.complete();
        developer.log('INITIALIZE CALLED ONCE: success', name: 'AgoraService');
      } catch (error, stackTrace) {
        developer.log(
          'Agora initialize attempt 1/1 failed: $error',
          name: 'AgoraService',
          error: error,
          stackTrace: stackTrace,
        );
        _initInProgress = null;
        completer.completeError(error, stackTrace);
        try {
          await _engine.release();
        } catch (_) {
          // Best effort cleanup before next retry click.
        }
        _sharedEngine = null;
        _sharedInitialized = false;
        _initialized = false;
        _throwMappedAgoraError(error, operation: 'initialize live media');
      }
    }

    // Set up event handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onUserJoined: (connection, remoteUid, elapsed) {
          if (!_remoteUids.contains(remoteUid)) {
            _remoteUids.add(remoteUid);
          }
          if (onRemoteUserJoined != null) onRemoteUserJoined!();
        },
        onUserOffline: (connection, remoteUid, reason) {
          _remoteUids.remove(remoteUid);
          _remoteStreamTypes.remove(remoteUid);
          _speakingUids.remove(remoteUid);
          if (onRemoteUserLeft != null) onRemoteUserLeft!();
        },
        onAudioVolumeIndication:
            (connection, speakers, speakerNumber, totalVolume) {
              final nextSpeakingUids = <int>{};
              var nextLocalSpeaking = false;
              var nextLocalLevel = 0.0;
              final nextRemoteLevels = <int, double>{};
              for (final speaker in speakers) {
                final uid = speaker.uid ?? 0;
                final volume = speaker.volume ?? 0;
                final level = (volume / 255.0).clamp(0.0, 1.0);
                if (uid == 0) {
                  nextLocalLevel = level;
                  if (volume > 10) nextLocalSpeaking = true;
                } else {
                  nextRemoteLevels[uid] = level;
                  if (volume > 10) nextSpeakingUids.add(uid);
                }
              }

              _localAudioLevel = nextLocalLevel;
              _remoteAudioLevels
                ..clear()
                ..addAll(nextRemoteLevels);

              final changed =
                  nextLocalSpeaking != _localSpeaking ||
                  nextSpeakingUids.length != _speakingUids.length ||
                  !nextSpeakingUids.containsAll(_speakingUids);
              if (!changed) {
                return;
              }

              _localSpeaking = nextLocalSpeaking;
              _speakingUids
                ..clear()
                ..addAll(nextSpeakingUids);
              if (onSpeakerActivityChanged != null) {
                onSpeakerActivityChanged!();
              }
            },
        onError: (err, msg) {
          developer.log('Agora engine error: $err $msg', name: 'AgoraService');
        },
        onTokenPrivilegeWillExpire: (connection, token) {
          developer.log(
            'Agora token will expire — triggering renewal',
            name: 'AgoraService',
          );
          if (onTokenWillExpire != null) onTokenWillExpire!();
        },
        onConnectionStateChanged: (connection, state, reason) {
          developer.log(
            'Agora connection state: $state reason: $reason',
            name: 'AgoraService',
          );
          // Only surface a lost-connection event for terminal states.
          // connectionStateReconnecting is a transient state Agora handles
          // internally; firing onConnectionLost there causes a double-reconnect.
          // _isRejoinInProgress suppresses the spurious disconnect fired by the
          // intentional leaveChannel() inside rejoinAsBroadcaster — on web the
          // SDK may not send connectionChangedLeaveChannel as the reason.
          if (state == ConnectionStateType.connectionStateDisconnected &&
              reason !=
                  ConnectionChangedReasonType.connectionChangedLeaveChannel &&
              !_isRejoinInProgress) {
            if (onConnectionLost != null) onConnectionLost!();
          }
        },
        onLocalVideoStateChanged: (source, state, reason) {
          if (!source.name.startsWith('videoSourceCamera')) {
            return;
          }
          developer.log(
            'Local video state: $state, reason: $reason',
            name: 'AgoraService',
          );
          if (state == LocalVideoStreamState.localVideoStreamStateCapturing ||
              state == LocalVideoStreamState.localVideoStreamStateEncoding) {
            final changed = !_localVideoCapturing;
            _localVideoCapturing = true;
            if (changed && onLocalVideoCaptureChanged != null) {
              onLocalVideoCaptureChanged!();
            }
            if (changed) {
              developer.log('CAMERA TRACK STARTED', name: 'AgoraService');
            }
            final waiter = _localVideoCaptureCompleter;
            if (waiter != null && !waiter.isCompleted) {
              waiter.complete();
            }
            return;
          }

          if (state == LocalVideoStreamState.localVideoStreamStateFailed) {
            final changed = _localVideoCapturing;
            _localVideoCapturing = false;
            if (changed && onLocalVideoCaptureChanged != null) {
              onLocalVideoCaptureChanged!();
            }
            final waiter = _localVideoCaptureCompleter;
            if (waiter != null && !waiter.isCompleted) {
              waiter.completeError(_mapLocalVideoReason(reason));
            }
            return;
          }

          // Ignore STOPPED events while we're actively enabling/disabling video
          // to avoid race conditions where the callback fires before the operation completes.
          if (state == LocalVideoStreamState.localVideoStreamStateStopped) {
            if (!_enableVideoInFlight) {
              final changed = _localVideoCapturing;
              _localVideoCapturing = false;
              if (changed && onLocalVideoCaptureChanged != null) {
                onLocalVideoCaptureChanged!();
              }
            } else {
              developer.log(
                'Ignoring STOPPED state before enableVideo operation completes',
                name: 'AgoraService',
              );
            }
          }
        },
      ),
    );

    // Default role is audience; the role is upgraded to broadcaster only when
    // the user actually enables camera or microphone in joinRoom().
    try {
      await _engine.setChannelProfile(
        ChannelProfileType.channelProfileLiveBroadcasting,
      );
      await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);
      developer.log(
        'AGORA ROLE: audience (default; upgraded to broadcaster on cam/mic enable)',
        name: 'AgoraService',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Agora channelProfile/clientRole setup skipped during initialize',
        name: 'AgoraService',
        error: error,
        stackTrace: stackTrace,
      );
    }

    try {
      await _engine.enableAudio();
    } catch (error, stackTrace) {
      developer.log(
        'Agora enableAudio failed',
        name: 'AgoraService',
        error: error,
        stackTrace: stackTrace,
      );
    }
    try {
      await _engine.enableDualStreamMode(enabled: true);
    } catch (error, stackTrace) {
      developer.log(
        'Agora enableDualStreamMode failed',
        name: 'AgoraService',
        error: error,
        stackTrace: stackTrace,
      );
    }
    try {
      await _engine.enableAudioVolumeIndication(
        interval: 300,
        smooth: 3,
        reportVad: true,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Agora audio volume indication failed',
        name: 'AgoraService',
        error: error,
        stackTrace: stackTrace,
      );
    }
    _initialized = true;
  }

  /// Join a video channel
  @override
  Future<void> joinRoom(
    String token,
    String channelName,
    int uid, {
    bool publishCameraTrackOnJoin = true,
    bool publishMicrophoneTrackOnJoin = true,
  }) async {
    if (!_initialized) {
      throw StateError(
        'Agora engine must be initialized before joining a channel.',
      );
    }

    final normalizedToken = token.trim();
    final normalizedChannelName = channelName.trim();
    if (normalizedToken.isEmpty) {
      throw ArgumentError('Agora token cannot be empty.');
    }
    if (normalizedChannelName.isEmpty) {
      throw ArgumentError('Agora channelName cannot be empty.');
    }

    final shouldPublishCamera = publishCameraTrackOnJoin;
    final shouldPublishMicrophone = publishMicrophoneTrackOnJoin;

    // Join as audience when not publishing anything so Agora allocates the
    // correct resources and does not waste a broadcaster slot.
    final isBroadcastJoin = shouldPublishCamera || shouldPublishMicrophone;
    final initialRole = isBroadcastJoin
        ? ClientRoleType.clientRoleBroadcaster
        : ClientRoleType.clientRoleAudience;

    try {
      await _engine.setChannelProfile(
        ChannelProfileType.channelProfileLiveBroadcasting,
      );
      await _engine.setClientRole(role: initialRole);
      developer.log(
        'AGORA ROLE: ${isBroadcastJoin ? "broadcaster" : "audience"} (publishing: cam=$shouldPublishCamera mic=$shouldPublishMicrophone)',
        name: 'AgoraService',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Agora channelProfile/clientRole before join failed',
        name: 'AgoraService',
        error: error,
        stackTrace: stackTrace,
      );
      _throwMappedAgoraError(error, operation: 'set client role');
    }

    try {
      await _engine.joinChannel(
        token: normalizedToken,
        channelId: normalizedChannelName,
        uid: uid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: initialRole,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishCameraTrack: shouldPublishCamera,
          publishMicrophoneTrack: shouldPublishMicrophone,
        ),
      );
      if (shouldPublishCamera) {
        await _ensurePublishPipelineAfterRoleUpgrade(
          publishAudio: shouldPublishMicrophone,
        );
      }
    } catch (error) {
      _throwMappedAgoraError(error, operation: 'join room');
    }

    _joinedChannel = true;
    _broadcasterMode = isBroadcastJoin;
    // Store for potential rejoin on web when enabling camera from audience mode.
    _lastToken = normalizedToken;
    _lastChannelName = normalizedChannelName;
    _lastUid = uid;
  }

  /// Join a video channel
  Future<void> joinChannel(
    String token,
    String channelName,
    int uid, {
    bool publishCameraTrackOnJoin = true,
    bool publishMicrophoneTrackOnJoin = true,
  }) async {
    await joinRoom(
      token,
      channelName,
      uid,
      publishCameraTrackOnJoin: publishCameraTrackOnJoin,
      publishMicrophoneTrackOnJoin: publishMicrophoneTrackOnJoin,
    );
  }

  @override
  Future<void> setBroadcaster(bool enabled) async {
    if (!_initialized) {
      developer.log(
        'setBroadcaster called but service not initialized',
        name: 'AgoraService',
      );
      return;
    }
    try {
      final targetRole = enabled
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience;
      developer.log(
        'Setting client role to ${enabled ? "broadcaster" : "audience"}',
        name: 'AgoraService',
      );
      await _engine.setClientRole(role: targetRole);
      _broadcasterMode = enabled;
      developer.log('Client role changed successfully', name: 'AgoraService');
    } catch (error) {
      developer.log(
        'Error setting client role: $error',
        name: 'AgoraService',
        error: error,
      );
      _throwMappedAgoraError(error, operation: 'switch role');
    }
  }

  /// On web, role-switching alone does not reliably renegotiate the WebRTC
  /// publish track. This method leaves and rejoins the channel as broadcaster
  /// so the browser negotiates a fresh publish path.
  Future<void> rejoinAsBroadcaster(
    String token,
    String channelName,
    int uid, {
    bool publishMicrophoneTrack = false,
  }) async {
    if (!_initialized) return;
    developer.log(
      'rejoinAsBroadcaster: leaving channel to force publish track renegotiation',
      name: 'AgoraService',
    );

    // Suppress onConnectionLost for the duration of this intentional leave+rejoin.
    // On web the Agora SDK may not send connectionChangedLeaveChannel as the
    // disconnect reason, which would otherwise trigger _handleConnectionLost and
    // null out _agoraService mid-operation.
    _isRejoinInProgress = true;
    try {
      // --- leave (full cleanup via existing method) ---
      try {
        await leaveChannel();
      } catch (e) {
        developer.log(
          'rejoinAsBroadcaster: leaveChannel error (ignored): $e',
          name: 'AgoraService',
        );
      }
      // Give web runtimes a short moment to fully release previous tracks.
      await Future<void>.delayed(const Duration(milliseconds: 250));

      // --- re‑enable video engine before join ---
      try {
        await _engine.enableVideo();
      } catch (e) {
        developer.log(
          'rejoinAsBroadcaster: enableVideo error: $e',
          name: 'AgoraService',
        );
      }

      // --- rejoin as broadcaster ---
      developer.log(
        'AGORA ROLE: broadcaster (rejoin for WebRTC SDP renegotiation)',
        name: 'AgoraService',
      );
      await _engine.setChannelProfile(
        ChannelProfileType.channelProfileLiveBroadcasting,
      );
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine.joinChannel(
        token: token.trim(),
        channelId: channelName.trim(),
        uid: uid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishCameraTrack: true,
          publishMicrophoneTrack: publishMicrophoneTrack,
        ),
      );

      // Set state flags BEFORE calling _ensurePublishPipelineAfterRoleUpgrade so
      // that publishLocalVideoStream / publishLocalAudioStream do not return early
      // on the !_joinedChannel guard, and use clientRoleBroadcaster in options.
      _joinedChannel = true;
      _broadcasterMode = true;

      await _engine.enableVideo();
      await _ensurePublishPipelineAfterRoleUpgrade(
        publishAudio: publishMicrophoneTrack,
      );
      _enableVideoInFlight = true;
      try {
        await _awaitLocalVideoCapturing();
      } finally {
        _enableVideoInFlight = false;
      }

      // Mirror the non-rejoin enableVideo path: if the capture event never
      // fired on web (SDK reliability issue), force the flag true here so
      // canRenderLocalView is consistent with broadcasterMode.
      if (kIsWeb && !_localVideoCapturing) {
        developer.log(
          'rejoinAsBroadcaster: web camera event not received; assuming capture active.',
          name: 'AgoraService',
        );
        _localVideoCapturing = true;
        if (onLocalVideoCaptureChanged != null) onLocalVideoCaptureChanged!();
      }

      developer.log(
        'rejoinAsBroadcaster: successfully rejoined as broadcaster',
        name: 'AgoraService',
      );
    } catch (error) {
      // Roll back flags if rejoin failed so callers see a consistent state.
      _joinedChannel = false;
      _broadcasterMode = false;
      _throwMappedAgoraError(error, operation: 'rejoin as broadcaster');
    } finally {
      _isRejoinInProgress = false;
    }
  }

  /// Renews the Agora token without leaving the channel.
  /// Call this from the [onTokenWillExpire] callback.
  @override
  Future<void> renewToken(String newToken) async {
    if (!_initialized || !_joinedChannel) return;
    final trimmed = newToken.trim();
    if (trimmed.isEmpty) return;
    try {
      await _engine.renewToken(trimmed);
      _lastToken = trimmed; // keep stored token in sync
      developer.log('renewToken: token refreshed', name: 'AgoraService');
    } catch (error, stackTrace) {
      developer.log(
        'renewToken failed: $error',
        name: 'AgoraService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Leave the current channel
  Future<void> leaveChannel() async {
    if (!_initialized) return;
    await _stopPreviewSafe();
    if (_joinedChannel) {
      await _engine.leaveChannel();
    }
    _remoteUids.clear();
    _remoteStreamTypes.clear();
    _speakingUids.clear();
    _localSpeaking = false;
    _joinedChannel = false;
    _broadcasterMode = false;
    _localVideoCapturing = false;
    _previewRunning = false;
  }

  /// Mute/unmute local audio
  @override
  Future<void> mute(bool muted) async {
    _localAudioMuted = muted;
    if (!_initialized) return;
    try {
      await _engine.muteLocalAudioStream(muted);
    } catch (error) {
      _throwMappedAgoraError(error, operation: 'toggle microphone');
    }
  }

  /// Set local microphone input gain.
  ///
  /// [volume] range [0.0, 2.0]; 1.0 = default (maps to Agora value 100).
  @override
  Future<void> setMicVolume(double volume) async {
    if (!_initialized) return;
    final agoraVol = (volume.clamp(0.0, 2.0) * 100).round();
    try {
      await _engine.adjustRecordingSignalVolume(agoraVol);
    } catch (e) {
      developer.log('setMicVolume error: $e', name: 'AgoraService');
    }
  }

  /// Set local speaker / playback output volume.
  ///
  /// [volume] range [0.0, 1.0]; 1.0 = default (maps to Agora value 100).
  @override
  Future<void> setSpeakerVolume(double volume) async {
    if (!_initialized) return;
    final agoraVol = (volume.clamp(0.0, 1.0) * 100).round();
    try {
      await _engine.adjustPlaybackSignalVolume(agoraVol);
    } catch (e) {
      developer.log('setSpeakerVolume error: $e', name: 'AgoraService');
    }
  }

  /// Enable/disable video.
  ///
  /// [publishMicrophoneTrack] controls whether the microphone track is
  /// published when enabling video. Pass `false` when the user's mic is
  /// currently muted so that enabling the camera does not silently re-enable
  /// audio. Defaults to `true` for backward-compatible behaviour.
  @override
  Future<void> enableVideo(
    bool enabled, {
    bool publishMicrophoneTrack = true,
  }) async {
    if (!_initialized) {
      developer.log(
        'enableVideo called but service not initialized',
        name: 'AgoraService',
      );
      return;
    }
    developer.log('enableVideo($enabled) - started', name: 'AgoraService');
    _enableVideoInFlight = true;
    try {
      if (enabled) {
        // On web, simply calling setClientRole + updateChannelMediaOptions does
        // not reliably trigger a WebRTC SDP renegotiation to add the publish
        // track. Rejoin as broadcaster instead so Chrome/Edge negotiate a fresh
        // publish path. This is only needed the first time we go from audience
        // → broadcaster; if already in broadcaster mode (e.g. mic is on), the
        // standard updateChannelMediaOptions path is fine.
        if (kIsWeb &&
            !_broadcasterMode &&
            _lastToken != null &&
            _lastChannelName != null &&
            _lastUid != null) {
          developer.log(
            'enableVideo(true) web: delegating to rejoinAsBroadcaster',
            name: 'AgoraService',
          );
          await rejoinAsBroadcaster(
            _lastToken!,
            _lastChannelName!,
            _lastUid!,
            publishMicrophoneTrack: publishMicrophoneTrack,
          );
          developer.log(
            'enableVideo($enabled) - completed successfully (via rejoin)',
            name: 'AgoraService',
          );
          return;
        }

        if (!_broadcasterMode) {
          developer.log(
            'Setting client role to broadcaster',
            name: 'AgoraService',
          );
          await _engine.setClientRole(
            role: ClientRoleType.clientRoleBroadcaster,
          );
          _broadcasterMode = true;
        }
        developer.log('Enabling video engine', name: 'AgoraService');
        await _engine.enableVideo();
        await _engine.enableLocalVideo(true);
        await _engine.muteLocalVideoStream(false);
        // startPreview() activates the hardware camera.
        // On web: call directly (not via _startPreviewSafe) so that errors
        // propagate to the caller instead of being silently swallowed.
        // A previous permission probe inside _connectCall already verified
        // device access; there is no need for a second getUserMedia preflight
        // here, which would acquire then immediately release the camera track
        // and cause a "device still releasing" race on many browsers.
        // On native: use the standard stopPreview + startCameraCapture dance.
        if (kIsWeb) {
          if (!_previewRunning) {
            try {
              await _engine.startPreview();
              _previewRunning = true;
              developer.log('startPreview called (web)', name: 'AgoraService');
            } catch (error) {
              // Map raw DomException/Dart errors to typed AgoraServiceException
              // so the UI can show a meaningful snackbar instead of a black tile.
              _throwMappedAgoraError(error, operation: 'start camera preview');
            }
          }
        } else {
          await _stopPreviewSafe();
          await _startCameraCaptureAfterRoleUpgrade();
          await _startPreviewSafe();
        }
        if (_joinedChannel) {
          developer.log(
            'Updating channel media options for video publishing',
            name: 'AgoraService',
          );
          await _engine.updateChannelMediaOptions(
            ChannelMediaOptions(
              channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
              publishCameraTrack: true,
              publishMicrophoneTrack: publishMicrophoneTrack,
            ),
          );
        }
        developer.log(
          'Awaiting local video capturing...',
          name: 'AgoraService',
        );
        await _awaitLocalVideoCapturing();
        if (kIsWeb && !_localVideoCapturing) {
          // On web, the Agora SDK does not reliably fire onLocalVideoStateChanged
          // after enableVideo(). If the full API sequence completed without error,
          // treat the camera as capturing — the hardware is on.
          developer.log(
            'Web: camera capturing event not received; assuming capture is active after successful API sequence.',
            name: 'AgoraService',
          );
          _localVideoCapturing = true;
          if (onLocalVideoCaptureChanged != null) onLocalVideoCaptureChanged!();
        }
        developer.log(
          'enableVideo($enabled) - completed successfully',
          name: 'AgoraService',
        );
      } else {
        await _stopPreviewSafe();
        await _engine.muteLocalVideoStream(true);
        await _engine.enableLocalVideo(false);
        _localVideoCapturing = false;
        // Keep _broadcasterMode as-is — camera toggles do NOT change the Agora
        // role. Firebase slot service governs who may broadcast; Agora stays as
        // broadcaster so the next enableVideo(true) reuses the existing publish
        // path (muteLocalVideoStream + enableLocalVideo) instead of triggering
        // an expensive leaveChannel/joinChannel renegotiation.
        if (_joinedChannel && _broadcasterMode) {
          await _engine.updateChannelMediaOptions(
            ChannelMediaOptions(
              channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
              publishCameraTrack: false,
              publishMicrophoneTrack: false,
            ),
          );
        }
        developer.log(
          'enableVideo(false) - completed; role stays broadcaster',
          name: 'AgoraService',
        );
      }
    } catch (error) {
      developer.log(
        'enableVideo($enabled) - failed: $error',
        name: 'AgoraService',
        error: error,
      );
      if (error is AgoraServiceException) {
        rethrow;
      }
      _throwMappedAgoraError(error, operation: 'toggle camera');
    } finally {
      _enableVideoInFlight = false;
    }
  }

  @override
  Future<void> dispose() async {
    if (!_initialized) return;
    // Unblock any caller awaiting _awaitLocalVideoCapturing immediately
    // instead of making them wait for the full 8-second timeout.
    final captureWaiter = _localVideoCaptureCompleter;
    if (captureWaiter != null && !captureWaiter.isCompleted) {
      captureWaiter.completeError(
        StateError('AgoraService disposed while awaiting local video capture'),
      );
    }
    _localVideoCaptureCompleter = null;
    await _stopPreviewSafe();
    if (_joinedChannel) {
      await _engine.leaveChannel();
    }
    // Shared engine is kept for the current page lifetime.
    _remoteUids.clear();
    _speakingUids.clear();
    _localSpeaking = false;
    _joinedChannel = false;
    _broadcasterMode = false;
    _localVideoCapturing = false;
    _previewRunning = false;
    _initialized = false;
  }
}

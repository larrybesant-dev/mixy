// lib/services/agora_service_web.dart
// Production-ready Agora Web Service using dart:js_interop
// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:async';
import 'dart:js_interop';

@JS('agoraWebBridge.init')
external JSPromise _jsInit(JSString appId);

@JS('agoraWebBridge.joinChannel')
external JSPromise _jsJoinChannel(
    JSString token, JSString channel, JSString uid);

@JS('agoraWebBridge.createCameraTrack')
external JSPromise _jsCreateCameraTrack([JSString? deviceId]);

@JS('agoraWebBridge.createMicrophoneTrack')
external JSPromise _jsCreateMicrophoneTrack([JSString? deviceId]);

@JS('agoraWebBridge.playCamera')
external void _jsPlayCamera(JSString videoElementId);

@JS('agoraWebBridge.leaveChannel')
external JSPromise _jsLeaveChannel();

@JS('agoraWebBridge.switchCamera')
external JSPromise _jsSwitchCamera(JSString deviceId);

@JS('agoraWebBridge.switchMic')
external JSPromise _jsSwitchMic(JSString deviceId);

@JS('agoraWebBridge.getDevices')
external JSPromise _jsGetDevices();

@JS('agoraWebBridge.setMicMuted')
external JSPromise _jsSetMicMuted(JSBoolean muted);

@JS('agoraWebBridge.setVideoMuted')
external JSPromise _jsSetVideoMuted(JSBoolean muted);

@JS('agoraWebBridge.getState')
external JSAny? _jsGetState();

@JS('agoraWebBridge.subscribeRemoteVideoTo')
external JSBoolean _jsSubscribeRemoteVideoTo(JSString elementId);

@JS('agoraWebBridge.renewToken')
external JSBoolean _jsRenewToken(JSString newToken);

@JS('agoraBridgeReady')
external JSAny? get _jsBridgeReady;

bool _jsToBool(JSAny? value) {
  if (value == null) return false;
  try {
    final dartValue = value.dartify();
    return dartValue == true;
  } catch (e) {
    return false;
  }
}

class AgoraException implements Exception {
  final String message;
  final Object? originalError;
  AgoraException(this.message, [this.originalError]);
  @override
  String toString() => 'AgoraException: $message';
}

class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  factory AgoraService.withAppId({required String appId}) {
    final instance = AgoraService._instance;
    instance._pendingAppId = appId;
    return instance;
  }

  String? _pendingAppId;
  bool _initialized = false;
  String? _appId;
  bool _inChannel = false;
  String? _currentChannelId;

  bool get isBridgeReady {
    if (!kIsWeb) return false;
    try {
      return _jsToBool(_jsBridgeReady);
    } catch (e) {
      return false;
    }
  }

  bool get isInitialized => _initialized;
  bool get isInChannel => _inChannel;
  String? get currentChannelId => _currentChannelId;

  Future<bool> init(String appId) async {
    if (!kIsWeb) return false;
    if (_initialized && _appId == appId) return true;
    try {
      final result = await _jsInit(appId.toJS).toDart;
      final success = _jsToBool(result);
      if (success) {
        _initialized = true;
        _appId = appId;
      }
      return success;
    } catch (e) {
      debugPrint('[AgoraService] Init failed: $e');
      return false;
    }
  }

  Future<void> initialize() async {
    final appId = _pendingAppId ?? _appId;
    if (appId == null || appId.isEmpty) {
      throw AgoraException('Agora App ID not provided');
    }
    final ok = await init(appId);
    if (!ok) throw AgoraException('Failed to initialize Agora SDK');
  }

  Future<bool> joinChannel(
      {String? token, required String channelId, required String uid}) async {
    if (!kIsWeb) return false;
    try {
      final result =
          await _jsJoinChannel((token ?? '').toJS, channelId.toJS, uid.toJS)
              .toDart;
      final success = _jsToBool(result);
      if (success) {
        _inChannel = true;
        _currentChannelId = channelId;
      }
      return success;
    } catch (e) {
      debugPrint('[AgoraService] Join failed: $e');
      return false;
    }
  }

  Future<bool> startCamera(String videoElementId, [String? deviceId]) async {
    if (!kIsWeb) return false;
    try {
      final result = await _jsCreateCameraTrack(deviceId?.toJS).toDart;
      final success = _jsToBool(result);
      if (success) _jsPlayCamera(videoElementId.toJS);
      return success;
    } catch (e) {
      debugPrint('[AgoraService] Camera failed: $e');
      return false;
    }
  }

  Future<bool> startMic([String? deviceId]) async {
    if (!kIsWeb) return false;
    try {
      final result = await _jsCreateMicrophoneTrack(deviceId?.toJS).toDart;
      return _jsToBool(result);
    } catch (e) {
      debugPrint('[AgoraService] Mic failed: $e');
      return false;
    }
  }

  Future<void> leaveChannel() async {
    if (!kIsWeb || !_inChannel) return;
    try {
      await _jsLeaveChannel().toDart;
    } catch (e) {
      debugPrint('[AgoraService] Leave failed: $e');
    } finally {
      _inChannel = false;
      _currentChannelId = null;
    }
  }

  Future<bool> switchCamera(String deviceId) async {
    if (!kIsWeb) return false;
    try {
      final result = await _jsSwitchCamera(deviceId.toJS).toDart;
      return _jsToBool(result);
    } catch (e) {
      return false;
    }
  }

  Future<bool> switchMic(String deviceId) async {
    if (!kIsWeb) return false;
    try {
      final result = await _jsSwitchMic(deviceId.toJS).toDart;
      return _jsToBool(result);
    } catch (e) {
      return false;
    }
  }

  Future<void> setMicrophoneMuted(bool muted) async {
    if (!kIsWeb) return;
    try {
      await _jsSetMicMuted(muted.toJS).toDart;
    } catch (e) {
      throw AgoraException('Failed to control microphone', e);
    }
  }

  Future<void> setVideoCameraMuted(bool muted) async {
    if (!kIsWeb) return;
    try {
      await _jsSetVideoMuted(muted.toJS).toDart;
    } catch (e) {
      throw AgoraException('Failed to control video', e);
    }
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    if (!kIsWeb) return [];
    try {
      final jsResult = await _jsGetDevices().toDart;
      if (jsResult == null) return [];
      try {
        final dartified = jsResult.dartify();
        if (dartified is List) {
          return dartified
              .whereType<Map>()
              .map((item) => {
                    'deviceId': item['deviceId']?.toString() ?? '',
                    'label': item['label']?.toString() ?? 'Unknown Device',
                    'kind': item['kind']?.toString() ?? '',
                  })
              .toList();
        }
      } catch (_) {}
      return [];
    } catch (e) {
      debugPrint('[AgoraService] getDevices failed: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getState() async {
    if (!kIsWeb) return {};
    try {
      final jsState = _jsGetState();
      if (jsState == null) return {'bridgeReady': isBridgeReady};
      final dartified = jsState.dartify();
      if (dartified is Map) {
        return {
          'bridgeReady': isBridgeReady,
          'initialized': dartified['initialized'] == true,
          'inChannel': dartified['inChannel'] == true,
          'currentChannel': dartified['currentChannel']?.toString(),
          'hasAudio': dartified['hasAudio'] == true,
          'hasVideo': dartified['hasVideo'] == true,
          'audioMuted': dartified['audioMuted'] ?? true,
          'videoMuted': dartified['videoMuted'] ?? true,
        };
      }
      return {'bridgeReady': isBridgeReady};
    } catch (e) {
      return {'bridgeReady': isBridgeReady, 'error': e.toString()};
    }
  }

  Future<bool> startCameraWithRetry(String videoElementId,
      {String? deviceId, int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      if (await startCamera(videoElementId, deviceId)) return true;
      if (i < retries - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return false;
  }

  Future<bool> startMicWithRetry({String? deviceId, int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      if (await startMic(deviceId)) return true;
      if (i < retries - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return false;
  }

  Future<bool> joinRoomFull({
    required String appId,
    required String channel,
    String? token,
    required String uid,
    required String videoElementId,
    bool enableCamera = true,
    bool enableMic = true,
    String? cameraDeviceId,
    String? micDeviceId,
  }) async {
    if (!kIsWeb) return false;
    if (!await init(appId)) return false;
    if (!await joinChannel(channelId: channel, token: token, uid: uid)) {
      return false;
    }
    if (enableCamera) {
      await startCameraWithRetry(videoElementId, deviceId: cameraDeviceId);
    }
    if (enableMic) await startMicWithRetry(deviceId: micDeviceId);
    return true;
  }

  /// Register an HTML element (by ID) to receive the next remote video stream.
  /// Call this after [joinChannel]. The bridge will play the first remote user's
  /// video track into the element as soon as they publish (or immediately if they
  /// already have a pending track).
  Future<bool> subscribeRemoteVideoTo(String elementId) async {
    if (!kIsWeb) return false;
    try {
      final result = _jsSubscribeRemoteVideoTo(elementId.toJS);
      return _jsToBool(result);
    } catch (e) {
      debugPrint('[AgoraService] subscribeRemoteVideoTo failed: $e');
      return false;
    }
  }

  /// Renew the Agora token for the current channel session.
  /// Call this when [onTokenPrivilegeWillExpire] fires or on a ~23h timer.
  /// Returns true if the JS bridge accepted the new token.
  Future<bool> renewToken(String newToken) async {
    if (!kIsWeb) return false;
    try {
      final result = _jsRenewToken(newToken.toJS);
      return _jsToBool(result);
    } catch (e) {
      debugPrint('[AgoraService] renewToken failed: $e');
      return false;
    }
  }

  Future<void> cleanup() async {
    try {
      if (_inChannel) await leaveChannel();
      _initialized = false;
      _currentChannelId = null;
    } catch (e) {
      debugPrint('[AgoraService] Cleanup error: $e');
    }
  }
}

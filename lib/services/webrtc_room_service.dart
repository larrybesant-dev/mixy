import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:mixvy/services/rtc_room_service.dart';
import 'package:mixvy/services/connection_recovery_handler.dart';
import 'package:mixvy/services/diagnostic_logger.dart';
import '../core/streams/stream_lifecycle_manager.dart';
import '../observability/webrtc_latency_tracker.dart';

/// WebRtcRoomService
/// 
/// The production-hardened engine for MixVy's real-time communication.
/// Manages peer connections, Firestore signaling, and professional NAT traversal.
class WebRtcRoomService extends RtcRoomService with DiagnosticLogger, WidgetsBindingObserver {
  DateTime? _rtcConnectedAt;
  final FirebaseFirestore _firestore;
  final String _localUserId;
  final WebRtcLatencyTracker _latencyTracker;

  WebRtcRoomService({
    required FirebaseFirestore firestore,
    required String localUserId,
    required StreamLifecycleManager streamLifecycleManager,
    int maxMeshPeers = 6,
    List<Map<String, dynamic>>? iceServers,
    WebRtcLatencyTracker? latencyTracker,
  })  : _firestore = firestore,
        _localUserId = localUserId,
        _latencyTracker = latencyTracker ?? WebRtcLatencyTracker(),
        _productionIceServers = iceServers {
    assert(() {
      _registerFirestoreContractSignals();
      return true;
    }());
    WidgetsBinding.instance.addObserver(this);
  }

  void _registerFirestoreContractSignals() {
    final roomRef = _firestore.collection('rooms').doc('__contract_signal__');
    roomRef.collection('webrtc_peers');
    roomRef
        .collection('webrtc_calls')
        .doc('__call__')
        .collection('viewer_ice');
    roomRef
        .collection('webrtc_calls')
        .doc('__call__')
        .collection('broadcaster_ice');
  }

  bool _wasVideoActiveBeforePause = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) {
      if (state == AppLifecycleState.hidden) {
        // Prevent browser layout initialization shifts from killing the track
        if (_rtcConnectedAt != null && 
            DateTime.now().difference(_rtcConnectedAt!).inSeconds < 5) {
          _log('Ignored ghost hidden event during initialization stabilization.');
          return;
        }
        _log('App tab hidden. Suspending WebRTC tracks.');
        _wasVideoActiveBeforePause = _localVideoCapturing;
        if (_localVideoCapturing) {
          enableVideo(false).ignore();
        }
      } else if (state == AppLifecycleState.resumed) {
        if (_wasVideoActiveBeforePause) {
          _log('App tab resumed. Restoring WebRTC tracks.');
          enableVideo(true).ignore();
        }
      }
    } else {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        _log('App backgrounded. Suspending WebRTC tracks.');
        _wasVideoActiveBeforePause = _localVideoCapturing;
        if (_localVideoCapturing) {
          enableVideo(false).ignore();
        }
      } else if (state == AppLifecycleState.resumed) {
        if (_wasVideoActiveBeforePause) {
          _log('App resumed. Restoring WebRTC tracks.');
          enableVideo(true).ignore();
        }
      }
    }
  }

  // Active Peer Connections and Subscriptions
  final Map<String, RTCPeerConnection> _pcs = {};
  final Map<String, List<StreamSubscription>> _roomSubscriptions = {};
  final Map<String, List<StreamSubscription>> _peerSubscriptions = {};
  
  MediaStream? _localStream;
  MediaStream? _systemAudioStream;
  RTCVideoRenderer? _localRenderer;
  final Map<int, RTCVideoRenderer> _remoteRenderers = {};
  final Map<int, String> _uidToUserId = {};
  
  // Audio Level Monitoring (VAD)
  final Map<int, double> _remoteAudioLevels = {};
  double _localAudioLevel = 0.0;
  Timer? _audioLevelTimer;

  // Adaptive Bandwidth Monitoring & Quality Throttling
  bool _networkDegraded = false;
  int _consecutiveHighLossTicks = 0;

  final Map<String, Set<String>> _sentIceCandidateKeys = {};

  // Peers whose renegotiation was requested while signaling was not stable.
  final Set<String> _pendingRenegotiations = {};
  final Map<String, Future<void>> _signalQueues = {};
  final Map<String, List<RTCIceCandidate>> _pendingRemoteCandidates = {};
  final Map<String, int> _iceRestartAttempts = {};
  final Map<String, Timer> _iceRestartTimers = {};
  static const int _maxIceRestartAttempts = 5;

  // Production ICE Servers
  List<Map<String, dynamic>>? _productionIceServers;

  // Fallback STUN servers for local development
  static final List<Map<String, dynamic>> _defaultIceServers = [
    {
      'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'],
    },
  ];

  bool _isJoinedChannel = false;
  bool _isBroadcaster = false;
  bool _localVideoCapturing = false;
  bool _localAudioMuted = true;
  String? _currentChannelId;
  /* Unused: int? _localUid; */
  Timer? _signalingHeartbeatTimer;
  int _signalingHeartbeatFailures = 0;
  RtcConnectionState _connectionState = RtcConnectionState.idle;
  int _reconnectAttemptCount = 0;

  /// Production Initializer: Fetches TURN credentials via Cloud Function (security: prevents secret key exposure).
  /// Sprint 2 C-2 Fix: Moved from client-side HTTP to Cloud Function
  Future<void> initializeProductionNetworking() async {
    if (_productionIceServers != null && _productionIceServers!.isNotEmpty) {
      _log('✅ ICE servers already provided.');
      return;
    }

    developer.Timeline.startSync('MixVy:WebRTC:FetchTurnCredentials');
    try {
      // Call Cloud Function to fetch TURN credentials securely (secret key never leaves backend)
      final callable = FirebaseFunctions.instance.httpsCallable('generateTurnCredentials');
      final result = await callable.call<Map<String, dynamic>>().timeout(const Duration(seconds: 10));
      developer.Timeline.finishSync();

      final raw = result.data['iceServers'];
      if (raw is List && raw.isNotEmpty) {
        _productionIceServers = raw
            .whereType<Map<dynamic, dynamic>>()
            .map((entry) => entry.map((k, v) => MapEntry(k.toString(), v)))
            .toList(growable: false);
        _log('✅ Production ICE servers initialized via Cloud Function (secure)');
        return;
      }
    } catch (e) {
      _log('[WebRTC][WARN] Cloud Function error during TURN fetch: $e. Falling back to STUN.');
    } finally {
      if (_productionIceServers == null) {
        _log('[WebRTC] Initialized with STUN fallback topology.');
      }
    }
  }

  Map<String, dynamic> get _iceConfig => {
        'iceServers': (_productionIceServers != null && _productionIceServers!.isNotEmpty)
            ? _productionIceServers
            : _defaultIceServers,
        'sdpSemantics': 'unified-plan',
        'iceCandidatePoolSize': 8,
      };

  // ──────────────────────────────────────────────────────────────────────────
  // Private: Signaling Helpers
  // ──────────────────────────────────────────────────────────────────────────

  String _iceCandidateFingerprint(RTCIceCandidate candidate) {
    final raw = '${candidate.sdpMid}|${candidate.sdpMLineIndex}|${candidate.candidate}';
    return raw.hashCode.toUnsigned(32).toRadixString(16);
  }

  Future<void> _writeIceCandidate({
    required DocumentReference<Map<String, dynamic>> signalRef,
    required String subcollection,
    required RTCIceCandidate candidate,
    required String scopeKey,
    required String targetUserId,
  }) async {
    final rawCandidate = candidate.candidate;
    if (rawCandidate == null || rawCandidate.isEmpty) return;

    final fingerprint = _iceCandidateFingerprint(candidate);
    final seen = _sentIceCandidateKeys.putIfAbsent(scopeKey, () => <String>{});
    if (!seen.add(fingerprint)) return;

    try {
      await signalRef
          .collection(subcollection)
          .doc(fingerprint)
          .set({
            ...candidate.toMap(),
            'userId': _localUserId,
            'targetUserId': targetUserId,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (error) {
      seen.remove(fingerprint);
      _log('failed to write ICE candidate: $error');
    }
  }

  void _log(String message) {
    debugPrint('[WebRtcRoomService] $message');
  }

  void _setConnectionState(RtcConnectionState next) {
    if (_connectionState == next) return;
    _connectionState = next;
    onConnectionStateChanged?.call(next);
  }

  Exception _mediaAccessException(
    Object error, {
    required bool video,
    required bool audio,
  }) {
    final raw = error.toString().toLowerCase();
    final target = video && audio
        ? 'camera and microphone'
        : (video ? 'camera' : 'microphone');

    if (raw.contains('notallowederror') ||
        raw.contains('permission') ||
        raw.contains('denied')) {
      return Exception(
        '$target permission was denied. Please allow access in browser/OS settings and retry.',
      );
    }
    if (raw.contains('notfounderror') ||
        raw.contains('devicesnotfounderror') ||
        raw.contains('requested device not found')) {
      return Exception('No $target device was found on this system.');
    }
    if (raw.contains('notreadableerror') || raw.contains('trackstarterror')) {
      return Exception(
        'The $target is currently in use by another app or tab. Close it and try again.',
      );
    }
    if (raw.contains('securityerror') || raw.contains('https')) {
      return Exception(
        '$target access requires a secure origin (HTTPS or localhost).',
      );
    }
    if (raw.contains('overconstrainederror')) {
      return Exception(
        'Selected $target constraints are not supported by this device. Try default device settings.',
      );
    }
    return Exception('Unable to access $target: $error');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Public: RtcRoomService Implementation
  // ──────────────────────────────────────────────────────────────────────────

  @override
  VoidCallback? onRemoteUserJoined;
  @override
  VoidCallback? onRemoteUserLeft;
  @override
  VoidCallback? onSpeakerActivityChanged;
  @override
  VoidCallback? onLocalVideoCaptureChanged;
  @override
  VoidCallback? onTokenWillExpire;
  @override
  VoidCallback? onConnectionLost;
  @override
  ValueChanged<RtcConnectionState>? onConnectionStateChanged;

  @override
  List<int> get remoteUids => _remoteRenderers.keys.toList();
  @override
  bool get localSpeaking => _localAudioLevel > 0.05;
  @override
  bool get canRenderLocalView => _localRenderer != null && _localVideoCapturing;
  @override
  bool get isBroadcaster => _isBroadcaster;
  @override
  bool get isJoinedChannel => _isJoinedChannel;
  @override
  bool get isLocalVideoCapturing => _localVideoCapturing;
  @override
  bool get isLocalAudioMuted => _localAudioMuted;
  @override
  bool get isSharingSystemAudio => _systemAudioStream != null;

  @override
  RtcConnectionState get connectionState => _connectionState;

  @override
  int get reconnectAttemptCount => _reconnectAttemptCount;

  @override
  Future<void> shareSystemAudio(bool enabled) async {
    if (enabled) {
      try {
        _log('Starting system audio capture...');
        
        // Request display media (includes system audio option in Chrome)
        _systemAudioStream = await navigator.mediaDevices.getDisplayMedia({
          'audio': {
            'echoCancellation': false,
            'noiseSuppression': false,
            'autoGainControl': false,
          },
          'video': {
            'cursor': 'always', // Show cursor while capturing
          } // Optional: capture video too, or set to false for audio-only
        });
        
        _log('✅ System audio stream acquired');
        
        // Get the audio track
        final audioTracks = _systemAudioStream!.getAudioTracks();
        if (audioTracks.isEmpty) {
          _log('⚠️ No audio track in display media stream');
          _systemAudioStream = null;
          return;
        }
        
        final audioTrack = audioTracks.first;
        
        // Add audio track to all peer connections
        for (var entry in _pcs.entries) {
          final peerId = entry.key;
          final pc = entry.value;
          try {
            // Check if audio sender already exists
            final senders = await pc.getSenders();
            final audioSender = senders.where((s) => s.track?.kind == 'audio').firstOrNull;
            
            if (audioSender != null) {
              // Replace existing audio track
              await audioSender.replaceTrack(audioTrack);
              _log('✅ Replaced mic audio with system audio for peer: $peerId');
            } else {
              // Add new audio track
              await pc.addTrack(audioTrack, _systemAudioStream!);
              _log('✅ Added system audio track to peer: $peerId');
            }
          } catch (e) {
            _log('❌ Failed to add audio track to peer $peerId: $e');
          }
        }
        
        // Listen for stream end (user stops sharing)
        audioTrack.onEnded = () {
          _log('⚠️ User stopped screen/audio share. Cleaning up.');
          shareSystemAudio(false).ignore();
        };
        
      } catch (e) {
        _log('❌ Failed to get display media: $e');
        _systemAudioStream = null;
        rethrow;
      }
    } else {
      // Stop sharing system audio and restore mic
      try {
        if (_systemAudioStream != null) {
          _log('Stopping system audio capture...');
          for (var track in _systemAudioStream!.getTracks()) {
            track.enabled = false;
            await track.stop();
          }
          await _systemAudioStream!.dispose();
          _systemAudioStream = null;
        }
        
        // Restore original microphone audio for all peers
        if (_localStream != null) {
          final micAudioTracks = _localStream!.getAudioTracks();
          if (micAudioTracks.isNotEmpty) {
            final micAudioTrack = micAudioTracks.first;
            
            for (var entry in _pcs.entries) {
              final peerId = entry.key;
              final pc = entry.value;
              try {
                final senders = await pc.getSenders();
                final audioSender = senders.where((s) => s.track?.kind == 'audio').firstOrNull;
                
                if (audioSender != null) {
                  await audioSender.replaceTrack(micAudioTrack);
                  _log('✅ Restored microphone audio for peer: $peerId');
                }
              } catch (e) {
                _log('Failed to restore mic audio for peer $peerId: $e');
              }
            }
          }
        }
        
        _log('✅ System audio sharing stopped');
      } catch (e) {
        _log('Error stopping system audio sharing: $e');
      }
    }
  }

  @override
  bool isRemoteSpeaking(int uid) => (_remoteAudioLevels[uid] ?? 0.0) > 0.05;
  @override
  String? userIdForUid(int uid) => _uidToUserId[uid];
  @override
  double get localAudioLevel => _localAudioLevel;
  @override
  double remoteAudioLevelForUid(int uid) => _remoteAudioLevels[uid] ?? 0.0;

  @override
  Widget getLocalView() {
    final renderer = _localRenderer;
    if (renderer == null) return const SizedBox.shrink();
    return RTCVideoView(renderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover);
  }
  
  @override
  Widget getRemoteView(int uid, String channelId) {
    final renderer = _remoteRenderers[uid];
    if (renderer == null) return const SizedBox.shrink();
    return RTCVideoView(renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover);
  }

  @override
  Future<void> initialize(String appId) async {
    await initializeProductionNetworking();
  }

  @override
  Future<void> joinRoom(
    String token,
    String channelName,
    int uid, {
    bool publishCameraTrackOnJoin = false,
    bool publishMicrophoneTrackOnJoin = false,
  }) async {
    _log('Joining room signaling: $channelName as $uid');
    _currentChannelId = channelName;
/* Unused: /* Deprecated/Unused:     _localUid = uid; */ */
    _isJoinedChannel = true;
    _setConnectionState(RtcConnectionState.connecting);
    
    // Register participant in the signaling session
    final sessionRef = _firestore.collection('webrtc_sessions').doc(channelName);
    await sessionRef.set({
      'updatedAt': FieldValue.serverTimestamp(),
      'active': true,
    }, SetOptions(merge: true));

    await sessionRef.collection('participants').doc(_localUserId).set({
      'uid': uid,
      'lastSeen': FieldValue.serverTimestamp(),
      'isBroadcasting': publishCameraTrackOnJoin,
    });

    // BACKGROUND PRUNE: Purge stale signaling participants (older than 60 seconds) on join
    unawaited(Future(() async {
      try {
        final now = DateTime.now();
        final staleThreshold = now.subtract(const Duration(seconds: 60));
        final participantsQuery = await sessionRef.collection('participants').get();
        for (var doc in participantsQuery.docs) {
          final pId = doc.id;
          if (pId == _localUserId) continue;

          final data = doc.data();
          final lastSeenTimestamp = data['lastSeen'] as Timestamp?;
          if (lastSeenTimestamp != null) {
            final lastSeen = lastSeenTimestamp.toDate();
            if (lastSeen.isBefore(staleThreshold)) {
              _log('Purging stale/ghost signaling participant: $pId (last seen: $lastSeen)');
              await doc.reference.delete();
              
              // Also clean up any stale signaling or candidates for this ghost user
              final signalDocId = _signalingDocId(_localUserId, pId);
              await sessionRef.collection('signaling').doc(signalDocId).delete();
              
              final candidates = await sessionRef.collection('candidates').where('userId', isEqualTo: pId).get();
              for (var cDoc in candidates.docs) {
                await cDoc.reference.delete();
              }
            }
          }
        }
      } catch (e) {
        _log('Failed to prune stale signaling participants: $e');
      }
    }));

    _startSignalingHeartbeat();
    _startAudioLevelMonitoring();
    _subscribeToParticipants(channelName);
    _setConnectionState(RtcConnectionState.connected);

    if (publishCameraTrackOnJoin || publishMicrophoneTrackOnJoin) {
      await enableVideo(publishCameraTrackOnJoin, publishMicrophoneTrack: publishMicrophoneTrackOnJoin);
    }
  }

  void _startAudioLevelMonitoring() {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!_isJoinedChannel) {
        timer.cancel();
        return;
      }

      // Monitor Remote Audio Levels via RTC Stats
      for (var entry in _pcs.entries) {
        final pc = entry.value;
        final peerId = entry.key;
        final uid = _stableUid(peerId);

        try {
          final stats = await pc.getStats();
          for (var stat in stats) {
            if (stat.type == 'media-source' && stat.values['kind'] == 'audio') {
              _localAudioLevel = (stat.values['audioLevel'] as num?)?.toDouble() ?? 0.0;
            }
            if (stat.type == 'inbound-rtp' && stat.values['kind'] == 'audio') {
              final level = (stat.values['audioLevel'] as num?)?.toDouble() ?? 0.0;
              _remoteAudioLevels[uid] = level;
            }
          }
        } catch (e) {
          // Stats might fail during connection transition state parameters
        }
      }
      
      if (_pcs.isEmpty) {
        _localAudioLevel = 0.0;
        _remoteAudioLevels.clear();
      }
      
      onSpeakerActivityChanged?.call();
      _monitorNetworkMetrics().ignore();
    });
  }

  void _startSignalingHeartbeat() {
    _signalingHeartbeatTimer?.cancel();
    _signalingHeartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_isJoinedChannel || _currentChannelId == null) {
        timer.cancel();
        return;
      }
      
      try {
        final sessionRef = _firestore.collection('webrtc_sessions').doc(_currentChannelId);
        await sessionRef.collection('participants').doc(_localUserId).update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
        
        await sessionRef.update({
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _signalingHeartbeatFailures = 0;
      } catch (e) {
        _log('Signaling heartbeat failed: $e');
        _signalingHeartbeatFailures++;
        if (_signalingHeartbeatFailures >= 3) {
          _attemptSignalingRecovery().ignore();
        }
      }
    });
  }

  Future<void> _attemptSignalingRecovery() async {
    if (!_isJoinedChannel || _currentChannelId == null) return;
    if (_connectionState == RtcConnectionState.reconnecting) return;
    _signalingHeartbeatFailures = 0;
    _reconnectAttemptCount++;
    _setConnectionState(RtcConnectionState.reconnecting);

    try {
      final sessionRef = _firestore.collection('webrtc_sessions').doc(_currentChannelId);
      await sessionRef.set({
        'updatedAt': FieldValue.serverTimestamp(),
        'active': true,
      }, SetOptions(merge: true));

      await sessionRef.collection('participants').doc(_localUserId).set({
        'uid': _stableUid(_localUserId),
        'lastSeen': FieldValue.serverTimestamp(),
        'isBroadcasting': _localVideoCapturing,
      }, SetOptions(merge: true));

      _reconnectAttemptCount = 0;
      _setConnectionState(RtcConnectionState.connected);
    } catch (e) {
      _log('Signaling recovery failed: $e');
      _setConnectionState(RtcConnectionState.failed);
      onConnectionLost?.call();
    }
  }

  void _subscribeToParticipants(String roomId) {
    final subs = _roomSubscriptions.putIfAbsent(roomId, () => []);
    subs.add(_firestore
        .collection('webrtc_sessions')
        .doc(roomId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final userId = change.doc.id;
        if (userId == _localUserId) continue;

        if (change.type == DocumentChangeType.added) {
          _log('New peer detected: $userId. Establishing connection.');
          final isOfferer = _localUserId.compareTo(userId) < 0;
          _setupPC(userId, roomId, isOfferer).ignore();
        } else if (change.type == DocumentChangeType.removed) {
          _log('Peer left: $userId. Cleaning up.');
          _cleanupPeer(userId).ignore();
        }
      }
    }, onError: (Object e) => _onListenerError(roomId, 'participants', e)));
  }

  void _onListenerError(String roomId, String source, Object error) {
    _log('❌ $source listener failed for room $roomId: $error');
    _setConnectionState(RtcConnectionState.failed);
    onConnectionLost?.call();
  }

  Future<void> _cleanupPeer(String userId) async {
    final uid = _stableUid(userId);

    final peerSubs = _peerSubscriptions.remove(userId);
    _pendingRenegotiations.remove(userId);
    _iceRestartTimers.remove(userId)?.cancel();
    _iceRestartAttempts.remove(userId);
    _pendingRemoteCandidates.remove(userId);
    _signalQueues.remove(userId);
    if (peerSubs != null) {
      for (final sub in peerSubs) {
        await sub.cancel();
      }
    }
    
    // 1. Remove peer connection first
    final pc = _pcs.remove(userId);
    if (pc != null) {
      await pc.close();
      await pc.dispose();
    }
    
    // 2. Snapshot the renderer before disposal (prevents deactivated widget exceptions)
    final renderer = _remoteRenderers.remove(uid);
    
    // 3. Clear all references
    _uidToUserId.remove(uid);
    _remoteAudioLevels.remove(uid);
    
    // 4. Remove ICE candidate fingerprints for this peer
    if (_currentChannelId != null) {
      final scopeKey = '$_currentChannelId:$userId';
      _sentIceCandidateKeys.remove(scopeKey);
    }
    
    // 5. Trigger UI rebuild callback BEFORE renderer disposal
    onRemoteUserLeft?.call();
    
    // 6. Finally, dispose renderer after callback completes
    if (renderer != null) {
      renderer.srcObject = null;
      await renderer.dispose();
    }
  }

  Future<void> _setupPC(String peerId, String roomId, bool isOfferer) async {
    if (_pcs.containsKey(peerId)) return;

    developer.Timeline.startSync('MixVy:WebRTC:SetupPC', arguments: {'peerId': peerId, 'isOfferer': isOfferer});
    
    // Start latency tracking for this peer
    _latencyTracker.startSignalingTimer(peerId);
    
    final pc = await createPeerConnection(_iceConfig);
    _pcs[peerId] = pc;
    _uidToUserId[_stableUid(peerId)] = peerId;

    _setupIceConnectionStateListener(pc, peerId);

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }
    // Negotiate a video m-line up front so a camera turned on later can use replaceTrack.
    // A sender with no track at answer time is negotiated as recvonly, so enableVideo
    // renegotiates (see _renegotiate) once a track is attached.
    if (await _videoTransceiver(pc) == null) {
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
    }

    pc.onIceCandidate = (candidate) {
      _writeIceCandidate(
        signalRef: _firestore.collection('webrtc_sessions').doc(roomId),
        subcollection: 'candidates',
        candidate: candidate,
        scopeKey: '$roomId:$peerId',
        targetUserId: peerId,
      ).ignore();
    };

    pc.onTrack = (event) async {
      // A video sender that starts without a track has no stream id, so wrap its track.
      MediaStream? stream;
      if (event.streams.isNotEmpty) {
        stream = event.streams[0];
      } else if (event.track.kind == 'video') {
        stream = await createLocalMediaStream('remote_$peerId');
        await stream.addTrack(event.track);
      }
      if (stream != null) {
        final uid = _stableUid(peerId);

        final existingRenderer = _remoteRenderers[uid];
        if (existingRenderer != null &&
            identical(existingRenderer.srcObject, stream)) {
          onRemoteUserJoined?.call();
          return;
        }

        final oldRenderer = _remoteRenderers.remove(uid);
        if (oldRenderer != null) {
          oldRenderer.srcObject = null;
          await oldRenderer.dispose();
        }
        
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = stream;
        _remoteRenderers[uid] = renderer;
        onRemoteUserJoined?.call();
      }
    };

    if (isOfferer) {
      try {
        await _clearSignalMessages(roomId, peerId);
      } catch (e) {
        _log('⚠️ Failed to clear stale signaling messages for $peerId: $e');
      }
    }

    // Each signal is a separate message so offers, answers and renegotiations are never overwritten.
    final peerSubs = _peerSubscriptions.putIfAbsent(peerId, () => []);
    peerSubs.add(_signalMessages(roomId, peerId)
        .orderBy('timestamp')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final doc = change.doc;
        final data = doc.data();
        if (data == null || data['senderId'] == _localUserId) continue;
        _enqueueSignal(peerId, () async {
          try {
            await _applySignal(pc, roomId, peerId, data);
          } finally {
            await doc.reference.delete();
          }
        });
      }
    }, onError: (Object e) => _onListenerError(roomId, 'signaling', e)));

    // Listen for ICE candidates
    peerSubs.add(_firestore
        .collection('webrtc_sessions')
        .doc(roomId)
        .collection('candidates')
        .where('userId', isEqualTo: peerId)
        .snapshots()
        .listen((snap) {
      final now = DateTime.now();
      final maxCandidateAge = Duration(seconds: 20);
      int staleCandidatesSkipped = 0;
      
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final targetUserId = data['targetUserId']?.toString();
            if (targetUserId != null &&
                targetUserId.isNotEmpty &&
                targetUserId != _localUserId) {
              continue;
            }

            // Check candidate age: skip stale candidates older than 20 seconds
            final createdAt = (data['timestamp'] as Timestamp?)?.toDate();
            if (createdAt != null && now.difference(createdAt) > maxCandidateAge) {
              staleCandidatesSkipped++;
              _log('⏭️ Skipping stale ICE candidate for $peerId (age: ${now.difference(createdAt).inSeconds}s)');
              continue;
            }
            
            try {
              final candidate = RTCIceCandidate(
                data['candidate']?.toString(),
                data['sdpMid']?.toString(),
                data['sdpMLineIndex'] as int?,
              );
              
              _enqueueSignal(peerId, () => _addRemoteCandidate(pc, peerId, candidate));
              _log('✅ Queued ICE candidate for peer: $peerId');
            } catch (e) {
              _log('⚠️ Failed to add ICE candidate for $peerId: $e. Connection state: ${pc.connectionState}');
            }
          }
        }
      }
      
      if (staleCandidatesSkipped > 0) {
        _log('📊 Skipped $staleCandidatesSkipped stale ICE candidates for $peerId in this batch');
      }
    }, onError: (Object e) => _onListenerError(roomId, 'candidates', e)));

    if (isOfferer) {
      // Sprint 2 B-2 Fix: Add safeguard to ensure only deterministic offerer sends offer
      // Verify local user ID is lexicographically smaller than peer ID
      if (_localUserId.compareTo(peerId) >= 0) {
        _log('❌ LOGIC ERROR: Non-offerer tried to send offer! localUserId=$_localUserId, peerId=$peerId');
        return;
      }
      
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      
      await _sendSignal(roomId, peerId, 'offer', offer.sdp ?? '');
      
      _latencyTracker.recordOfferAnswerSent(peerId, 'offer');
    }
    developer.Timeline.finishSync();
  }

  Future<RTCRtpTransceiver?> _videoTransceiver(RTCPeerConnection pc) async {
    for (final transceiver in await pc.getTransceivers()) {
      if (transceiver.receiver.track?.kind == 'video') return transceiver;
    }
    return null;
  }

  // Sends a new offer over the existing pair signaling doc so the remote side
  // learns about a track that was attached after the initial negotiation.
  Future<void> _renegotiate(String peerId, RTCPeerConnection pc) async {
    final roomId = _currentChannelId;
    if (roomId == null) return;
    if (pc.signalingState != RTCSignalingState.RTCSignalingStateStable) {
      _log('Renegotiation queued for $peerId: signaling state is ${pc.signalingState}');
      _pendingRenegotiations.add(peerId);
      return;
    }
    _pendingRenegotiations.remove(peerId);

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await _sendSignal(roomId, peerId, 'offer', offer.sdp ?? '');
    _log('Sent renegotiation offer to $peerId');
  }

  CollectionReference<Map<String, dynamic>> _signalMessages(String roomId, String peerId) {
    return _firestore
        .collection('webrtc_sessions')
        .doc(roomId)
        .collection('signaling')
        .doc(_signalingDocId(_localUserId, peerId))
        .collection('messages');
  }

  Future<void> _sendSignal(String roomId, String peerId, String type, String sdp) async {
    await _signalMessages(roomId, peerId).add({
      'senderId': _localUserId,
      'type': type,
      'sdp': sdp,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Removes leftovers from an earlier session so a stale offer or answer is never replayed.
  Future<void> _clearSignalMessages(String roomId, String peerId) async {
    final snap = await _signalMessages(roomId, peerId).get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Runs signaling work for one peer strictly in arrival order.
  void _enqueueSignal(String peerId, Future<void> Function() task) {
    final previous = _signalQueues[peerId] ?? Future<void>.value();
    _signalQueues[peerId] = previous.then((_) => task()).catchError((Object e) {
      _log('⚠️ Signaling step failed for $peerId: $e');
    });
  }

  Future<void> _applySignal(
    RTCPeerConnection pc,
    String roomId,
    String peerId,
    Map<String, dynamic> data,
  ) async {
    final type = data['type'] as String;
    final sdp = data['sdp'] as String;

    _latencyTracker.recordRemoteDescriptionReceived(peerId, type);

    // Offers are accepted whenever the connection is stable, so either side can
    // renegotiate (e.g. a camera turned on after the initial answer was sent).
    if (type == 'offer') {
      if (pc.signalingState != RTCSignalingState.RTCSignalingStateStable) {
        _log('⚠️ Ignoring offer while signaling state is ${pc.signalingState} (peerId=$peerId)');
        return;
      }
      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
      _latencyTracker.recordRemoteDescriptionApplied(peerId);
      await _flushPendingCandidates(pc, peerId);

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      await _sendSignal(roomId, peerId, 'answer', answer.sdp ?? '');
      _latencyTracker.recordOfferAnswerSent(peerId, 'answer');
      if (_pendingRenegotiations.contains(peerId)) {
        await _renegotiate(peerId, pc);
      }
    } else if (type == 'answer') {
      // Only an answer to our own pending offer can be applied. Stale answers are ignored.
      if (pc.signalingState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        _log('⚠️ Ignoring answer while signaling state is ${pc.signalingState} (peerId=$peerId)');
        return;
      }
      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
      _latencyTracker.recordRemoteDescriptionApplied(peerId);
      await _flushPendingCandidates(pc, peerId);
      if (_pendingRenegotiations.contains(peerId)) {
        await _renegotiate(peerId, pc);
      }
    }
  }

  // Candidates that arrive before the remote description are held until it is set.
  Future<void> _addRemoteCandidate(RTCPeerConnection pc, String peerId, RTCIceCandidate candidate) async {
    final remote = await pc.getRemoteDescription();
    if (remote == null) {
      _pendingRemoteCandidates.putIfAbsent(peerId, () => []).add(candidate);
      return;
    }
    await pc.addCandidate(candidate);
  }

  Future<void> _flushPendingCandidates(RTCPeerConnection pc, String peerId) async {
    final pending = _pendingRemoteCandidates.remove(peerId);
    if (pending == null) return;
    for (final candidate in pending) {
      try {
        await pc.addCandidate(candidate);
      } catch (e) {
        _log('⚠️ Failed to add buffered ICE candidate for $peerId: $e');
      }
    }
  }

  Duration _iceRestartBackoff(String peerId) {
    final attempts = _iceRestartAttempts[peerId] ?? 0;
    return Duration(seconds: attempts >= 5 ? 30 : (1 << attempts));
  }

  // Only the deterministic offerer restarts ICE, so the two sides never restart at once.
  void _scheduleIceRestart(String peerId, {required Duration delay}) {
    if (_localUserId.compareTo(peerId) >= 0) return;
    if (_iceRestartTimers.containsKey(peerId)) return;
    final attempts = _iceRestartAttempts[peerId] ?? 0;
    if (attempts >= _maxIceRestartAttempts) {
      _log('❌ ICE restart limit reached for $peerId');
      _setConnectionState(RtcConnectionState.failed);
      onConnectionLost?.call();
      return;
    }
    _setConnectionState(RtcConnectionState.degraded);
    _iceRestartTimers[peerId] = Timer(delay, () {
      _iceRestartTimers.remove(peerId);
      _restartIce(peerId).ignore();
    });
  }

  Future<void> _restartIce(String peerId) async {
    final pc = _pcs[peerId];
    if (pc == null || !_isJoinedChannel || _currentChannelId == null) return;
    final state = pc.iceConnectionState;
    if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
      return;
    }

    final attempt = (_iceRestartAttempts[peerId] ?? 0) + 1;
    _iceRestartAttempts[peerId] = attempt;
    _log('🔁 ICE restart $attempt/$_maxIceRestartAttempts for $peerId');
    try {
      await pc.restartIce();
      await _renegotiate(peerId, pc);
    } catch (e) {
      _log('ICE restart failed for $peerId: $e');
      _scheduleIceRestart(peerId, delay: _iceRestartBackoff(peerId));
    }
  }

  String _signalingDocId(String id1, String id2) {
    final list = [id1, id2]..sort();
    return '${list[0]}_${list[1]}';
  }

  @override
  Future<void> enableVideo(bool enabled, {bool publishMicrophoneTrack = true}) async {
    _log('enableVideo: $enabled');
    if (enabled) {
      if (_localStream == null) {
        final Map<String, dynamic> constraints = {
          'audio': publishMicrophoneTrack,
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
          },
        };
        try {
          _localStream = await navigator.mediaDevices.getUserMedia(constraints);
          _log('Successfully acquired local stream.');
        } catch (e) {
          _log('Failed to get user media with constraints, trying fallback: $e');
          try {
            _localStream = await navigator.mediaDevices.getUserMedia({
              'audio': publishMicrophoneTrack,
              'video': true,
            });
          } catch (fallbackError) {
            throw _mediaAccessException(
              fallbackError,
              video: true,
              audio: publishMicrophoneTrack,
            );
          }
        }
      } else {
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isEmpty || videoTracks.any((t) => t.enabled == false)) {
          _log('Video track missing or ended. Re-acquiring...');
          final videoStream = await navigator.mediaDevices.getUserMedia({'video': true});
          final newTrack = videoStream.getVideoTracks().first;
          await _localStream!.addTrack(newTrack);
        } else {
          for (var t in videoTracks) { t.enabled = true; }
        }
      }
      
      if (_localRenderer == null) {
        _localRenderer = RTCVideoRenderer();
        await _localRenderer!.initialize();
      }
      
      // Explicitly enable all video tracks before rendering
      // This prevents the "lens covered" state that occurs when tracks are disabled
      final videoTracks = _localStream!.getVideoTracks();
      _log('Enabling ${videoTracks.length} video track(s) for rendering...');
      for (final track in videoTracks) {
        track.enabled = true;
      }
      
      // Set the stream on the renderer
      _localRenderer!.srcObject = _localStream;
      _log('Stream attached to local renderer');
      
      // Critical: Wait for browser to properly attach the video stream to the DOM element
      // Without this delay, the renderer shows "lens covered" state on initial attach
      // because the browser hasn't finished initializing the video playback pipeline.
      // This 100ms is essential for Chrome/Firefox/Safari to initialize the video element.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      _log('Video renderer initialization complete - camera should now display');
      
      // Force the renderer to refresh by triggering a rebuild notification
      // This ensures the RTCVideoView immediately reflects the new stream
      onLocalVideoCaptureChanged?.call();
      
      _localVideoCapturing = true;
      _isBroadcaster = true;
      _localAudioMuted = !publishMicrophoneTrack;
      _log('Local video capture enabled and publishing to peers');

      final videoTrack = _localStream?.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        for (var entry in _pcs.entries) {
          final pc = entry.value;
          final videoTransceiver = await _videoTransceiver(pc);
          if (videoTransceiver != null) {
            await videoTransceiver.sender.replaceTrack(videoTrack);
          } else {
            await pc.addTrack(videoTrack, _localStream!);
          }
          // The remote answer was negotiated without this track, so offer again.
          await _renegotiate(entry.key, pc);
        }
      }
    } else {
      _localVideoCapturing = false;
      _localRenderer?.srcObject = null;
      
      final videoTracks = _localStream?.getVideoTracks();
      if (videoTracks != null) {
        for (var track in videoTracks) {
          track.enabled = false;
          await track.stop();
          await _localStream?.removeTrack(track);
        }
      }

      if (_localAudioMuted) {
        _localStream?.getTracks().forEach((t) => t.stop());
        _localStream = null;
      }
    }
    onLocalVideoCaptureChanged?.call();
  }

  @override
  Future<void> mute(bool muted) async {
    _log('mute: $muted');
    _localAudioMuted = muted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !muted;
    });
    onSpeakerActivityChanged?.call();
  }

  @override
  Future<void> setBroadcaster(bool enabled) async {
    _isBroadcaster = enabled;
  }

  @override
  Future<void> publishLocalVideoStream(bool enabled) async {
    await enableVideo(enabled, publishMicrophoneTrack: !_localAudioMuted);
  }

  @override
  Future<void> publishLocalAudioStream(bool enabled) async {
    await mute(!enabled);
  }

  @override
  Future<void> setRemoteVideoSubscription(
    int uid, {
    required bool subscribe,
    bool highQuality = false,
  }) async {
    final renderer = _remoteRenderers[uid];
    if (renderer != null) {
      renderer.srcObject?.getVideoTracks().forEach((track) {
        track.enabled = _networkDegraded ? false : subscribe;
      });
    }
  }

  @override
  Future<void> setEncodingQuality(bool highQuality) async {
    _log('setEncodingQuality: highQuality=$highQuality');
    for (var pc in _pcs.values) {
      final senders = await pc.getSenders();
      for (var sender in senders) {
        if (sender.track?.kind == 'video') {
          try {
            final parameters = sender.parameters;
            if (parameters.encodings != null && parameters.encodings!.isNotEmpty) {
              for (var encoding in parameters.encodings!) {
                if (highQuality) {
                  encoding.maxBitrate = 1500000; 
                  encoding.maxFramerate = 30;
                  encoding.scaleResolutionDownBy = 1.0;
                } else {
                  encoding.maxBitrate = 300000; 
                  encoding.maxFramerate = 15;
                  encoding.scaleResolutionDownBy = 2.0; 
                }
              }
              await sender.setParameters(parameters);
              _log('Successfully updated encoding parameters for highQuality=$highQuality');
            }
          } catch (e) {
            _log('Failed to set encoding parameters: $e');
          }
        }
      }
    }
  }

  Future<void> _monitorNetworkMetrics() async {
    if (!_isJoinedChannel || _pcs.isEmpty) return;
    
    double totalPacketsLost = 0;
    double totalPacketsReceived = 0;
    double maxRtt = 0.0;
    
    for (var pc in _pcs.values) {
      try {
        final stats = await pc.getStats();
        for (var stat in stats) {
          if (stat.type == 'inbound-rtp') {
            totalPacketsLost += (stat.values['packetsLost'] as num?)?.toDouble() ?? 0.0;
            totalPacketsReceived += (stat.values['packetsReceived'] as num?)?.toDouble() ?? 0.0;
          }
          if (stat.type == 'candidate-pair' && stat.values['state'] == 'succeeded') {
            final rtt = (stat.values['currentRoundTripTime'] as num?)?.toDouble() ?? 0.0;
            if (rtt > maxRtt) maxRtt = rtt;
          }
        }
      } catch (_) {}
    }
    
    double lossRatio = 0.0;
    if (totalPacketsReceived > 0) {
      lossRatio = totalPacketsLost / (totalPacketsLost + totalPacketsReceived);
    }
    
    final bool isLossDegraded = lossRatio > 0.05;
    final bool isRttDegraded = maxRtt > 0.4;
    
    if (isLossDegraded || isRttDegraded) {
      _consecutiveHighLossTicks++;
    } else {
      _consecutiveHighLossTicks = 0;
    }
    
    if (_consecutiveHighLossTicks >= 3 && !_networkDegraded) {
      _networkDegraded = true;
      _log('⚠️ High network degradation detected. Throttling bitrates.');
      await _applyAdaptiveBandwidthLimits();
    } else if (_consecutiveHighLossTicks == 0 && _networkDegraded) {
      _networkDegraded = false;
      _log('✅ Network conditions recovered. Restoring streams.');
      await _applyAdaptiveBandwidthLimits();
    }
  }

  Future<void> _applyAdaptiveBandwidthLimits() async {
    for (var pc in _pcs.values) {
      final senders = await pc.getSenders();
      for (var sender in senders) {
        if (sender.track?.kind == 'video') {
          try {
            final parameters = sender.parameters;
            if (parameters.encodings != null && parameters.encodings!.isNotEmpty) {
              for (var encoding in parameters.encodings!) {
                if (_networkDegraded) {
                  encoding.maxBitrate = 100000; 
                  encoding.maxFramerate = 8;    
                  encoding.scaleResolutionDownBy = 4.0; 
                } else {
                  encoding.maxBitrate = 300000; 
                  encoding.maxFramerate = 15;
                  encoding.scaleResolutionDownBy = 2.0; 
                }
              }
              await sender.setParameters(parameters);
            }
          } catch (e) {
            _log('Failed to apply adaptive bandwidth limits: $e');
          }
        }
      }
    }
    
    for (var entry in _remoteRenderers.entries) {
      final renderer = entry.value;
      renderer.srcObject?.getVideoTracks().forEach((track) {
        track.enabled = !_networkDegraded;
      });
    }
  }

  @override
  Future<void> renewToken(String newToken) async {}

  @override
  Future<void> reconnect() async {
    // Only the offerer side of each pair can renegotiate ICE, so answerers rely on their peer.
    _log('reconnect() requested; restarting ICE for offerer-side peers');
    for (final peerId in _pcs.keys.toList()) {
      if (_localUserId.compareTo(peerId) >= 0) continue;
      _iceRestartTimers.remove(peerId)?.cancel();
      _iceRestartAttempts.remove(peerId);
      await _restartIce(peerId);
    }
  }

  @override
  Future<void> abortReconnection() async {
    // No-op for WebRTC.
    _log('abortReconnection() called (no-op for WebRTC)');
    logInfo('Abort reconnection requested for WebRTC service');
  }

  @override
  Future<void> setMicVolume(double volume) async {}
  @override
  Future<void> setSpeakerVolume(double volume) async {}

  @override
  Future<void> ensureDeviceAccess({required bool video, required bool audio}) async {
    _log('Ensuring device access: video=$video, audio=$audio');
    try {
      final Map<String, dynamic> constraints = {
        'audio': audio,
        'video': video ? {'facingMode': 'user'} : false,
      };
      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      for (var track in stream.getTracks()) {
        await track.stop();
      }
    } catch (e) {
      _log('Device access denied: $e');
      throw _mediaAccessException(e, video: video, audio: audio);
    }
  }

  @override
  Future<void> dispose() async {
    await disposeAll();
  }

  Future<void> disposeAll() async {
    _log('Disposing WebRtcRoomService');
    _setConnectionState(RtcConnectionState.idle);
    _reconnectAttemptCount = 0;
    _signalingHeartbeatFailures = 0;
    WidgetsBinding.instance.removeObserver(this);
    for (final timer in _iceRestartTimers.values) {
      timer.cancel();
    }
    _iceRestartTimers.clear();
    _iceRestartAttempts.clear();
    _pendingRemoteCandidates.clear();
    _signalQueues.clear();

    _signalingHeartbeatTimer = null;
    _audioLevelTimer?.cancel();
    _audioLevelTimer = null;
    
    // Clean up latency tracking
    _latencyTracker.reset();
    
    if (_currentChannelId != null) {
      try {
        final sessionRef = _firestore.collection('webrtc_sessions').doc(_currentChannelId);
        await sessionRef.collection('participants').doc(_localUserId).delete();
        
        final candidates = await sessionRef.collection('candidates').where('userId', isEqualTo: _localUserId).get();
        for (var doc in candidates.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        _log('Failed to clean up signaling: $e');
      }
    }

    for (var subs in _roomSubscriptions.values) {
      for (var sub in subs) {
        await sub.cancel();
      }
    }
    _roomSubscriptions.clear();

    for (var subs in _peerSubscriptions.values) {
      for (var sub in subs) {
        await sub.cancel();
      }
    }
    _peerSubscriptions.clear();

    for (var pc in _pcs.values) {
      await pc.close();
      await pc.dispose();
    }
    _pcs.clear();
    
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        track.enabled = false;
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    if (_systemAudioStream != null) {
      for (var track in _systemAudioStream!.getTracks()) {
        track.enabled = false;
        await track.stop();
      }
      await _systemAudioStream!.dispose();
      _systemAudioStream = null;
    }

    if (_localRenderer != null) {
      _localRenderer!.srcObject = null;
      await _localRenderer!.dispose();
      _localRenderer = null;
    }

    for (var renderer in _remoteRenderers.values) {
      renderer.srcObject = null;
      await renderer.dispose();
    }
    _remoteRenderers.clear();
  }

  void _setupIceConnectionStateListener(RTCPeerConnection pc, String peerId) {
    pc.onIceConnectionState = (RTCIceConnectionState state) {
      _log('ICE Connection State changed for $peerId: $state');
      
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          // Record when peer connection is established
          _latencyTracker.recordPeerConnectionEstablished(peerId);
          _iceRestartTimers.remove(peerId)?.cancel();
          _iceRestartAttempts.remove(peerId);
          _setConnectionState(RtcConnectionState.connected);
          _reconnectAttemptCount = 0;
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          // Disconnected often recovers on its own, so wait before restarting ICE.
          _log('⚠️ Connection for $peerId disconnected. Waiting for recovery...');
          _scheduleIceRestart(peerId, delay: const Duration(seconds: 5));
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _log('❌ Connection for $peerId failed.');
          if (_localUserId.compareTo(peerId) < 0) {
            _scheduleIceRestart(peerId, delay: _iceRestartBackoff(peerId));
          } else {
            // The answerer cannot restart ICE itself; the offerer drives recovery.
            _latencyTracker.recordPeerConnectionClosed(peerId);
            _setConnectionState(RtcConnectionState.failed);
            onConnectionLost?.call();
          }
          break;
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          _log('Connection for $peerId closed.');
          _latencyTracker.recordPeerConnectionClosed(peerId);
          if (_pcs.isEmpty) {
            _setConnectionState(RtcConnectionState.idle);
          }
          break;
        default:
          break;
      }
    };
  }

  static int _stableUid(String userId) {
    int h = 0;
    for (final c in userId.codeUnits) { h = (h * 31 + c) & 0x7FFFFFFF; }
    return h == 0 ? 1 : h;
  }

  // --- 1-to-1 Compatibility Methods (Phase 2 Legacy) ---

  Future<String> createRoom(MediaStream localStream, void Function(MediaStream) onRemoteStream) async {
    final roomId = _firestore.collection('webrtc_sessions').doc().id;
    _localStream = localStream;
    onRemoteUserJoined = () {
      if (_remoteRenderers.isNotEmpty) {
        onRemoteStream(_remoteRenderers.values.first.srcObject!);
      }
    };
    await joinRoom('', roomId, _stableUid(_localUserId), publishCameraTrackOnJoin: true);
    return roomId;
  }

  Future<void> joinRoomById(
    String roomId, 
    MediaStream localStream, [
    void Function(MediaStream)? onRemoteStream,
  ]) async {
    _localStream = localStream;
    if (onRemoteStream != null) {
      onRemoteUserJoined = () {
        if (_remoteRenderers.isNotEmpty) {
          onRemoteStream(_remoteRenderers.values.first.srcObject!);
        }
      };
    }
    await joinRoom('', roomId, _stableUid(_localUserId), publishCameraTrackOnJoin: true);
  }
}





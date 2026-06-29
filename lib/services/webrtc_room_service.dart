import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';
import '../config/app_env.dart';
import 'dart:developer' as developer;
import 'package:mixvy/services/rtc_room_service.dart';
import '../core/streams/stream_lifecycle_manager.dart';
import '../observability/webrtc_latency_tracker.dart';

/// WebRtcRoomService
/// 
/// The production-hardened engine for MixVy's real-time communication.
/// Manages peer connections, Firestore signaling, and professional NAT traversal.
class WebRtcRoomService extends RtcRoomService with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
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
  
  MediaStream? _localStream;
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

  /// Production Initializer: Fetches TURN credentials to bypass public firewalls.
  Future<void> initializeProductionNetworking() async {
    if (_productionIceServers != null && _productionIceServers!.isNotEmpty) {
      _log('✅ ICE servers already provided.');
      return;
    }

    final String secretKey = AppEnv.meteredSecretKey;
    if (secretKey.isEmpty) {
      _log('⚠️ Metered Secret Key is empty. Skipping production networking setup.');
      return;
    }

    final String domain = AppEnv.meteredDomain;
    final String url = "https://$domain/api/v1/turn/credential${secretKey.isNotEmpty ? '?secretKey=$secretKey' : ''}";

    developer.Timeline.startSync('MixVy:WebRTC:FetchTurnCredentials');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "expiryInSeconds": 3600,
          "label": "mixvy-prod-session"
        }),
      ).timeout(const Duration(seconds: 10));
      developer.Timeline.finishSync();

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final username = data['username']?.toString();
          final password = data['password']?.toString();
          
          if (username != null && password != null) {
            _productionIceServers = [
              {'urls': 'stun:stun.l.google.com:19302'},
              {
                'urls': 'turn:open.metered.ca:443',
                'username': username,
                'credential': password,
              }
            ];
            _log('✅ Production ICE servers initialized successfully');
            return;
          }
        }
      }
    } catch (e) {
      _log('[WebRTC][WARN] Networking error during TURN fetch: $e. Falling back to STUN.');
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
  bool get isSharingSystemAudio => false;

  @override
  Future<void> shareSystemAudio(bool enabled) async {}

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
      } catch (e) {
        _log('Signaling heartbeat failed: $e');
      }
    });
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
          _cleanupPeer(userId);
        }
      }
    }));
  }

  void _cleanupPeer(String userId) {
    final uid = _stableUid(userId);
    _pcs.remove(userId)?.dispose();
    _remoteRenderers.remove(uid)?.dispose();
    _uidToUserId.remove(uid);
    _remoteAudioLevels.remove(uid);
    onRemoteUserLeft?.call();
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

    pc.onIceCandidate = (candidate) {
      _writeIceCandidate(
        signalRef: _firestore.collection('webrtc_sessions').doc(roomId),
        subcollection: 'candidates',
        candidate: candidate,
        scopeKey: '$roomId:$peerId',
      ).ignore();
    };

    pc.onTrack = (event) async {
      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        final uid = _stableUid(peerId);
        
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = stream;
        _remoteRenderers[uid] = renderer;
        onRemoteUserJoined?.call();
      }
    };

    final signalRef = _firestore
        .collection('webrtc_sessions')
        .doc(roomId)
        .collection('signaling')
        .doc(_signalingDocId(_localUserId, peerId));

    // Listen for remote signals
    final subs = _roomSubscriptions[roomId]!;
    subs.add(signalRef.snapshots().listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data()!;
      final senderId = data['senderId'] as String;
      if (senderId == _localUserId) return;

      final type = data['type'] as String;
      final sdp = data['sdp'] as String;

      // Record when remote description is received from Firestore
      _latencyTracker.recordRemoteDescriptionReceived(peerId, type);

      if (type == 'offer' && !isOfferer) {
        await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
        
        // Record when remote description has been applied
        _latencyTracker.recordRemoteDescriptionApplied(peerId);
        
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        
        await signalRef.set({
          'senderId': _localUserId,
          'type': 'answer',
          'sdp': answer.sdp,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // Record when our answer is sent
        _latencyTracker.recordOfferAnswerSent(peerId, 'answer');
      } else if (type == 'answer' && isOfferer) {
        await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
        
        // Record when remote answer has been applied
        _latencyTracker.recordRemoteDescriptionApplied(peerId);
      }
    }));

    // Listen for ICE candidates
    subs.add(_firestore
        .collection('webrtc_sessions')
        .doc(roomId)
        .collection('candidates')
        .where('userId', isEqualTo: peerId)
        .snapshots()
        .listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            pc.addCandidate(RTCIceCandidate(
              data['candidate']?.toString(),
              data['sdpMid']?.toString(),
              data['sdpMLineIndex'] as int?,
            ));
          }
        }
      }
    }));

    if (isOfferer) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      
      await signalRef.set({
        'senderId': _localUserId,
        'type': 'offer',
        'sdp': offer.sdp,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Record when our offer is sent to Firestore
      _latencyTracker.recordOfferAnswerSent(peerId, 'offer');
    }
    developer.Timeline.finishSync();
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
          _localStream = await navigator.mediaDevices.getUserMedia({
            'audio': publishMicrophoneTrack,
            'video': true,
          });
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
      _localRenderer!.srcObject = _localStream;
      _localVideoCapturing = true;
      _isBroadcaster = true;
      _localAudioMuted = !publishMicrophoneTrack;

      final videoTrack = _localStream?.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        for (var pc in _pcs.values) {
          final senders = await pc.getSenders();
          final videoSender = senders.where((s) => s.track?.kind == 'video').firstOrNull;
          if (videoSender != null) {
            await videoSender.replaceTrack(videoTrack);
          } else {
            await pc.addTrack(videoTrack, _localStream!);
            _log('Renegotiation needed for peer after adding video track.');
          }
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
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    await disposeAll();
  }

  Future<void> disposeAll() async {
    _log('Disposing WebRtcRoomService');
    WidgetsBinding.instance.removeObserver(this);
    _signalingHeartbeatTimer?.cancel();
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

    for (var pc in _pcs.values) {
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
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _log('⚠️ Connection for $peerId disconnected. Waiting for recovery...');
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _log('❌ Connection for $peerId failed.');
          _latencyTracker.recordPeerConnectionClosed(peerId);
          onConnectionLost?.call();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          _log('Connection for $peerId closed.');
          _latencyTracker.recordPeerConnectionClosed(peerId);
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





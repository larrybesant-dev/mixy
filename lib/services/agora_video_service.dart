import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'agora/agora_platform_service.dart';
import 'agora/agora_web_bridge_v2.dart';
import '../shared/providers/agora_participant_provider.dart';
import '../shared/providers/agora_video_tile_provider.dart';
import '../shared/providers/user_display_name_provider.dart';
import '../shared/models/agora_participant.dart';
import '../core/logging/debug_log.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora show UserInfo;

/// Sanitize string for safe logging on Flutter Web
String _safeLog(String input) {
  try {
    return utf8.decode(utf8.encode(input), allowMalformed: true);
  } catch (e) {
    return input.replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
  }
}

/// Agora Video Service for Flutter (Web & Mobile)
///
/// Full production implementation with:
/// - Complete event handling (video, audio, speaking detection)
/// - Participant state management via Riverpod
/// - Video tile tracking
/// - Display name caching
/// - Debug logging for troubleshooting
class AgoraVideoService extends ChangeNotifier {
  final Ref? ref; // Riverpod ref for accessing providers
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lazy-loaded to ensure Firebase is initialized
  FirebaseFunctions? _functionsInstance;
  FirebaseFunctions get _functions =>
      _functionsInstance ??
      FirebaseFunctions.instanceFor(region: 'us-central1');

  RtcEngine? _engine;
  bool _isInitialized = false;
  String? _currentChannel;
  int? _localUid;
  // Getter for agoraEngine
  RtcEngine? get agoraEngine => kIsWeb ? null : _engine;
  final List<int> _remoteUsers = [];
  final Set<int> _remoteUsersSet = {}; // Deduplication using Set
  bool _isMicMuted = false;
  bool _isVideoMuted = false;
  bool _isInChannel = false;
  String? _error;
  String? _currentSpeakerId; // User ID of current turn-based speaker
  bool _micLocked = false; // Whether mic is locked for turn-based mode
  int? _activeSpeakerUid; // Most active speaker by volume
  String? _agoraAppId; // Store App ID for platform service

  // Track media state per user to prevent ghost users (uid â†’ { hasVideo, hasAudio })
  final Map<int, Map<String, bool>> _remoteUserMediaState = {};

  // Broadcaster mode support for 100+ participants
  bool _isBroadcaster =
      true; // Default to broadcaster, can downgrade to audience
  final List<String> _activeBroadcasters = []; // Track active broadcaster UIDs

  // Web browser permission state tracking
  bool _isCameraPermissionGranted = false;
  bool _isMicPermissionGranted = false;
  bool _isCameraPermissionDenied = false;
  bool _isMicPermissionDenied = false;
  bool _isCameraPermissionPermanentlyDenied = false;
  bool _isMicPermissionPermanentlyDenied = false;
  bool _isCheckingPermissions = false;

  // Constructor accepting Riverpod ref
  AgoraVideoService({this.ref});

  // Getters
  bool get isInitialized => _isInitialized;
  String? get currentChannel => _currentChannel;
  int? get localUid => _localUid;
  List<int> get remoteUsers => List.unmodifiable(_remoteUsers);
  bool get isMicMuted => _isMicMuted;
  bool get isVideoMuted => _isVideoMuted;
  bool get isInChannel => _isInChannel;
  bool get isBroadcaster => _isBroadcaster;
  List<String> get activeBroadcasters => List.unmodifiable(_activeBroadcasters);
  RtcEngine? get engine => _engine;
  String? get error => _error;
  String? get currentSpeakerId => _currentSpeakerId;
  int? get activeSpeakerUid => _activeSpeakerUid;

  /// #9 Auto-spotlight: uid of the participant whose video tile is pinned first
  int? get spotlightedUid => _activeSpeakerUid;
  bool get micLocked => _micLocked;

  // Permission state getters
  bool get isCameraPermissionGranted => _isCameraPermissionGranted;
  bool get isMicPermissionGranted => _isMicPermissionGranted;
  bool get isCameraPermissionDenied => _isCameraPermissionDenied;
  bool get isMicPermissionDenied => _isMicPermissionDenied;
  bool get isCameraPermissionPermanentlyDenied =>
      _isCameraPermissionPermanentlyDenied;
  bool get isMicPermissionPermanentlyDenied =>
      _isMicPermissionPermanentlyDenied;
  bool get isCheckingPermissions => _isCheckingPermissions;

  /// Initialize Agora Engine with full event handlers
  Future<void> initialize() async {
    if (_isInitialized) {
      DebugLog.info(_safeLog('Ã°Å¸â€â€ž  Agora already initialized'));
      return;
    }

    try {
      DebugLog.info(_safeLog('Ã°Å¸Å½Â¬ Step 1: Initializing Agora SDK...'));
      DebugLog.info(
        _safeLog(
          'Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â',
        ),
      );
      DebugLog.info(_safeLog(
          'Ã°Å¸Å½Â¯ AGORA INIT - PLATFORM: ${kIsWeb ? "WEB (JS SDK)" : "NATIVE (Flutter SDK)"}'));

      // Get Agora App ID from Firestore config
      final configDoc =
          await _firestore.collection('config').doc('agora').get();
      final appId = configDoc.data()?['appId'] as String?;

      if (appId == null || appId.isEmpty) {
        throw Exception('Agora App ID not configured in Firestore');
      }
      _agoraAppId = appId;
      DebugLog.info(
          _safeLog('Ã¢Å“â€¦ Agora App ID loaded (length: ${appId.length})'));

      if (kIsWeb) {
        // WEB: Just mark as initialized, actual init happens on join
        DebugLog.info(
            _safeLog('Ã°Å¸Å’Â Web platform - will initialize on join'));
        _isInitialized = true;
        _engine = null; // No native engine on web      } else {
        // NATIVE: Initialize via platform service
        DebugLog.info(_safeLog('Ã°Å¸â€œÂ± Initializing Agora Native SDK...'));
        await AgoraPlatformService.initializeNative(appId);
        _engine = AgoraPlatformService.engine;

        if (_engine != null) {
          // Register event handlers for native
          _registerEventHandlers();

          // Set audio profile for high quality voice
          await _engine!.setAudioProfile(
              profile: AudioProfileType.audioProfileMusicHighQuality);

          // Enable audio volume indication for speaking detection
          await _engine!.enableAudioVolumeIndication(
              interval: 200, smooth: 3, reportVad: true);
        }

        _isInitialized = true;
        DebugLog.info(_safeLog('Ã¢Å“â€¦ Agora Native SDK initialized'));
      }

      // Check initial permission status on web
      if (kIsWeb) {
        await checkPermissions();
        _setupWebRemoteUserCallbacks();
      }

      notifyListeners();
      DebugLog.info(_safeLog('Ã¢Å“â€¦ Agora SDK initialized successfully'));
    } catch (e, stackTrace) {
      DebugLog.info(_safeLog('Ã¢ÂÅ’ Agora initialization failed: $e'));
      DebugLog.info(_safeLog('Stack trace: $stackTrace'));
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Register all Agora event handlers
  /// CRITICAL: Must be called BEFORE joining channel
  void _registerEventHandlers() {
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        // === CHANNEL LIFECYCLE ===
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          DebugLog.info(_safeLog(' Joined channel: ${connection.channelId}'));
          _localUid = connection.localUid;
          _currentChannel = connection.channelId;
          _isInChannel = true;

          // Update video tile provider with local UID
          ref?.read(videoTileProvider.notifier).setLocalUid(_localUid!);

          notifyListeners();
        },

        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          DebugLog.info(_safeLog(' Left channel'));
          _currentChannel = null;
          _localUid = null;
          _remoteUsers.clear();
          _remoteUsersSet.clear();
          _remoteUserMediaState.clear(); // Clear media state tracking
          _isInChannel = false;

          // Clear all participant and video state
          ref?.read(agoraParticipantsProvider.notifier).clear();
          ref?.read(videoTileProvider.notifier).clear();

          notifyListeners();
        },

        // === USER LIFECYCLE ===
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          DebugLog.info(_safeLog('User joined: $remoteUid'));

          // Use Set for atomic deduplication check
          if (!_remoteUsersSet.contains(remoteUid)) {
            _remoteUsers.add(remoteUid);
            _remoteUsersSet.add(remoteUid);

            // Initialize media state for this user
            _remoteUserMediaState[remoteUid] = {
              'hasVideo': false,
              'hasAudio': false
            };

            // Add participant to state (display name fetched async)
            _addParticipantToState(remoteUid);

            DebugLog.info(_safeLog('New remote user added: $remoteUid'));
          } else {
            DebugLog.info(_safeLog(
                'Remote user already tracked (rejoin or duplicate): $remoteUid'));
          }

          notifyListeners();

          // Set up remote video canvas (important for web)
          if (kIsWeb) {
            _engine!.setupRemoteVideo(VideoCanvas(
                uid: remoteUid, renderMode: RenderModeType.renderModeFit));
          }
        },

        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          DebugLog.info(_safeLog('User left: $remoteUid (reason: $reason)'));

          // Remove from both list and set for consistency
          _remoteUsers.remove(remoteUid);
          _remoteUsersSet.remove(remoteUid);
          _remoteUserMediaState.remove(remoteUid);

          // Remove from participant and video state
          ref
              ?.read(agoraParticipantsProvider.notifier)
              .removeParticipant(remoteUid);
          ref?.read(videoTileProvider.notifier).removeRemoteVideo(remoteUid);

          notifyListeners();
        },

        onUserInfoUpdated: (int uid, agora.UserInfo info) {
          DebugLog.info(_safeLog(
              'User info updated: uid=$uid, userAccount=${info.userAccount}'));

          // Update participant with Firestore userId if available
          if (ref != null && info.userAccount != null) {
            _fetchAndUpdateDisplayName(uid, info.userAccount!);
          }
        },

        // === VIDEO STATE TRACKING (CRITICAL FOR CAMERA INDICATORS) ===
        onRemoteVideoStateChanged: (
          RtcConnection connection,
          int remoteUid,
          RemoteVideoState state,
          RemoteVideoStateReason reason,
          int elapsed,
        ) {
          DebugLog.info(_safeLog(
              'Remote video state: uid=$remoteUid, state=$state, reason=$reason'));

          final hasVideo = state == RemoteVideoState.remoteVideoStateStarting ||
              state == RemoteVideoState.remoteVideoStateDecoding;

          // Update participant video state
          ref
              ?.read(agoraParticipantsProvider.notifier)
              .updateVideoState(remoteUid, hasVideo);

          // Update video tile provider
          if (hasVideo) {
            ref?.read(videoTileProvider.notifier).addRemoteVideo(remoteUid);
          } else {
            ref?.read(videoTileProvider.notifier).removeRemoteVideo(remoteUid);
          }

          notifyListeners();
        },

        // === AUDIO STATE TRACKING (CRITICAL FOR MIC INDICATORS) ===
        onRemoteAudioStateChanged: (
          RtcConnection connection,
          int remoteUid,
          RemoteAudioState state,
          RemoteAudioStateReason reason,
          int elapsed,
        ) {
          DebugLog.info(_safeLog(
              'Remote audio state: uid=$remoteUid, state=$state, reason=$reason'));

          final hasAudio = state == RemoteAudioState.remoteAudioStateStarting ||
              state == RemoteAudioState.remoteAudioStateDecoding;

          ref
              ?.read(agoraParticipantsProvider.notifier)
              .updateAudioState(remoteUid, hasAudio);

          notifyListeners();
        },

        // === SPEAKING DETECTION (VOLUME INDICATORS) ===
        onAudioVolumeIndication: (RtcConnection connection,
            List<AudioVolumeInfo> speakers,
            int speakerNumber,
            int totalVolume) {
          int? maxVolumeUid;
          int maxVolume = 0;

          for (var speaker in speakers) {
            if (speaker.uid != null && speaker.volume != null) {
              final isSpeaking = speaker.volume! > 10; // Threshold for speaking
              ref
                  ?.read(agoraParticipantsProvider.notifier)
                  .updateSpeakingState(speaker.uid!, isSpeaking);

              // Track most active speaker by volume
              if (speaker.volume! > maxVolume) {
                maxVolume = speaker.volume!;
                maxVolumeUid = speaker.uid!;
              }
            }
          }

          // Update active speaker if changed
          if (maxVolumeUid != _activeSpeakerUid && maxVolume > 10) {
            _activeSpeakerUid = maxVolumeUid;
            // #9 Auto-spotlight: promote speaker to index 0 in remote user list
            if (maxVolumeUid != null &&
                _remoteUsersSet.contains(maxVolumeUid)) {
              _remoteUsers.remove(maxVolumeUid);
              _remoteUsers.insert(0, maxVolumeUid);
            }
            notifyListeners();
          }
        },

        // === ERROR HANDLING ===
        onError: (ErrorCodeType err, String msg) {
          DebugLog.info(_safeLog('Agora Error: $err - $msg'));
          _error = '$err: $msg';
          notifyListeners();
        },

        // === CONNECTION STATE ===
        onConnectionStateChanged: (RtcConnection connection,
            ConnectionStateType state, ConnectionChangedReasonType reason) {
          DebugLog.info(_safeLog('Connection state: $state, reason: $reason'));
        },

        // === NETWORK QUALITY ===
        onNetworkQuality: (RtcConnection connection, int remoteUid,
            QualityType txQuality, QualityType rxQuality) {
          if (txQuality == QualityType.qualityPoor ||
              rxQuality == QualityType.qualityPoor) {
            DebugLog.info(_safeLog(' Poor network quality detected'));
          }
        },
      ),
    );

    DebugLog.info(_safeLog(' Event handlers registered'));
  }

  /// Request camera and microphone permissions
  Future<bool> requestPermissions() async {
    try {
      _isCheckingPermissions = true;
      notifyListeners();

      DebugLog.info(
          _safeLog(' Requesting camera and microphone permissions...'));

      final Map<Permission, PermissionStatus> statuses =
          await [Permission.camera, Permission.microphone].request();

      // Parse permission statuses
      final cameraStatus = statuses[Permission.camera];
      final micStatus = statuses[Permission.microphone];

      _isCameraPermissionGranted = cameraStatus?.isGranted ?? false;
      _isMicPermissionGranted = micStatus?.isGranted ?? false;
      _isCameraPermissionDenied = cameraStatus?.isDenied ?? false;
      _isMicPermissionDenied = micStatus?.isDenied ?? false;
      _isCameraPermissionPermanentlyDenied =
          cameraStatus?.isPermanentlyDenied ?? false;
      _isMicPermissionPermanentlyDenied =
          micStatus?.isPermanentlyDenied ?? false;

      final bool allGranted =
          statuses.values.every((status) => status.isGranted);

      if (!allGranted) {
        DebugLog.info(_safeLog('  Some permissions denied'));
        final deniedPerms = statuses.entries
            .where((e) => !e.value.isGranted)
            .map((e) => e.key.toString())
            .join(', ');
        _error = 'Permissions denied: $deniedPerms';
      } else {
        DebugLog.info(_safeLog(' All permissions granted'));
      }

      _isCheckingPermissions = false;
      notifyListeners();
      return allGranted;
    } catch (e) {
      DebugLog.info(_safeLog(' Permission request failed: $e'));
      _error = 'Permission error: $e';
      _isCheckingPermissions = false;
      notifyListeners();
      return false;
    }
  }

  /// Check permission status without requesting (web friendly)
  Future<void> checkPermissions() async {
    try {
      _isCheckingPermissions = true;
      notifyListeners();

      DebugLog.info(_safeLog(' Checking camera and microphone permissions...'));

      final cameraStatus = await Permission.camera.status;
      final micStatus = await Permission.microphone.status;

      _isCameraPermissionGranted = cameraStatus.isGranted;
      _isMicPermissionGranted = micStatus.isGranted;
      _isCameraPermissionDenied = cameraStatus.isDenied;
      _isMicPermissionDenied = micStatus.isDenied;
      _isCameraPermissionPermanentlyDenied = cameraStatus.isPermanentlyDenied;
      _isMicPermissionPermanentlyDenied = micStatus.isPermanentlyDenied;

      DebugLog.info(_safeLog(
          ' Permission status - Camera: $cameraStatus, Mic: $micStatus'));

      _isCheckingPermissions = false;
      notifyListeners();
    } catch (e) {
      DebugLog.info(_safeLog(' Permission check failed: $e'));
      _isCheckingPermissions = false;
      notifyListeners();
    }
  }

  /// Join a video room with proper initialization order
  Future<void> joinRoom(String roomId) async {
    // On web, _engine is null until join (web uses platform service)
    if (!_isInitialized || (!kIsWeb && _engine == null)) {
      throw Exception('Agora not initialized');
    }

    // Verify App ID is set (set during initialize())
    if (_agoraAppId == null || _agoraAppId!.isEmpty) {
      throw Exception('Agora App ID not initialized - call initialize() first');
    }

    // Prevent double joins
    if (_isInChannel) {
      DebugLog.info(_safeLog('  Already in channel: $_currentChannel'));
      return;
    }

    try {
      DebugLog.info(
        _safeLog(
          'Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â',
        ),
      );
      DebugLog.info(_safeLog('Ã°Å¸Å¡â‚¬ JOIN ROOM SEQUENCE START'));
      DebugLog.info(_safeLog('Ã°Å¸â€œÂ Channel: $roomId'));
      DebugLog.info(
          _safeLog('Ã°Å¸â€œÂ Platform: ${kIsWeb ? "WEB" : "NATIVE"}'));
      DebugLog.info(
        _safeLog(
          'Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â',
        ),
      );

      // === CHECKPOINT 1: VERIFY AUTH STATE ===
      DebugLog.info(
          _safeLog('Ã°Å¸â€â€™ [1/6] Verifying authentication state...'));
      final user = _auth.currentUser;

      if (user == null) {
        DebugLog.info(_safeLog(' ERROR: FirebaseAuth.currentUser is null'));
        throw Exception('Not authenticated - please sign in first');
      }

      // Extra verification: wait for auth state to be stable
      final authUser = await _auth
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 3), onTimeout: () => user);

      if (authUser == null) {
        DebugLog.info(_safeLog(' ERROR: Auth state unstable - user is null'));
        throw Exception('Authentication state not ready');
      }

      DebugLog.info(_safeLog('Ã¢Å“â€¦ [1/6] Auth verified'));
      DebugLog.info(_safeLog('   Ã¢â€â€Ã¢â€â‚¬ User: ${user.email}'));
      DebugLog.info(_safeLog('   Ã¢â€â€Ã¢â€â‚¬ UID: ${user.uid}'));
      DebugLog.info(_safeLog(
          '   Ã¢â€â€Ã¢â€â‚¬ Provider: ${user.providerData.map((p) => p.providerId).join(", ")}'));

      // === CHECKPOINT 2: GET AGORA TOKEN ===
      DebugLog.info(_safeLog('Ã°Å¸Å½Â« [2/6] Requesting Agora token...'));

      // === CHECKPOINT 3: PERMISSIONS ===
      if (kIsWeb) {
        DebugLog.info(_safeLog(
            'Ã°Å¸Å’Â [3/6] Web platform - browser will prompt for permissions on join'));
      } else {
        DebugLog.info(
            _safeLog('Ã°Å¸â€œÂ± [3/6] Requesting native permissions...'));
        final hasPermissions = await requestPermissions();
        if (!hasPermissions) {
          DebugLog.info(_safeLog('Ã¢ÂÅ’ Permissions denied'));
          throw Exception('Camera/Microphone permissions required');
        }
        DebugLog.info(_safeLog('Ã¢Å“â€¦ [3/6] Permissions granted'));
      }

      // On web, also check permissions status for UI feedback
      if (kIsWeb) {
        await checkPermissions();
      }

      // Get Agora token from Firebase Functions
      late String token;
      try {
        DebugLog.info(_safeLog(' Requesting Agora token...'));
        DebugLog.info(_safeLog('   roomId: $roomId'));
        DebugLog.info(_safeLog('   userId: ${user.uid}'));
        DebugLog.info(_safeLog('   FirebaseFunctions region: us-central1'));
        DebugLog.info(_safeLog('   Auth state: VERIFIED'));

        // CRITICAL: Force-refresh ID token before calling function
        // This ensures Firebase Web SDK has a fresh token to attach to the callable envelope
        DebugLog.info(
            _safeLog(' Refreshing Firebase ID token for callable...'));
        final refreshedToken = await user.getIdToken(true);
        DebugLog.info(_safeLog(
            ' ID token refreshed, length: ${refreshedToken?.length ?? 0}'));

        if (refreshedToken == null || refreshedToken.isEmpty) {
          throw Exception(
              'Failed to obtain fresh ID token for callable invocation');
        }

        // Use callable API - auth context is automatically included by Firebase SDK
        // The refreshed token above ensures the callable envelope has valid authentication
        DebugLog.info(_safeLog(
            ' Invoking generateAgoraToken callable with authenticated context...'));
        final result =
            await _functions.httpsCallable('generateAgoraToken').call({
          'roomId': roomId,
          'userId': user.uid,
        });
        DebugLog.info(_safeLog(' Callable returned successfully'));

        DebugLog.info(_safeLog(' Token response received'));
        final tokenValue = result.data['token'] as String?;
        final tokenUid = result.data['uid'] as int?;

        if (tokenValue == null) throw Exception('Response missing token field');
        if (tokenUid == null) throw Exception('Response missing uid field');

        token = tokenValue;
        _localUid = tokenUid;

        DebugLog.info(_safeLog('Ã¢Å“â€¦ [2/6] Token obtained'));
        DebugLog.info(_safeLog('   Ã¢â€â€Ã¢â€â‚¬ Length: ${token.length}'));
        DebugLog.info(_safeLog('   Ã¢â€â€Ã¢â€â‚¬ UID: $tokenUid'));
        DebugLog.info(_safeLog('   Ã¢â€â€Ã¢â€â‚¬ Channel: $roomId'));
      } catch (e, st) {
        DebugLog.info(_safeLog(' Agora token generation failed: $e'));
        DebugLog.info(_safeLog('Stack trace: $st'));
        throw Exception('Token generation error: $e');
      }

      // === CHECKPOINT 4: LOCAL VIDEO SETUP ===
      DebugLog.info(_safeLog('Ã°Å¸â€œÂ¹ [4/6] Setting up local video...'));
      try {
        if (!kIsWeb) {
          // Native: Set up preview before join
          await _engine!.enableLocalVideo(true);
          await _engine!.setupLocalVideo(const VideoCanvas(
              uid: 0, renderMode: RenderModeType.renderModeFit));
          await _engine!.startPreview();
          await _engine!.muteLocalVideoStream(false);
          DebugLog.info(_safeLog('Ã¢Å“â€¦ [4/6] Local video preview started'));
        } else {
          // Web: Preview happens automatically on join
          DebugLog.info(
              _safeLog('Ã¢Å“â€¦ [4/6] Web - local video will start on join'));
        }

        _isVideoMuted = false;
        notifyListeners();
      } catch (e) {
        DebugLog.info(_safeLog('  Local video setup error: $e'));
        // Continue anyway - permissions might be granted during join
      }

      // === CHECKPOINT 5: FIRESTORE PARTICIPANT ===
      DebugLog.info(
          _safeLog('Ã°Å¸â€œÂ [5/6] Adding user to Firestore participants...'));
      try {
        await _firestore
            .collection('rooms')
            .doc(roomId)
            .collection('participants')
            .doc(user.uid)
            .set({
          'userId': user.uid,
          'joinedAt': DateTime.now(),
          'displayName': user.displayName ?? 'User',
          'photoUrl': user.photoURL,
        });
        DebugLog.info(_safeLog('Ã¢Å“â€¦ [5/6] Participant added to Firestore'));
      } catch (e) {
        DebugLog.info(_safeLog('  Failed to add user to participants: $e'));
        // Don't fail - continue anyway
      }

      // === CHECKPOINT 6: JOIN CHANNEL ===
      DebugLog.info(
        _safeLog(
          'Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â',
        ),
      );
      DebugLog.info(_safeLog('Ã°Å¸â€â€” [6/6] Joining Agora channel...'));
      DebugLog.info(_safeLog(
          '   Ã¢â€â€Ã¢â€â‚¬ SDK: ${kIsWeb ? "Web JS" : "Native Flutter"}'));
      DebugLog.info(_safeLog('   Ã¢â€â€Ã¢â€â‚¬ Channel: $roomId'));
      DebugLog.info(
          _safeLog('   Ã¢â€â€Ã¢â€â‚¬ UID: $_localUid (from token)'));
      DebugLog.info(
          _safeLog('   Ã¢â€â€Ã¢â€â‚¬ Token length: ${token.length}'));

      final joined = await AgoraPlatformService.joinChannel(
        appId: _agoraAppId!,
        channelName: roomId,
        token: token,
        uid: _localUid.toString(), // Use UID from token response
      );

      if (!joined) {
        DebugLog.info(_safeLog('Ã¢ÂÅ’ Platform service returned false'));
        throw Exception('Failed to join channel via platform service');
      }

      _currentChannel = roomId;
      _isInChannel = true;

      DebugLog.info(
        _safeLog(
          'Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â',
        ),
      );
      DebugLog.info(_safeLog('Ã¢Å“â€¦ [6/6] JOIN COMPLETE'));
      DebugLog.info(_safeLog('Ã¢Å“â€¦ Successfully in channel: $roomId'));
      DebugLog.info(_safeLog('Ã¢Å“â€¦ Waiting for remote users...'));
      DebugLog.info(
        _safeLog(
          'Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â',
        ),
      );
      notifyListeners();
    } catch (e, stackTrace) {
      DebugLog.info(_safeLog(' Failed to join room: $e'));
      DebugLog.info(_safeLog('Stack trace: $stackTrace'));
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Leave the current room with proper cleanup
  Future<void> leaveRoom() async {
    // Prevent double leaves
    if (!_isInChannel && _currentChannel == null) {
      DebugLog.info(_safeLog('Ã°Å¸â€â€ž  Not in any channel'));
      return;
    }

    try {
      DebugLog.info(_safeLog('Ã°Å¸â€˜â€¹ Leaving room...'));

      // Remove user from room participants collection
      if (_currentChannel != null) {
        final user = _auth.currentUser;
        if (user != null) {
          try {
            await _firestore
                .collection('rooms')
                .doc(_currentChannel)
                .collection('participants')
                .doc(user.uid)
                .delete();
            DebugLog.info(
                _safeLog('Ã¢Å“â€¦ User removed from room participants'));
          } catch (e) {
            DebugLog.info(_safeLog(
                'Ã¢Å¡Â Ã¯Â¸Â  Failed to remove user from participants: $e'));
          }
        }
      }

      // Leave channel via platform service
      await AgoraPlatformService.leaveChannel();

      // Clean up web remote user callbacks
      if (kIsWeb) {
        AgoraWebBridgeV2.setOnRemoteUserPublished(null);
        AgoraWebBridgeV2.setOnRemoteUserUnpublished(null);
      }

      if (!kIsWeb && _engine != null) {
        await _engine!.stopPreview();
      }

      // Reset all room state
      _currentChannel = null;
      _localUid = null;
      _remoteUsers.clear();
      _isInChannel = false;
      _isMicMuted = false;
      _isVideoMuted = false;
      _currentSpeakerId = null;
      _activeSpeakerUid = null;
      _micLocked = false;
      _isBroadcaster = true;
      _activeBroadcasters.clear();

      notifyListeners();

      DebugLog.info(_safeLog('Ã¢Å“â€¦ Left room successfully'));
    } catch (e) {
      DebugLog.info(_safeLog(' Failed to leave room: $e'));
    }
  }

  /// Toggle microphone mute
  Future<void> toggleMic() async {
    try {
      _isMicMuted = !_isMicMuted;
      await AgoraPlatformService.setMicMuted(_isMicMuted);
      notifyListeners();
      DebugLog.info(
          _safeLog('Ã°Å¸Å½Â¤ Mic ${_isMicMuted ? "muted" : "unmuted"}'));
    } catch (e) {
      DebugLog.info(_safeLog(' Failed to toggle mic: $e'));
      _error = 'Mic toggle failed: $e';
      _isMicMuted = !_isMicMuted; // Revert on error
      notifyListeners();
    }
  }

  /// Toggle video mute
  Future<void> toggleVideo() async {
    try {
      _isVideoMuted = !_isVideoMuted;
      await AgoraPlatformService.setVideoMuted(_isVideoMuted);

      // Handle preview for native
      if (!kIsWeb && _engine != null) {
        if (_isVideoMuted) {
          await _engine!.stopPreview();
        } else {
          await _engine!.startPreview();
        }
      }

      notifyListeners();
      DebugLog.info(
          _safeLog('Ã°Å¸â€œÂ¹ Video ${_isVideoMuted ? "muted" : "unmuted"}'));
    } catch (e) {
      DebugLog.info(_safeLog('Ã°Å¸â€œÂ¹ Failed to toggle video: $e'));
      _error = 'Video toggle failed: $e';
      _isVideoMuted = !_isVideoMuted; // Revert on error
      notifyListeners();
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_engine == null) return;

    try {
      await _engine!.switchCamera();
      DebugLog.info(_safeLog(' Camera switched'));
    } catch (e) {
      DebugLog.info(_safeLog(' Failed to switch camera: $e'));
      _error = 'Camera switch failed: $e';
      notifyListeners();
    }
  }

  // ============================================================================
  // MIC-LOCK ENFORCEMENT FOR TURN-BASED MODE
  // ============================================================================

  /// Enforce turn-based lock: mute all except current speaker
  /// Called when a user is granted the turn
  Future<void> enforceTurnBasedLock(String speakerId) async {
    if (_engine == null) return;

    try {
      _currentSpeakerId = speakerId;
      _micLocked = true;

      final isCurrentUser = _currentSpeakerId == _auth.currentUser?.uid;

      if (isCurrentUser) {
        // Unmute local mic for the speaker
        await _engine!.muteLocalAudioStream(false);
        _isMicMuted = false;
        DebugLog.info(_safeLog(' Turn-based lock: Mic unlocked for speaker'));
      } else {
        // Mute local mic if not the speaker
        await _engine!.muteLocalAudioStream(true);
        _isMicMuted = true;
        DebugLog.info(_safeLog(' Turn-based lock: Mic locked for non-speaker'));
      }

      notifyListeners();
    } catch (e) {
      DebugLog.info(_safeLog(' Failed to enforce turn-based lock: $e'));
      _error = 'Mic lock failed: $e';
      notifyListeners();
    }
  }

  /// Release turn-based lock: restore normal mic control
  /// Called when turn-based mode is disabled or speaker turn ends
  Future<void> releaseTurnBasedLock() async {
    if (_engine == null) return;

    try {
      _currentSpeakerId = null;
      _micLocked = false;

      // Restore local mic to unmuted state
      await _engine!.muteLocalAudioStream(false);
      _isMicMuted = false;

      DebugLog.info(
          _safeLog(' Turn-based lock released: Normal mic control restored'));
      notifyListeners();
    } catch (e) {
      DebugLog.info(_safeLog(' Failed to release turn-based lock: $e'));
      _error = 'Mic unlock failed: $e';
      notifyListeners();
    }
  }

  // ============================================================================
  // HELPER METHODS FOR PARTICIPANT STATE MANAGEMENT
  // ============================================================================

  /// Add participant to state and fetch display name from Firestore
  void _addParticipantToState(int uid) {
    if (ref == null) return;

    // Create participant with temporary display name
    // In production, map uid to userId via room metadata
    final userId =
        uid.toString(); // Temporary - should come from room participants map

    final participant = AgoraParticipant(
      uid: uid,
      userId: userId,
      displayName: 'User $uid', // Temporary until Firestore fetch completes
      hasVideo: false,
      hasAudio: true,
      isSpeaking: false,
      joinedAt: DateTime.now(),
    );

    ref!.read(agoraParticipantsProvider.notifier).addParticipant(participant);

    // Fetch and update display name asynchronously
    _fetchAndUpdateDisplayName(uid, userId);
  }

  /// Fetch display name from Firestore and update participant
  Future<void> _fetchAndUpdateDisplayName(int uid, String userId) async {
    if (ref == null) return;

    try {
      final displayName =
          await ref!.read(userDisplayNameProvider(userId).future);
      ref!
          .read(agoraParticipantsProvider.notifier)
          .updateDisplayName(uid, displayName);
      DebugLog.info(
          _safeLog('Updated display name for uid=$uid: $displayName'));
    } catch (e) {
      DebugLog.info(_safeLog('Failed to fetch display name for uid=$uid: $e'));
    }
  }

  /// Setup method combinations to stop remote participant stream
  /// On web: Handled via Firestore listener removing participant
  /// On native: We can mute their audio but not truly kick them from the session
  /// The Firestore removedUsers list and canUserJoinRoom validation handles actual removal

  /// Set up web remote user event callbacks
  /// Called during initialize() on web platform to listen for remote user events
  void _setupWebRemoteUserCallbacks() {
    if (!kIsWeb) return;

    try {
      // When a remote user publishes video/audio
      AgoraWebBridgeV2.setOnRemoteUserPublished((event) {
        try {
          final uid = event['uid'] as int?;
          final mediaType = event['mediaType'] as String?;

          if (uid == null) return;

          DebugLog.info(_safeLog(
              'Remote user published: uid=$uid, mediaType=$mediaType'));

          // Get or create media state for this user
          _remoteUserMediaState[uid] ??= {'hasVideo': false, 'hasAudio': false};
          final mediaState = _remoteUserMediaState[uid]!;

          // Update media state
          if (mediaType == 'video') {
            mediaState['hasVideo'] = true;
          } else if (mediaType == 'audio') {
            mediaState['hasAudio'] = true;
          }

          // Only add to remote users if this is the FIRST track from this user
          if (!_remoteUsersSet.contains(uid)) {
            _remoteUsers.add(uid);
            _remoteUsersSet.add(uid);

            // Add participant to state (will fetch display name async)
            _addParticipantToState(uid);

            DebugLog.info(
                _safeLog('New remote user added: uid=$uid (first track)'));
          } else {
            // User already in list, this is an additional media track
            DebugLog.info(_safeLog(
                'Remote user already added: uid=$uid (additional track: $mediaType)'));
          }

          notifyListeners();
        } catch (e) {
          DebugLog.info(_safeLog('Error handling remote user published: $e'));
        }
      });

      // When a remote user unpublishes video/audio
      AgoraWebBridgeV2.setOnRemoteUserUnpublished((event) {
        try {
          final uid = event['uid'] as int?;

          if (uid == null) return;

          DebugLog.info(_safeLog('Remote user unpublished: uid=$uid'));

          // Get media state for this user
          final mediaState = _remoteUserMediaState[uid];
          if (mediaState == null) {
            DebugLog.info(
                _safeLog('User not tracked, ignoring unpublish: uid=$uid'));
            return;
          }

          // Mark this media type as unavailable
          final mediaType = event['mediaType'] as String?;
          if (mediaType == 'video') {
            mediaState['hasVideo'] = false;
          } else if (mediaType == 'audio') {
            mediaState['hasAudio'] = false;
          }

          // Only remove user if ALL tracks are gone
          final hasVideo = mediaState['hasVideo'] ?? false;
          final hasAudio = mediaState['hasAudio'] ?? false;

          if (!hasVideo && !hasAudio) {
            // All tracks gone, remove user completely
            _remoteUsers.remove(uid);
            _remoteUsersSet.remove(uid);
            _remoteUserMediaState.remove(uid);

            // Remove from participant state
            ref
                ?.read(agoraParticipantsProvider.notifier)
                .removeParticipant(uid);
            ref?.read(videoTileProvider.notifier).removeRemoteVideo(uid);

            DebugLog.info(_safeLog(
                'User completely removed (all tracks gone): uid=$uid'));
          } else {
            DebugLog.info(_safeLog(
                'User still has active tracks: uid=$uid (video=$hasVideo, audio=$hasAudio)'));
          }

          notifyListeners();
        } catch (e) {
          DebugLog.info(_safeLog('Error handling remote user unpublished: $e'));
        }
      });

      // When a remote user completely leaves (most reliable)
      AgoraWebBridgeV2.setOnRemoteUserLeft((event) {
        try {
          final uid = event['uid'] as int?;

          if (uid == null) return;

          DebugLog.info(_safeLog('Remote user completely left: uid=$uid'));

          // Force-remove this user regardless of media state
          if (_remoteUsersSet.contains(uid)) {
            _remoteUsers.remove(uid);
            _remoteUsersSet.remove(uid);
            _remoteUserMediaState.remove(uid);

            // Clean up participant and video state
            ref
                ?.read(agoraParticipantsProvider.notifier)
                .removeParticipant(uid);
            ref?.read(videoTileProvider.notifier).removeRemoteVideo(uid);

            DebugLog.info(
                _safeLog('User force-removed (left event): uid=$uid'));
            notifyListeners();
          }
        } catch (e) {
          DebugLog.info(_safeLog('Error handling remote user left: $e'));
        }
      });

      DebugLog.info(_safeLog(
          'Web remote user callbacks configured with media state tracking'));
    } catch (e) {
      DebugLog.info(_safeLog('Error setting up web callbacks: $e'));
    }
  }

  // ============================================================================
  // PROVIDER-COMPATIBLE ALIASES
  // ============================================================================

  Future<void> joinChannel(String channelName,
      {String? token, int? uid}) async {
    await joinRoom(channelName);
  }

  Future<void> leaveChannel() async {
    await leaveRoom();
  }

  Future<void> enableLocalAudio(bool enabled) async {
    if (_engine == null) return;
    await _engine!.enableLocalAudio(enabled);
    _isMicMuted = !enabled;
    notifyListeners();
  }

  Future<void> enableLocalVideo(bool enabled) async {
    if (_engine == null) return;
    await _engine!.enableLocalVideo(enabled);
    _isVideoMuted = !enabled;
    notifyListeners();
  }

  Future<void> muteRemoteAudioStream(int uid, bool mute) async {
    if (_engine == null) return;
    await _engine!.muteRemoteAudioStream(uid: uid, mute: mute);
  }

  Future<void> muteLocalAudio() async {
    if (_engine == null) return;
    await _engine!.muteLocalAudioStream(true);
    _isMicMuted = true;
    notifyListeners();
  }

  Future<void> unmuteLocalAudio() async {
    if (_engine == null) return;
    await _engine!.muteLocalAudioStream(false);
    _isMicMuted = false;
    notifyListeners();
  }

  Future<void> muteLocalVideo() async {
    if (_engine == null) return;
    await _engine!.muteLocalVideoStream(true);
    _isVideoMuted = true;
    notifyListeners();
  }

  Future<void> unmuteLocalVideo() async {
    if (_engine == null) return;
    await _engine!.muteLocalVideoStream(false);
    _isVideoMuted = false;
    notifyListeners();
  }

  Future<void> setMicMuted(bool muted) async {
    if (_engine == null) return;
    await _engine!.muteLocalAudioStream(muted);
    _isMicMuted = muted;
    notifyListeners();
  }

  Future<void> setVideoMuted(bool muted) async {
    if (_engine == null) return;
    await _engine!.muteLocalVideoStream(muted);
    _isVideoMuted = muted;
    notifyListeners();
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  @override
  void dispose() {
    DebugLog.info(_safeLog('  Disposing Agora service...'));
    _disposeEngine();
    super.dispose();
  }

  void _disposeEngine() {
    if (_engine == null) return;

    try {
      _remoteUsers.clear();
      _currentChannel = null;
      _localUid = null;
      _isInChannel = false;
      _isInitialized = false;

      _engine!.stopPreview().catchError((e) {
        DebugLog.info(_safeLog('  Error stopping preview: $e'));
      });

      _engine!.leaveChannel().catchError((e) {
        DebugLog.info(_safeLog('  Error leaving channel: $e'));
      });

      _engine!.release().then((_) {
        DebugLog.info(_safeLog(' Agora engine released'));
      }).catchError((e) {
        DebugLog.info(_safeLog('  Error releasing engine: $e'));
      });

      _engine = null;
      notifyListeners();
    } catch (e) {
      DebugLog.info(_safeLog(' Error disposing Agora engine: $e'));
    }
  }

  /// Switch user role between broadcaster and audience
  /// Broadcasters can stream video/audio, audiences can only receive
  /// Use this for 100+ participant rooms - limit active broadcasters to ~20
  Future<void> switchToBroadcaster() async {
    if (!_isInitialized || _engine == null) {
      throw Exception('Agora not initialized');
    }

    try {
      DebugLog.info(_safeLog(' Switching to broadcaster mode...'));

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // Enable local video/audio for broadcasting
      await _engine!.muteLocalVideoStream(false);
      await _engine!.muteLocalAudioStream(false);

      _isBroadcaster = true;
      _isVideoMuted = false;
      _isMicMuted = false;

      notifyListeners();
      DebugLog.info(_safeLog(' Switched to broadcaster mode'));
    } catch (e) {
      DebugLog.info(_safeLog(' Failed to switch to broadcaster: $e'));
      rethrow;
    }
  }

  /// Switch user to audience mode (receive only)
  /// Helps manage 100+ participants by limiting active broadcasters
  Future<void> switchToAudience() async {
    if (!_isInitialized || _engine == null) {
      throw Exception('Agora not initialized');
    }

    try {
      DebugLog.info(_safeLog(' Switching to audience mode...'));

      await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);

      // Disable local video/audio for audience members
      await _engine!.muteLocalVideoStream(true);
      await _engine!.muteLocalAudioStream(true);

      _isBroadcaster = false;
      _isVideoMuted = true;
      _isMicMuted = true;

      notifyListeners();
      DebugLog.info(_safeLog(' Switched to audience mode'));
    } catch (e) {
      DebugLog.info(_safeLog(' Failed to switch to audience: $e'));
      rethrow;
    }
  }

  /// Check if system is running at broadcaster capacity
  /// Returns true if active broadcasters >= 20 (conservative limit for 100+ room)
  bool isAtBroadcasterCapacity() {
    return _activeBroadcasters.length >= 20;
  }

  /// Update active broadcaster list from Firestore
  void updateActiveBroadcasters(List<String> broadcasterIds) {
    _activeBroadcasters.clear();
    _activeBroadcasters.addAll(broadcasterIds);
    DebugLog.info(
        _safeLog(' Active broadcasters: ${_activeBroadcasters.length}'));
    notifyListeners();
  }
}

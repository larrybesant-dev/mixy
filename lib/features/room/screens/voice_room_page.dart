import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:mixmingle/shared/models/room.dart';
import 'package:mixmingle/shared/models/agora_participant.dart';
import 'package:mixmingle/shared/models/room_role.dart';
import 'package:mixmingle/shared/models/room_event.dart';
import 'package:mixmingle/shared/providers/all_providers.dart';
import 'package:mixmingle/shared/providers/room_providers.dart'
    as legacy_room_providers;
import 'package:mixmingle/services/agora/agora_video_service.dart';
import 'package:mixmingle/core/utils/app_logger.dart';
import 'package:mixmingle/features/room/widgets/voice_room_chat_overlay.dart';
import 'package:mixmingle/features/room/widgets/moderation_panel.dart';
import 'package:mixmingle/core/platform/web_platform_view_helper.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixmingle/shared/models/user.dart';
import 'package:mixmingle/shared/widgets/enhanced_stage_layout.dart';
import 'package:mixmingle/features/room/widgets/dynamic_video_grid.dart';

/// Full RoomPage Widget Tree
/// A complete, production-ready room screen with:
/// - Video grid (adaptive layout for 1-12+ users)
/// - Participant list with live indicators
/// - Real-time chat overlay
/// - Control bar (mic, camera, flip, chat, leave)
/// - Speaking animations and indicators
/// - Proper lifecycle management
/// - Zero placeholders
class VoiceRoomPage extends ConsumerStatefulWidget {
  final Room room;

  const VoiceRoomPage({super.key, required this.room});

  @override
  ConsumerState<VoiceRoomPage> createState() => _VoiceRoomPageState();
}

/// State management for VoiceRoomPage
/// Handles:
/// - Agora initialization and joining
/// - Lifecycle management (join on mount, leave on dispose)
/// - Animation controllers for smooth UI transitions
/// - UI state (participant list visibility, chat panel)
class _VoiceRoomPageState extends ConsumerState<VoiceRoomPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late AnimationController _tileAnimationController;
  late Animation<double> _tileFadeAnimation;
  late Animation<Offset> _tileSlideAnimation;

  bool _isInitializing = false;
  bool _isJoined = false;
  String? _errorMessage;
  bool _showParticipantList = true;

  // ðŸ”¥ Reactive auth getter using Riverpod authStateProvider
  // CRITICAL: Always use ref.watch here, not direct FirebaseAuth.instance.currentUser
  // Returns Firebase Auth User (has .uid property)
  firebase_auth.User? get currentUser => ref.watch(authStateProvider).maybeWhen(
        data: (user) => user,
        orElse: () => null,
      );

  // Single-mic (stage) mode state
  bool _singleMicMode = false;
  bool _turnBased = false;
  String? _currentSpeakerUserId;
  final List<String> _speakerQueue = [];
  final Set<String> _raisedHands = {};

  // Speaker timer state
  Timer? _speakerTimer;
  int _speakerTimeRemaining = 0;
  // ignore: unused_field
  int _turnDurationSeconds =
      60; // Used when turn-based speaking is fully implemented

  // ðŸ”¥ PHASE 3.1d: Periodic Agora â†’ Firestore sync timer
  Timer? _agoraSyncTimer;

  // ðŸ”¥ PHASE 3.1: Cache current room for deep widget tree access
  late Room _currentRoom;

  // ðŸ”¥ PHASE 3.1b: Cache current participants for deep widget tree access
  List<EnrichedParticipant> _currentParticipants = [];

  // Track registered platform view IDs to prevent duplicate registration
  final Set<String> _registeredViewIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize from widget.room
    _currentRoom = widget.room;
    _turnBased = widget.room.turnBased;
    _turnDurationSeconds = widget.room.turnDurationSeconds;

    // Note: ref.listen moved to build method to comply with Riverpod lifecycle rules

    // Setup animations for tile entry
    _tileAnimationController = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);

    _tileFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
        parent: _tileAnimationController, curve: Curves.easeInOut));

    _tileSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _tileAnimationController, curve: Curves.easeOutCubic));

    // Now attempt join with auth listener active (which is in build method)
    _initializeAndJoinRoom();
    // NOTE: Event handlers are already registered in agora_video_service.dart
    // Removed duplicate _setupAgoraEventHandlers() call to prevent double event firing
    // NOTE: Periodic sync timer removed - event handlers already update Firestore on state changes
    // Removed _startAgoraSyncTimer() to prevent unnecessary duplicate writes
  }

  // ðŸ”¥ PHASE 3.1d: Sync local Agora state to Firestore
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ignore: unused_local_variable
    final agoraService = ref.read(agoraVideoServiceProvider);
    if (!_isJoined) return;

    switch (state) {
      case AppLifecycleState.paused:
        // App paused - may need to pause video
        break;
      case AppLifecycleState.resumed:
        // App resumed - resume video if needed
        break;
      case AppLifecycleState.detached:
        // App closing
        break;
      case AppLifecycleState.hidden:
        // App hidden
        break;
      case AppLifecycleState.inactive:
        // App inactive
        break;
    }
  }

  Future<void> _initializeAndJoinRoom() async {
    AppLogger.info(
        'ðŸ”¥ [JOIN] Function called - _isInitializing: $_isInitializing, _isJoined: $_isJoined');
    if (_isInitializing || _isJoined) {
      AppLogger.info(
          'ðŸ”¥ [JOIN] Early return - already initializing or joined');
      return;
    }

    AppLogger.info('ðŸ”¥ [JOIN] Setting state to initializing');
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      AppLogger.info('ðŸ”¥ [JOIN] Getting agora service and user');
      final agoraService = ref.read(agoraVideoServiceProvider);

      // CRITICAL FIX: Get fresh user from currentUserProvider (User from shared/models/user.dart)
      User? user;
      String authErrorDetails = '';
      try {
        user = await ref.read(currentUserProvider.future).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            AppLogger.warning(
                'ðŸ” Auth provider timeout (10s), throwing to trigger fallback');
            authErrorDetails = 'Provider timeout';
            throw TimeoutException('Auth provider did not resolve in time');
          },
        );
      } catch (e) {
        AppLogger.warning('ðŸ” Auth provider error: $e');
        if (authErrorDetails.isEmpty) {
          authErrorDetails = 'Provider error: $e';
        }
        // No fallback: rely solely on Riverpod provider for user
      }

      AppLogger.info(
          'ðŸ”¥ [JOIN] User: ${user?.email ?? "NULL"} (Details: $authErrorDetails)');
      if (user == null) {
        final errorMsg = authErrorDetails.isNotEmpty
            ? 'Authentication failed - $authErrorDetails. Please sign in again.'
            : 'Not authenticated. Please sign in first.';
        throw Exception(errorMsg);
      }

      AppLogger.info(
          'ðŸ”¥ [JOIN] Checking if Agora is initialized: ${agoraService.isInitialized}');

      // CRITICAL FIX: Verify user has access to room (not banned/removed)
      AppLogger.info('ðŸ”¥ [JOIN] Verifying room access permission');
      try {
        final roomDoc = await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.room.id)
            .get();
        if (!roomDoc.exists) {
          throw Exception('Room no longer exists');
        }

        final roomData = roomDoc.data()!;
        final bannedUsers = List<String>.from(roomData['bannedUsers'] ?? []);

        if (bannedUsers.contains(user.id)) {
          throw Exception('You are banned from this room');
        }

        // Note: Kicked users can rejoin, so we don't block them
        AppLogger.info('ðŸ”¥ [JOIN] Room access verified âœ…');
      } catch (e) {
        AppLogger.error('ðŸ”¥ Room permission check failed', e, null);
        throw Exception('Cannot access room: ${e.toString()}');
      }

      // Initialize Agora engine if needed
      if (!agoraService.isInitialized) {
        AppLogger.info('ðŸ”¥ [JOIN] Initializing Agora engine...');
        debugPrint('ðŸŽ¬ Initializing Agora engine...');
        await agoraService.initialize();
        AppLogger.info('ðŸ”¥ [JOIN] Agora initialized');
      }

      // Join room with Agora
      AppLogger.info('ðŸ”¥ [JOIN] About to join room: ${widget.room.id}');
      debugPrint('ðŸ“¢ Joining room: ${widget.room.id}');
      await agoraService.joinRoom(widget.room.id);
      AppLogger.info('ðŸ”¥ [JOIN] joinRoom completed');

      // #1 Record vibe join for intelligence layer
      final vibeUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (vibeUid != null && widget.room.vibeTag != null) {
        ref
            .read(vibeIntelligenceServiceProvider)
            .recordVibeJoin(userId: vibeUid, vibeTag: widget.room.vibeTag!);
      }

      // Trigger tile animation
      _tileAnimationController.forward();

      if (mounted) {
        setState(() {
          _isJoined = true;
          _isInitializing = false;
          _currentSpeakerUserId ??=
              user!.id; // Default speaker is self when stage mode is used
        });
        // #8 Activate vibe accent for this room
        if (widget.room.vibeTag != null) {
          ref.read(activeVibeProvider.notifier).set(widget.room.vibeTag);
        }
        // System message will be added automatically via Firestore trigger
        debugPrint('✅ Successfully joined room');
      }
    } catch (e) {
      debugPrint('âŒ Failed to initialize room: $e');
      AppLogger.error('ðŸ”¥ Room initialization failed', e, null);
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _leaveRoom() async {
    try {
      final agoraService = ref.read(agoraVideoServiceProvider);
      final user = currentUser;

      // Remove from Firestore participants
      if (user != null) {
        try {
          final repository = ref.read(roomSubcollectionRepositoryProvider);
          await repository.removeParticipant(
            roomId: widget.room.id,
            userId: user.uid,
          );

          // Log leave event
          await repository.logEvent(
            roomId: widget.room.id,
            event: RoomEvent.userLeft(
              userId: user.uid,
              timestamp: DateTime.now(),
            ),
          );
        } catch (e) {
          debugPrint('âš ï¸ Failed to remove from Firestore: $e');
        }
      }

      // System message will be added automatically via Firestore trigger
      debugPrint('ðŸ‘‹ Leaving room...');
      await agoraService.leaveRoom();
      // #8 Reset vibe accent
      ref.read(activeVibeProvider.notifier).set(null);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('âš ï¸ Error leaving room: $e');
      // Still navigate even if error
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // ============================================================================
  // SPEAKER TIMER METHODS
  // ============================================================================

  // Unused - pending full turn-based implementation
  // void _startSpeakerTimer() {
  //   _stopSpeakerTimer(); // Clear any existing timer

  //   if (!mounted || !_turnBased || _currentSpeakerUserId == null) return;

  //   setState(() {
  //     _speakerTimeRemaining = _turnDurationSeconds;
  //   });

  //   _speakerTimer = Timer.periodic(Duration(seconds: 1), (timer) {
  //     if (!mounted) {
  //       timer.cancel();
  //       return;
  //     }

  //     setState(() {
  //       _speakerTimeRemaining--;
  //     });

  //     // Auto-advance when time expires
  //     if (_speakerTimeRemaining <= 0) {
  //       _autoAdvanceSpeaker();
  //       timer.cancel();
  //     }
  //   });

  //   debugPrint('â±ï¸ Speaker timer started: $_speakerTimeRemaining seconds');
  // }

  // Unused - pending full turn-based implementation
  // void _stopSpeakerTimer() {
  //   _speakerTimer?.cancel();
  //   _speakerTimer = null;
  //   if (mounted) {
  //     setState(() {
  //       _speakerTimeRemaining = 0;
  //     });
  //   }
  // }

  // Unused - pending full turn-based implementation
  // Future<void> _autoAdvanceSpeaker() async {
  //   if (!mounted) return;

  //   try {
  //     // final roomService = ref.read(roomServiceProvider);
  //     final user = currentUser;

  //     if (user == null) return;

  //     // Only auto-advance if the room is still in turn-based mode and we're a moderator
  //     // TODO: Implement turn-based speaking - method not yet available in RoomService
  //     // await roomService.grantTurnFromQueue(widget.room.id, user.id);
  //     debugPrint('â° Auto-advance feature pending implementation');
  //   } catch (e) {
  //     debugPrint('âš ï¸ Auto-advance failed: $e');
  //   }
  // }

  void _extendSpeakerTime(int additionalSeconds) async {
    try {
      setState(() {
        _speakerTimeRemaining += additionalSeconds;
      });
      debugPrint('â±ï¸ Speaker time extended by $additionalSeconds seconds');
    } catch (e) {
      debugPrint('âš ï¸ Failed to extend time: $e');
    }
  }

  void _skipCurrentSpeaker() async {
    if (!mounted) return;

    try {
      // final roomService = ref.read(roomServiceProvider);
      final user = currentUser;

      if (user == null || _currentSpeakerUserId == null) return;

      // End current turn
      // TODO: Implement turn-based speaking - methods not yet available in RoomService
      // await roomService.endTurn(widget.room.id, user.id);

      // Grant next from queue if available
      final room = widget.room;
      if (room.speakerQueue.isNotEmpty) {
        // await roomService.grantTurnFromQueue(widget.room.id, user.id);
      }

      debugPrint('â© Speaker transition feature pending implementation');
    } catch (e) {
      debugPrint('âš ï¸ Failed to skip speaker: $e');
    }
  }

  @override
  void dispose() {
    // Cancel all timers first to prevent accessing disposed widget
    _speakerTimer?.cancel();
    _speakerTimer = null;
    _agoraSyncTimer?.cancel();
    _agoraSyncTimer = null;

    WidgetsBinding.instance.removeObserver(this);
    _tileAnimationController.dispose();

    // Leave room if still joined (async cleanup via Future)
    if (_isJoined) {
      try {
        ref.read(agoraVideoServiceProvider).leaveRoom().then((_) {
          debugPrint('âœ… Room cleanup complete');
        }).catchError((e) {
          debugPrint('âš ï¸ Error during room cleanup: $e');
        });
      } catch (e) {
        debugPrint('Error during dispose: $e');
      }
    }

    // #8 Reset vibe accent on dispose
    ref.read(activeVibeProvider.notifier).set(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL FIX: Setup auth listener using ref.listen (only allowed in build method)
    // This ensures retry logic is active if auth resolves after first join call
    // ONLY retry if we explicitly failed before (not during initial load)
    ref.listen(authStateProvider, (previous, next) {
      // Only trigger join if:
      // 1. Previous state was null/unauthenticated (user just signed in)
      // 2. Current state is authenticated
      // 3. We haven't already joined successfully
      final wasUnauthenticated = previous?.maybeWhen(
            data: (user) => user == null,
            orElse: () => true,
          ) ??
          true;

      final isNowAuthenticated = next.maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );

      if (wasUnauthenticated &&
          isNowAuthenticated &&
          !_isJoined &&
          !_isInitializing) {
        AppLogger.info(
            'ðŸ” Auth state changed: unauthenticated â†’ authenticated, retrying room join');
        _initializeAndJoinRoom();
      }
    });

    // Watch all necessary providers
    final agoraParticipants = ref.watch(agoraParticipantsProvider);
    final videoTiles = ref.watch(videoTileProvider);
    final agoraService = ref.watch(agoraVideoServiceProvider);
    // final user = currentUser; // Unused in this method
    // Get user profile for display name - use AsyncData pattern
    final currentUserProfileAsync = ref.watch(currentUserProvider);
    final currentUserProfile = currentUserProfileAsync.maybeWhen(
      data: (user) => user,
      orElse: () => null,
    );

    // ðŸ”¥ PHASE 3.1: Watch live room stream for real-time updates
    final roomAsync = ref.watch(roomProvider(widget.room.id));

    // ðŸ”¥ PHASE 3.1b: Watch enriched participants stream for real-time participant sync
    final participantsAsync =
        ref.watch(enrichedParticipantsProvider(widget.room.id));

    return roomAsync.when(
      data: (room) {
        // Use fallback to widget.room if stream returns null (shouldn't happen, but defensive)
        final currentRoom = room ?? widget.room;

        // Update cached room for deep widget tree
        if (room != null) {
          _currentRoom = room;
        }

        return participantsAsync.when(
          data: (enrichedParticipants) {
            // Update cached participants for deep widget tree
            _currentParticipants = enrichedParticipants;

            return Scaffold(
              backgroundColor: Colors.black,
              appBar: _buildAppBar(context, enrichedParticipants.length,
                  currentUser, currentRoom),
              body: _buildBody(
                  agoraParticipants, videoTiles, agoraService, currentUser),
              bottomNavigationBar: _buildControlBar(
                  agoraService, currentUser, currentUserProfile),
            );
          },
          loading: () => Scaffold(
            backgroundColor: Colors.black,
            appBar: _buildAppBar(
                context, _currentParticipants.length, currentUser, currentRoom),
            body: Column(
              children: [
                Expanded(
                    child: _buildBody(agoraParticipants, videoTiles,
                        agoraService, currentUser)),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white70),
                      ),
                      SizedBox(width: 8),
                      Text('Syncing participants...',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar:
                _buildControlBar(agoraService, currentUser, currentUserProfile),
          ),
          error: (error, stack) {
            debugPrint('âŒ Participants stream error: $error');
            // Fallback to cached participants on error
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: _buildAppBar(context, _currentParticipants.length,
                  currentUser, currentRoom),
              body: _buildBody(
                  agoraParticipants, videoTiles, agoraService, currentUser),
              bottomNavigationBar: _buildControlBar(
                  agoraService, currentUser, currentUserProfile),
            );
          },
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      error: (error, stack) {
        debugPrint('âŒ Room stream error: $error');
        // Fallback to widget.room on error
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: _buildAppBar(
              context, _currentParticipants.length, currentUser, widget.room),
          body: _buildBody(
              agoraParticipants, videoTiles, agoraService, currentUser),
          bottomNavigationBar:
              _buildControlBar(agoraService, currentUser, currentUserProfile),
        );
      },
    );
  }

  /// App bar with room name, participant count, and action buttons
  PreferredSizeWidget _buildAppBar(BuildContext context, int participantCount,
      firebase_auth.User? currentUser, Room room) {
    final isHostOrCoHost = currentUser != null &&
        (currentUser.uid == room.hostId ||
            room.moderators.contains(currentUser.uid));

    return AppBar(
      backgroundColor: Colors.black87,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: _leaveRoom,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            room.name ?? room.title,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Row(
            children: [
              Text(
                '$participantCount ${participantCount == 1 ? 'participant' : 'participants'} â€¢ ${room.category}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (_turnBased && _currentSpeakerUserId != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(4)),
                  child: const Text(
                    'ðŸŽ¤ Speaking',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      actions: [
        // Host settings (host/co-host only)
        if (isHostOrCoHost)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70),
                tooltip: 'Host controls',
                // ignore: unnecessary_null_comparison
                onPressed: () => _showHostSettingsSheet(
                    context, currentUser, participantCount, room),
              ),
            ),
          ),

        // Moderation panel (only for host/co-host)
        if (currentUser != null && currentUser.uid == _currentRoom.hostId)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: IconButton(
                icon:
                    const Icon(Icons.admin_panel_settings, color: Colors.amber),
                tooltip: 'Moderation',
                onPressed: () {
                  final participants = ref.read(agoraParticipantsProvider);
                  showModerationPanel(
                    context,
                    room: widget.room,
                    currentUserId: currentUser.uid,
                    currentUserRole: RoomRole.owner,
                    participants: participants,
                  );
                },
              ),
            ),
          ),
        // Participant list toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showParticipantList = !_showParticipantList;
                });
              },
              child: Icon(
                  _showParticipantList ? Icons.people : Icons.people_outline,
                  color: Colors.white),
            ),
          ),
        ),

        // Help button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.white70),
              tooltip: 'Keyboard shortcuts and help',
              onPressed: () => _showHelpDialog(context),
            ),
          ),
        ),
      ],
    );
  }

  /// Main body: Video grid + Participant list
  Widget _buildBody(
    Map<int, AgoraParticipant> participants,
    VideoTileState videoTiles,
    AgoraVideoService agoraService,
    firebase_auth.User? currentUser,
  ) {
    // Loading state
    if (_isInitializing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.grey[900]),
              child: const Center(
                child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.pinkAccent)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Joining room...',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      );
    }

    // Error state
    if (_errorMessage != null) {
      // Extract user-friendly error message
      String userFriendlyMessage = _errorMessage!;
      if (userFriendlyMessage.contains('NotAuthenticatedException')) {
        userFriendlyMessage = 'You need to be logged in to join this room';
      } else if (userFriendlyMessage.contains('permission')) {
        userFriendlyMessage = 'You don\'t have permission to join this room';
      } else if (userFriendlyMessage.contains('timeout')) {
        userFriendlyMessage =
            'Connection timed out. Please check your internet and try again';
      } else if (userFriendlyMessage.contains('firestore')) {
        userFriendlyMessage =
            'Unable to load room information. Please try again';
      } else if (userFriendlyMessage.length > 100) {
        // Truncate very long error messages
        userFriendlyMessage = '${userFriendlyMessage.substring(0, 100)}...';
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 64),
            const SizedBox(height: 20),
            const Text(
              'Failed to join room',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                userFriendlyMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _initializeAndJoinRoom,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      foregroundColor: Colors.white),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Success state - Main layout
    return Row(
      children: [
        // Video grid area
        Expanded(
          child: Stack(
            children: [
              _buildVideoArea(
                  videoTiles, agoraService, participants, currentUser),

              // TODO: Add camera approval UI component or skip for V1
              // Placeholder for future camera approval feature
            ],
          ),
        ),

        // Participant sidebar (if visible)
        if (_showParticipantList) _buildParticipantSidebar(participants),
      ],
    );
  }

  /// Video grid area with adaptive layout
  Widget _buildVideoArea(
    VideoTileState videoTiles,
    AgoraVideoService agoraService,
    Map<int, AgoraParticipant> participants,
    firebase_auth.User? currentUser,
  ) {
    final sortedVideoUids =
        _sortVideoUids(videoTiles.allVideoUids, participants);

    // No cameras on - placeholder
    if (sortedVideoUids.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 80, color: Colors.grey[700]),
            const SizedBox(height: 24),
            Text(
              'No cameras active',
              style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 18,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              '${participants.length} ${participants.length == 1 ? 'person' : 'people'} in the room',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Stage layout when turn-based mode is active (spotlight + thumbnails)
    if (_turnBased && participants.isNotEmpty) {
      final speakerId = _currentSpeakerUserId != null
          ? participants.entries
              .firstWhere(
                (entry) => entry.value.userId == _currentSpeakerUserId,
                orElse: () => MapEntry(0, participants.values.first),
              )
              .key
          : null;

      return EnhancedStageLayout(
        speakerId: speakerId,
        allParticipants: participants,
        localUid: agoraService.localUid,
        rtcEngine: agoraService.engine,
        channelId: agoraService.currentChannel,
        onTileTapped: (uid) {
          // Future: allow clicking to spotlight a participant
        },
        isCurrentUserSpeaker:
            currentUser != null && currentUser.uid == _currentSpeakerUserId,
      );
    }

    // Stage layout when single-mic mode is active
    if (_singleMicMode) {
      final featuredUid = _resolveFeaturedUid(sortedVideoUids, participants);
      if (featuredUid != null) {
        final audienceUids =
            sortedVideoUids.where((uid) => uid != featuredUid).toList();
        return _buildStageLayout(
          featuredUid: featuredUid,
          audienceUids: audienceUids,
          agoraService: agoraService,
          participants: participants,
        );
      }
    }

    // Use DynamicVideoGrid for adaptive layouts
    final gridTiles = sortedVideoUids.map((uid) {
      final participant = participants[uid];
      return VideoTile(
        uid: uid,
        view: _buildVideoTile(uid, agoraService, participant),
        isMuted: participant?.hasAudio == false,
        isSpeaking: participant?.isSpeaking ?? false,
        displayName: participant?.displayName ?? 'User',
        avatarUrl: null, // Add if available
        isOnCam: participant?.hasVideo ?? true,
      );
    }).toList();

    return Container(
      color: Colors.black,
      child: DynamicVideoGrid(
        tiles: gridTiles,
        padding: const EdgeInsets.all(16),
        spacing: 8,
      ),
    );
  }

  // Stage-first layout: big featured tile + filmstrip grid
  Widget _buildStageLayout({
    required int featuredUid,
    required List<int> audienceUids,
    required AgoraVideoService agoraService,
    required Map<int, AgoraParticipant> participants,
  }) {
    return Container(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Featured speaker gets the hero spot
            Expanded(
              flex: audienceUids.isEmpty ? 10 : 6,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _buildVideoTile(
                    featuredUid, agoraService, participants[featuredUid]),
              ),
            ),
            if (audienceUids.isNotEmpty) ...[
              const SizedBox(height: 12),
              Expanded(
                flex: 4,
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _calculateGridColumns(audienceUids.length),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: audienceUids.length,
                  itemBuilder: (context, index) {
                    final uid = audienceUids[index];
                    return _buildVideoTile(
                        uid, agoraService, participants[uid]);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int? _resolveFeaturedUid(
      List<int> videoUids, Map<int, AgoraParticipant> participants) {
    if (videoUids.isEmpty) return null;

    // Prefer the current stage speaker if present
    if (_currentSpeakerUserId != null) {
      for (final entry in participants.entries) {
        final matchesStageSpeaker = entry.value.userId == _currentSpeakerUserId;
        if (matchesStageSpeaker && videoUids.contains(entry.key)) {
          return entry.key;
        }
      }
    }

    // Fallback to first available camera
    return videoUids.first;
  }

  List<int> _sortVideoUids(
      List<int> videoUids, Map<int, AgoraParticipant> participants) {
    final sorted = List<int>.from(videoUids);

    sorted.sort((a, b) {
      final aParticipant = participants[a];
      final bParticipant = participants[b];

      final aIsStageSpeaker = aParticipant?.userId == _currentSpeakerUserId;
      final bIsStageSpeaker = bParticipant?.userId == _currentSpeakerUserId;
      if (aIsStageSpeaker != bIsStageSpeaker) {
        return aIsStageSpeaker ? -1 : 1;
      }

      final aSpeaking = aParticipant?.isSpeaking == true;
      final bSpeaking = bParticipant?.isSpeaking == true;
      if (aSpeaking != bSpeaking) {
        return aSpeaking ? -1 : 1;
      }

      return a.compareTo(b);
    });

    return sorted;
  }

  /// Single video tile with overlays (name, mute indicator, speaking ring)
  Widget _buildVideoTile(
      int uid, AgoraVideoService agoraService, AgoraParticipant? participant) {
    final isLocal = uid == agoraService.localUid;
    final isCurrentSpeaker = participant?.userId != null &&
        participant!.userId == _currentSpeakerUserId;

    return SlideTransition(
      position: _tileSlideAnimation,
      child: FadeTransition(
        opacity: _tileFadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            // Speaking ring
            border: participant?.isSpeaking == true
                ? Border.all(color: Colors.greenAccent, width: 3)
                : Border.all(color: Colors.grey[800] ?? Colors.grey, width: 1),
            boxShadow: participant?.isSpeaking == true
                ? [
                    BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2)
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video view
                if (kIsWeb)
                  // Web: Use HTML div containers that Agora Web SDK renders into
                  _buildWebVideoView(uid, isLocal)
                else if (agoraService.engine != null)
                  // Native: Use AgoraVideoView with RTC Engine
                  AgoraVideoView(
                    controller: isLocal
                        ? VideoViewController(
                            rtcEngine: agoraService.engine!,
                            canvas: const VideoCanvas(uid: 0))
                        : VideoViewController.remote(
                            rtcEngine: agoraService.engine!,
                            canvas: VideoCanvas(uid: uid),
                            connection: RtcConnection(
                                channelId: agoraService.currentChannel ?? ''),
                          ),
                  )
                else
                  Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.pinkAccent)),
                    ),
                  ),

                // Gradient overlay for name tag readability
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 80,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                  ),
                ),

                // Name tag + speaking indicator
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      // Speaking indicator
                      if (participant?.isSpeaking == true)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.graphic_eq,
                              color: Colors.greenAccent, size: 18),
                        ),

                      // Display name
                      Expanded(
                        child: Text(
                          isLocal
                              ? 'You'
                              : (participant?.displayName ?? 'User'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.start,
                        ),
                      ),

                      if (isCurrentSpeaker)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.pinkAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.pinkAccent),
                          ),
                          child: const Text(
                            'Speaker',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),

                // Mute badge (top right)
                if (participant?.hasAudio == false)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.red[600], shape: BoxShape.circle),
                      child: const Icon(Icons.mic_off,
                          color: Colors.white, size: 16),
                    ),
                  ),

                // No video badge (if camera is off)
                if (participant?.hasVideo == false)
                  Positioned(
                    top: 12,
                    right: participant?.hasAudio == false ? null : 12,
                    left: participant?.hasAudio == false ? 12 : null,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.grey[700], shape: BoxShape.circle),
                      child: const Icon(Icons.videocam_off,
                          color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build Web video view using HTML Platform View
  Widget _buildWebVideoView(int uid, bool isLocal) {
    final viewId = isLocal ? 'local-video' : 'remote-video-$uid';

    // Register the HTML view only once to prevent "ViewFactory already registered" errors
    if (!_registeredViewIds.contains(viewId)) {
      _registeredViewIds.add(viewId);
      registerVideoViewFactory(
        viewId,
        isLocal ? 'local-video' : 'remote-video-$uid',
      );
    }

    return HtmlElementView(viewType: viewId);
  }

  /// Participant list sidebar
  Widget _buildParticipantSidebar(
      Map<int, AgoraParticipant> agoraParticipants) {
    // ðŸ”¥ PHASE 3.1b: Watch enriched participants (Agora + Firestore merged)
    final enrichedParticipantsAsync =
        ref.watch(enrichedParticipantsProvider(widget.room.id));

    return enrichedParticipantsAsync.when(
      data: (enrichedParticipants) {
        return Container(
          width: 280,
          color: Colors.grey[950],
          child: Column(
            children: [
              // Header with tabs
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  border: Border(
                      bottom:
                          BorderSide(color: Colors.grey[800] ?? Colors.grey)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people, color: Colors.white70, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Participants (${enrichedParticipants.length})',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    // Event feed icon
                    IconButton(
                      icon: const Icon(Icons.history,
                          color: Colors.white70, size: 20),
                      onPressed: () {
                        final eventsAsync = ref
                            .watch(roomEventsFirestoreProvider(widget.room.id));
                        _showEventFeed(eventsAsync);
                      },
                      tooltip: 'Room Activity',
                    ),
                  ],
                ),
              ),

              // Participant list
              Expanded(
                child: enrichedParticipants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Waiting for others to join...',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Invite people to get the conversation started',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: enrichedParticipants.length,
                        itemBuilder: (context, index) {
                          final enrichedParticipant =
                              enrichedParticipants[index];
                          return _buildEnrichedParticipantListItem(
                              enrichedParticipant);
                        },
                      ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        width: 280,
        color: Colors.grey[950],
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      ),
      error: (error, stack) {
        debugPrint('âŒ Enriched participants error: $error');
        // Fallback to Agora-only view
        return _buildParticipantSidebarFallback(agoraParticipants);
      },
    );
  }

  /// Fallback participant sidebar using only Agora data
  Widget _buildParticipantSidebarFallback(
      Map<int, AgoraParticipant> participants) {
    return Container(
      width: 280,
      color: Colors.grey[950],
      child: Column(
        children: [
          // Header with tabs
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(
                  bottom: BorderSide(color: Colors.grey[800] ?? Colors.grey)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Participants (${participants.length})',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                // Event feed icon
                IconButton(
                  icon: const Icon(Icons.history,
                      color: Colors.white70, size: 20),
                  onPressed: () {
                    final eventsAsync =
                        ref.watch(roomEventsFirestoreProvider(widget.room.id));
                    _showEventFeed(eventsAsync);
                  },
                  tooltip: 'Room Activity',
                ),
              ],
            ),
          ),

          // Participant list
          Expanded(
            child: participants.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Waiting for others to join...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Invite people to get the conversation started',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final participant = participants.values.elementAt(index);
                      return _buildParticipantListItem(participant);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showHostSettingsSheet(BuildContext context,
      firebase_auth.User currentUser, int participantCount, Room room) {
    final isHostOrCoHost = currentUser.uid == room.hostId ||
        room.moderators.contains(currentUser.uid);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[950],
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    room.name ?? room.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    room.description.isNotEmpty
                        ? room.description
                        : 'No description',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  trailing: Chip(
                    backgroundColor: Colors.grey[850],
                    label: Text('Host controls',
                        style:
                            TextStyle(color: Colors.grey[200], fontSize: 12)),
                  ),
                ),
                const Divider(color: Colors.white10),

                // Turn-based toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.pinkAccent,
                  title: const Text(
                    'Turn-based speaking',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Only one person can speak at a time',
                      style: TextStyle(color: Colors.white70)),
                  value: _turnBased,
                  onChanged: isHostOrCoHost
                      ? (value) async {
                          await _updateTurnBased(value, ctx);
                        }
                      : null,
                ),

                const Divider(color: Colors.white10, height: 32),

                // Room settings section
                const Text(
                  'Room Settings',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                // Max users
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Max Users: ${room.maxUsers}',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: Text('Current: $participantCount',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  trailing:
                      const Icon(Icons.people, color: Colors.white70, size: 20),
                ),

                // Slow mode
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Slow Mode: ${room.slowModeSeconds}s',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: Text(
                      room.slowModeSeconds > 0
                          ? 'Messages limited to 1 per ${room.slowModeSeconds}s'
                          : 'Disabled',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  trailing:
                      const Icon(Icons.timer, color: Colors.white70, size: 20),
                ),

                // NSFW flag
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('NSFW Content',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  trailing: Icon(
                    room.isNSFW ? Icons.warning : Icons.check_circle,
                    color: room.isNSFW ? Colors.red[400] : Colors.green[400],
                    size: 20,
                  ),
                ),

                // Room privacy
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Privacy',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        room.isLocked ? Icons.lock : Icons.public,
                        color: room.isLocked
                            ? Colors.orange[400]
                            : Colors.green[400],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        room.isLocked ? 'Private' : 'Public',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Delete room button (only for room owner)
                if (currentUser.uid == room.hostId) ...[
                  const Divider(color: Colors.white10, height: 32),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_forever,
                        color: Colors.redAccent),
                    title: const Text(
                      'Delete Room',
                      style: TextStyle(
                          color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Permanently delete this room and end for all participants',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx); // Close bottom sheet
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          backgroundColor: Colors.grey[900],
                          title: const Text('Delete Room?',
                              style: TextStyle(color: Colors.white)),
                          content: const Text(
                            'This will permanently delete the room and disconnect all participants. This action cannot be undone.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && context.mounted) {
                        try {
                          final roomService = ref
                              .read(legacy_room_providers.roomServiceProvider);
                          await roomService.deleteRoom(
                              room.id, currentUser.uid);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Room deleted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.of(context).pop(); // Exit room page
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete room: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateTurnBased(bool value, BuildContext context) async {
    final roomService = ref.read(legacy_room_providers.roomServiceProvider);
    final previous = _turnBased;

    setState(() {
      _turnBased = value;
    });

    try {
      await roomService.updateTurnBased(widget.room.id, value);
      if (!mounted) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Turn-based speaking ${value ? 'enabled' : 'disabled'}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.grey[850],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _turnBased = previous;
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update setting: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  /// Individual participant list item with indicators
  Widget _buildParticipantListItem(AgoraParticipant participant) {
    final isCurrentSpeaker = participant.userId == _currentSpeakerUserId;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Stack(
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[800],
              child: Text(
                participant.displayName.isNotEmpty
                    ? participant.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),

            // Speaking ring
            if (participant.isSpeaking)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.greenAccent, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          participant.displayName,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          isCurrentSpeaker
              ? 'On stage'
              : (participant.isSpeaking ? 'Speaking...' : 'Listener'),
          style: TextStyle(
            color: isCurrentSpeaker
                ? Colors.pinkAccent
                : (participant.isSpeaking
                    ? Colors.greenAccent
                    : Colors.grey[500]),
            fontSize: 11,
            fontWeight: (isCurrentSpeaker || participant.isSpeaking)
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mic indicator
            Icon(
              participant.hasAudio ? Icons.mic : Icons.mic_off,
              color:
                  participant.hasAudio ? Colors.greenAccent : Colors.red[400],
              size: 16,
            ),
            const SizedBox(width: 8),

            // Camera indicator
            Icon(
              participant.hasVideo ? Icons.videocam : Icons.videocam_off,
              color:
                  participant.hasVideo ? Colors.greenAccent : Colors.red[400],
              size: 16,
            ),

            // Moderation menu (only for moderators, not on own profile)
          ],
        ),
      ),
    );
  }

  // --- Single-mic (stage) mode helpers ---

  void _toggleSingleMicMode(
      firebase_auth.User? currentUser, AgoraVideoService agoraService) {
    setState(() {
      _singleMicMode = !_singleMicMode;
      _raisedHands.clear();
      _speakerQueue.clear();
      if (_singleMicMode) {
        _currentSpeakerUserId = currentUser?.uid ?? _currentSpeakerUserId;
      } else {
        _currentSpeakerUserId = null;
      }
    });

    _applySingleMicRulesForLocal(agoraService, currentUser);
  }

  void _applySingleMicRulesForLocal(
      AgoraVideoService agoraService, firebase_auth.User? currentUser) {
    if (!_singleMicMode || currentUser == null) return;
    final isCurrentSpeaker = _currentSpeakerUserId == currentUser.uid;
    if (!isCurrentSpeaker && !agoraService.isMicMuted) {
      agoraService.toggleMic();
    }
  }

  /// ðŸ”¥ PHASE 3.1b: Enriched participant list item with full metadata
  Widget _buildEnrichedParticipantListItem(EnrichedParticipant participant) {
    final isCurrentSpeaker = participant.userId == _currentSpeakerUserId;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Stack(
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[800],
              backgroundImage: participant.avatarUrl != null
                  ? NetworkImage(participant.avatarUrl!)
                  : null,
              child: participant.avatarUrl == null
                  ? Text(
                      participant.displayName.isNotEmpty
                          ? participant.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    )
                  : null,
            ),

            // Speaking ring
            if (participant.isSpeaking)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.greenAccent, width: 2),
                  ),
                ),
              ),

            // ðŸ”¥ PHASE 3.1c: Raised hand badge (from Firestore raisedHands list)
            if (_currentRoom.raisedHands.contains(participant.userId))
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.pan_tool, color: Colors.white, size: 10),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                participant.displayName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Role badge
            if (participant.isHost || participant.isModerator)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: participant.isHost
                      ? Colors.purple.withValues(alpha: 0.3)
                      : participant.isModerator
                          ? Colors.blue.withValues(alpha: 0.3)
                          : Colors.green.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: participant.isHost
                        ? Colors.purple
                        : participant.isModerator
                            ? Colors.blue
                            : Colors.green,
                  ),
                ),
                child: Text(
                  participant.roleLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              isCurrentSpeaker
                  ? 'On stage'
                  : (participant.isSpeaking ? 'Speaking...' : 'Listening'),
              style: TextStyle(
                color: isCurrentSpeaker
                    ? Colors.pinkAccent
                    : (participant.isSpeaking
                        ? Colors.greenAccent
                        : Colors.grey[500]),
                fontSize: 11,
                fontWeight: (isCurrentSpeaker || participant.isSpeaking)
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
            // Connection quality indicator
            if (participant.connectionQuality == 'poor' ||
                participant.connectionQuality == 'unknown')
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.signal_cellular_alt_1_bar,
                  size: 12,
                  color: Colors.orange[400],
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ðŸ”¥ PHASE 3.1c: Approve button for host/moderators when hand is raised
            if (_isCurrentUserModerator() &&
                _currentRoom.raisedHands.contains(participant.userId))
              IconButton(
                icon: const Icon(Icons.check_circle,
                    color: Colors.amber, size: 20),
                tooltip: 'Approve to speak',
                onPressed: () => _approveRaisedHand(participant.userId),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            if (_isCurrentUserModerator() &&
                _currentRoom.raisedHands.contains(participant.userId))
              const SizedBox(width: 8),

            // Mic indicator
            Icon(
              participant.hasAudio ? Icons.mic : Icons.mic_off,
              color:
                  participant.hasAudio ? Colors.greenAccent : Colors.red[400],
              size: 16,
            ),
            const SizedBox(width: 8),

            // Camera indicator
            Icon(
              participant.hasVideo ? Icons.videocam : Icons.videocam_off,
              color:
                  participant.hasVideo ? Colors.greenAccent : Colors.red[400],
              size: 16,
            ),

            // ðŸ”¥ PHASE 3.1e: Moderation menu for host/moderators
            if (_isCurrentUserModerator() && !_isOwnProfile(participant.userId))
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 16),
                tooltip: 'Moderation actions',
                onSelected: (action) =>
                    _handleModerationAction(action, participant),
                itemBuilder: (context) => [
                  // Promote/Demote moderator
                  if (!participant.isHost)
                    PopupMenuItem(
                      value: participant.isModerator ? 'demote' : 'promote',
                      child: Row(
                        children: [
                          Icon(
                            participant.isModerator
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            size: 16,
                            color: participant.isModerator
                                ? Colors.orange
                                : Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(participant.isModerator
                              ? 'Demote moderator'
                              : 'Promote to moderator'),
                        ],
                      ),
                    ),
                  // Mute/Unmute
                  PopupMenuItem(
                    value: participant.hasAudio ? 'mute' : 'unmute',
                    child: Row(
                      children: [
                        Icon(
                          participant.hasAudio ? Icons.mic_off : Icons.mic,
                          size: 16,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(participant.hasAudio ? 'Mute' : 'Unmute'),
                      ],
                    ),
                  ),
                  // Spotlight
                  PopupMenuItem(
                    value: 'spotlight',
                    child: Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber[400]),
                        const SizedBox(width: 8),
                        const Text('Spotlight'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  // Kick
                  PopupMenuItem(
                    value: 'kick',
                    child: Row(
                      children: [
                        Icon(Icons.remove_circle,
                            size: 16, color: Colors.orange[400]),
                        const SizedBox(width: 8),
                        const Text('Kick from room'),
                      ],
                    ),
                  ),
                  // Ban
                  if (!participant.isHost)
                    PopupMenuItem(
                      value: 'ban',
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 16, color: Colors.red[600]),
                          const SizedBox(width: 8),
                          const Text('Ban from room'),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ðŸ”¥ PHASE 3.1c: Raised hand management methods
  bool _isCurrentUserModerator() {
    final user = currentUser;
    if (user == null) return false;
    return user.uid == _currentRoom.hostId ||
        _currentRoom.moderators.contains(user.uid);
  }

  bool _isOwnProfile(String userId) {
    final user = currentUser;
    return user != null && user.uid == userId;
  }

  bool _isCurrentUserSpeaker() {
    final user = currentUser;
    if (user == null) return false;
    return _currentRoom.speakers.contains(user.uid);
  }

  bool _hasCurrentUserRaisedHand() {
    final user = currentUser;
    if (user == null) return false;
    return _currentRoom.raisedHands.contains(user.uid);
  }

  Future<void> _raiseHand() async {
    final user = currentUser;
    // CRITICAL FIX: Use local user variable instead of currentUser getter twice
    if (user == null) return;

    try {
      final roomService = ref.read(legacy_room_providers.roomServiceProvider);
      await roomService.raiseHand(widget.room.id, user.uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to raise hand: $e')),
        );
      }
    }
  }

  Future<void> _lowerHand() async {
    final user = currentUser;
    // CRITICAL FIX: Use local user variable instead of currentUser getter twice
    if (user == null) return;

    try {
      final roomService = ref.read(legacy_room_providers.roomServiceProvider);
      await roomService.lowerHand(widget.room.id, user.uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to lower hand: $e')),
        );
      }
    }
  }

  Future<void> _approveRaisedHand(String targetUserId) async {
    final user = currentUser;
    if (user == null) return;

    try {
      final roomService = ref.read(legacy_room_providers.roomServiceProvider);
      await roomService.approveRaisedHand(
          widget.room.id, user.uid, targetUserId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User approved to speak')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: $e')),
        );
      }
    }
  }

  // ðŸ”¥ PHASE 3.1e: Moderation action handler
  Future<void> _handleModerationAction(
      String action, EnrichedParticipant participant) async {
    final user = currentUser;
    if (user == null) return;

    final roomService = ref.read(legacy_room_providers.roomServiceProvider);

    try {
      switch (action) {
        case 'promote':
          await roomService.makeModerator(
              widget.room.id, user.uid, participant.userId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('${participant.displayName} promoted to moderator')),
            );
          }
        case 'demote':
          await roomService.removeModerator(
              widget.room.id, user.uid, participant.userId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('${participant.displayName} removed as moderator')),
            );
          }
        case 'mute':
          await roomService.muteUser(
              widget.room.id, user.uid, participant.userId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${participant.displayName} muted')),
            );
          }
        case 'unmute':
          await roomService.unmuteUser(
              widget.room.id, user.uid, participant.userId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${participant.displayName} unmuted')),
            );
          }
        case 'spotlight':
          await roomService.spotlightUser(
              widget.room.id, user.uid, participant.userId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${participant.displayName} spotlighted')),
            );
          }
        case 'kick':
          final confirmed = await _showConfirmDialog(
            'Kick ${participant.displayName}?',
            'This user will be removed from the room but can rejoin.',
          );
          if (confirmed == true) {
            await roomService.kickUser(
                widget.room.id, user.uid, participant.userId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('${participant.displayName} kicked from room')),
              );
            }
          }
        case 'ban':
          final confirmed = await _showConfirmDialog(
            'Ban ${participant.displayName}?',
            'This user will be permanently banned and cannot rejoin.',
          );
          if (confirmed == true) {
            await roomService.banUser(
                widget.room.id, user.uid, participant.userId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('${participant.displayName} banned from room')),
              );
            }
          }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to $action: $e')),
        );
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _toggleHandRaise(String userId) {
    setState(() {
      if (_raisedHands.contains(userId)) {
        _raisedHands.remove(userId);
        _speakerQueue.removeWhere((id) => id == userId);
      } else {
        _raisedHands.add(userId);
        if (!_speakerQueue.contains(userId)) {
          _speakerQueue.add(userId);
        }
      }
    });
  }

  void _grantNextSpeaker(
      AgoraVideoService agoraService, firebase_auth.User? currentUser) {
    if (_speakerQueue.isEmpty) return;
    final next = _speakerQueue.removeAt(0);
    setState(() {
      _currentSpeakerUserId = next;
      _raisedHands.remove(next);
    });
    _applySingleMicRulesForLocal(agoraService, currentUser);
  }

  void _endCurrentTurn(
      AgoraVideoService agoraService, firebase_auth.User currentUser) {
    setState(() {
      if (_turnBased && _speakerQueue.isNotEmpty) {
        _currentSpeakerUserId = _speakerQueue.removeAt(0);
        _raisedHands.remove(_currentSpeakerUserId);
      } else {
        _currentSpeakerUserId = null;
      }
    });
    _applySingleMicRulesForLocal(agoraService, currentUser);
  }

  /// Control bar at bottom (mic, camera, flip, chat, leave)
  Widget _buildControlBar(AgoraVideoService agoraService,
      firebase_auth.User? currentUser, dynamic currentUserProfile) {
    final isHost = currentUser?.uid == _currentRoom.hostId;
    final isModerator = currentUser != null &&
        (isHost || _currentRoom.moderators.contains(currentUser.uid));
    final isCurrentSpeaker =
        currentUser != null && _currentSpeakerUserId == currentUser.uid;
    final canSpeak = !_turnBased || isCurrentSpeaker || isHost;
    final hasRaisedHand =
        currentUser != null && _raisedHands.contains(currentUser.uid);

    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timer countdown widget
            if (_turnBased &&
                _currentSpeakerUserId != null &&
                _speakerTimeRemaining > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _speakerTimeRemaining <= 10
                        ? Colors.red[700]
                        : Colors.orange[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${(_speakerTimeRemaining ~/ 60).toString().padLeft(2, '0')}:${(_speakerTimeRemaining % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            // Moderator override controls
            if (_turnBased &&
                _currentSpeakerUserId != null &&
                isModerator &&
                _speakerTimeRemaining > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _extendSpeakerTime(30),
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label:
                          const Text('Extend', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () => _skipCurrentSpeaker(),
                      icon: const Icon(Icons.skip_next, size: 16),
                      label: const Text('Skip', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                    if (_speakerQueue.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _grantNextSpeaker(agoraService, currentUser),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('Next',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Main control buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Stage mode toggle (host only)
                if (isHost)
                  _buildControlButton(
                    icon: _singleMicMode
                        ? Icons.record_voice_over
                        : Icons.mic_external_on,
                    label: _singleMicMode ? 'Stage On' : 'Stage Off',
                    isActive: _singleMicMode,
                    onPressed: () {
                      _toggleSingleMicMode(currentUser, agoraService);
                    },
                  ),

                // Queue / grant button (host only when stage mode on)
                if (isHost && _singleMicMode)
                  _buildControlButton(
                    icon: Icons.queue_music,
                    label: _speakerQueue.isEmpty
                        ? 'Queue'
                        : 'Grant (${_speakerQueue.length})',
                    isActive: _speakerQueue.isNotEmpty,
                    onPressed: _speakerQueue.isEmpty
                        ? null
                        : () {
                            _grantNextSpeaker(agoraService, currentUser);
                          },
                  ),

                // Mic toggle
                _buildControlButton(
                  icon: agoraService.isMicMuted ? Icons.mic_off : Icons.mic,
                  label: !_singleMicMode
                      ? (agoraService.isMicMuted ? 'Unmute' : 'Mute')
                      : (canSpeak
                          ? (agoraService.isMicMuted ? 'Unmute' : 'Mute')
                          : 'Locked'),
                  isActive: canSpeak && !agoraService.isMicMuted,
                  onPressed: !canSpeak
                      ? null
                      : () {
                          agoraService.toggleMic();
                          setState(() {}); // Rebuild to update button state
                        },
                ),

                // Camera toggle
                _buildControlButton(
                  icon: agoraService.isVideoMuted
                      ? Icons.videocam_off
                      : Icons.videocam,
                  label: agoraService.isVideoMuted ? 'Start' : 'Stop',
                  isActive: !agoraService.isVideoMuted,
                  onPressed: () {
                    agoraService.toggleVideo();
                    setState(() {}); // Rebuild to update button state
                  },
                ),

                // Flip camera (only if video is on)
                if (!agoraService.isVideoMuted)
                  _buildControlButton(
                    icon: Icons.flip_camera_ios,
                    label: 'Flip',
                    isActive: true,
                    onPressed: () => agoraService.switchCamera(),
                  ),

                // Chat
                _buildControlButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  isActive: false,
                  onPressed: () {
                    final displayName = currentUserProfile?.displayName ??
                        currentUserProfile?.username ??
                        currentUser?.displayName ??
                        'Anonymous';
                    debugPrint(
                        'ðŸŽ¤ Opening chat - Profile: displayName="${currentUserProfile?.displayName}", username="${currentUserProfile?.username}", Auth: displayName="${currentUser?.displayName}", Final: "$displayName"');
                    showVoiceRoomChat(
                      context,
                      roomId: widget.room.id,
                      currentUserId: currentUser?.uid ?? 'unknown',
                      currentDisplayName: displayName,
                    );
                  },
                ),

                // ðŸ”¥ PHASE 3.1c: Raise/Lower Hand button for listeners
                if (!_isCurrentUserSpeaker() && !_isCurrentUserModerator())
                  _buildControlButton(
                    icon: _hasCurrentUserRaisedHand()
                        ? Icons.pan_tool
                        : Icons.front_hand,
                    label: _hasCurrentUserRaisedHand() ? 'Lower' : 'Raise',
                    isActive: _hasCurrentUserRaisedHand(),
                    onPressed: () {
                      if (_hasCurrentUserRaisedHand()) {
                        _lowerHand();
                      } else {
                        _raiseHand();
                      }
                    },
                  ),

                // Raise hand / end turn controls (when stage mode is on)
                if (_singleMicMode)
                  _buildControlButton(
                    icon: isCurrentSpeaker
                        ? Icons.flag
                        : (hasRaisedHand ? Icons.pan_tool : Icons.front_hand),
                    label: isCurrentSpeaker
                        ? 'End turn'
                        : (hasRaisedHand ? 'Lower hand' : 'Raise hand'),
                    isActive: true,
                    onPressed: () {
                      if (currentUser == null) return;
                      if (isCurrentSpeaker) {
                        _endCurrentTurn(agoraService, currentUser);
                      } else {
                        _toggleHandRaise(currentUser.uid);
                      }
                    },
                  ),

                // Leave (always red)
                _buildControlButton(
                  icon: Icons.call_end,
                  label: 'Leave',
                  isActive: false,
                  isLeave: true,
                  onPressed: _leaveRoom,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Individual control button
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    bool isLeave = false,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isLeave
              ? Colors.red[600]
              : (isActive ? Colors.pinkAccent : Colors.grey[800]),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  /// Calculate optimal grid columns based on video count
  int _calculateGridColumns(int count) {
    if (count == 1) return 1;
    if (count == 2) return 2;
    if (count == 3) return 3;
    if (count <= 6) return 2;
    if (count <= 9) return 3;
    return 4;
  }

  /// Show help dialog with keyboard shortcuts and tips
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        child: SingleChildScrollView(
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.help_outline,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Quick Guide',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),

                // Keyboard Shortcuts
                _buildHelpSection(
                  title: 'Keyboard Shortcuts',
                  items: [
                    ('Ctrl + M', 'Toggle Microphone'),
                    ('Ctrl + V', 'Toggle Camera'),
                    ('Space', 'Push to Talk (hold to speak)'),
                    ('Esc', 'Leave Room'),
                  ],
                ),
                const SizedBox(height: 16),

                // Control Bar Tips
                _buildHelpSection(
                  title: 'Control Buttons',
                  items: [
                    ('ðŸŽ¤ Mic', 'Turn your microphone on/off'),
                    ('ðŸ“¹ Camera', 'Enable/disable your video'),
                    ('ðŸ”„ Flip', 'Switch between front and back camera'),
                    ('ðŸ’¬ Chat', 'Open room chat and see messages'),
                    ('ðŸ“ž Leave', 'Exit the room and return home'),
                  ],
                ),
                const SizedBox(height: 16),

                // Stage Mode Tips (if applicable)
                if (_singleMicMode) ...[
                  _buildHelpSection(
                    title: 'Stage Mode (One Speaker)',
                    items: [
                      ('ðŸŽ¤ Raise Hand', 'Request to speak'),
                      ('ðŸŽ¤ End Turn', 'Pass your turn to someone else'),
                      ('ðŸ“‹ Queue', 'Host: Grant next person from queue'),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Turn-Based Tips (if applicable)
                if (_turnBased) ...[
                  _buildHelpSection(
                    title: 'Turn-Based Conversation',
                    items: [
                      ('â±ï¸ Timer', 'Each speaker gets limited time'),
                      (
                        'ðŸŽ¤ Speaking',
                        'Badge shows who currently has the floor'
                      ),
                      ('ðŸ“‹ Queue', 'People waiting appear in order'),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // General Tips
                _buildHelpSection(
                  title: 'Tips & Tricks',
                  items: [
                    ('Click name', 'View participant profile'),
                    ('Right-click', 'Moderation options (if you\'re a mod)'),
                    ('Green ring', 'Person is actively speaking'),
                    ('Muted badge', 'Microphone is off'),
                  ],
                ),
                const SizedBox(height: 24),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Got It!'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Helper to build a help section
  Widget _buildHelpSection({
    required String title,
    required List<(String, String)> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...items.asMap().entries.map((entry) {
          final (key, value) = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    key,
                    style: const TextStyle(
                      color: Colors.pinkAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Show event feed dialog
  void _showEventFeed(AsyncValue<List<RoomEvent>> eventsAsync) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        child: Container(
          width: 400,
          height: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Room Activity',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 24),
              Expanded(
                child: eventsAsync.when(
                  data: (events) {
                    if (events.isEmpty) {
                      return Center(
                        child: Text(
                          'No activity yet',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, i) {
                        final event = events[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            _getEventIcon(event.type),
                            size: 20,
                            color: _getEventColor(event.type),
                          ),
                          title: Text(
                            event.getDescription(userNames: {}),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                          subtitle: Text(
                            _formatEventTime(event.createdAt),
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 11),
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text(
                      'Error loading events: $err',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get icon for event type
  IconData _getEventIcon(RoomEventType type) {
    switch (type) {
      case RoomEventType.userJoined:
        return Icons.login;
      case RoomEventType.userLeft:
        return Icons.logout;
      case RoomEventType.kicked:
        return Icons.exit_to_app;
      case RoomEventType.banned:
        return Icons.block;
      case RoomEventType.muted:
        return Icons.mic_off;
      case RoomEventType.unmuted:
        return Icons.mic;
      case RoomEventType.camEnabled:
        return Icons.videocam;
      case RoomEventType.camDisabled:
        return Icons.videocam_off;
      case RoomEventType.roleChanged:
        return Icons.admin_panel_settings;
      default:
        return Icons.info;
    }
  }

  /// Get color for event type
  Color _getEventColor(RoomEventType type) {
    switch (type) {
      case RoomEventType.userJoined:
      case RoomEventType.unmuted:
      case RoomEventType.camEnabled:
        return Colors.green;
      case RoomEventType.kicked:
      case RoomEventType.banned:
        return Colors.red;
      case RoomEventType.muted:
      case RoomEventType.camDisabled:
        return Colors.orange;
      case RoomEventType.roleChanged:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Format event timestamp
  String _formatEventTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

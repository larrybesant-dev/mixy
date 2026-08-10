import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/room_model.dart';
import '../../../models/room_participant_model.dart';
import '../../../core/theme.dart';
import '../../../core/firestore/firestore_error_utils.dart';
import '../../../core/telemetry/app_telemetry.dart';
import '../../../services/diagnostic_logger.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../services/connection_recovery_handler.dart';
import '../../../services/connection_health_check.dart';
import 'room_management_modal.dart';
import '../room_controller.dart';
import '../providers/room_webrtc_provider.dart';
import '../providers/room_session_provider.dart';
import '../providers/participant_providers.dart';
import '../providers/mic_access_provider.dart';
import '../providers/cam_view_request_provider.dart';
import '../providers/presence_provider.dart';
import '../providers/connection_recovery_provider.dart';
import '../providers/room_gift_provider.dart';
import '../providers/gift_effect_queue_provider.dart';
import '../widgets/network_health_widget.dart';
import '../widgets/recovery_badge.dart';
import '../widgets/connection_failed_overlay.dart';
import '../widgets/mic_queue_panel.dart';
import '../widgets/room_control_sheets.dart';
import '../widgets/user_list_panel.dart';
import '../widgets/room_text_utils.dart';
import '../widgets/room_rank_diamond_badge_row.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../widgets/floating_gift_animation.dart';
import '../../../widgets/gift_ticker_widget.dart';
import '../../../widgets/room_gift_picker_sheet.dart';

class LiveRoomScreen extends ConsumerStatefulWidget {
  final String roomId;

  const LiveRoomScreen({
    super.key,
    required this.roomId,
  });

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _RoomAnnouncementMarquee extends StatefulWidget {
  const _RoomAnnouncementMarquee({
    required this.text,
    required this.textStyle,
  });

  final String text;
  final TextStyle textStyle;

  @override
  State<_RoomAnnouncementMarquee> createState() => _RoomAnnouncementMarqueeState();
}

class _RoomAnnouncementMarqueeState extends State<_RoomAnnouncementMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeText = widget.text.trim().isEmpty
        ? 'Welcome to MixVy Live'
        : widget.text.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 28,
        color: const Color(0x220B0B0B),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final progress = _controller.value;
                final start = width;
                final end = -width;
                final dx = start + (end - start) * progress;
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: child,
                );
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '  📣 $safeText  ',
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: widget.textStyle,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen>
    with WidgetsBindingObserver, DiagnosticLogger {
  late TextEditingController messageController;
  late ScrollController scrollController;
  String? _lastSeenGiftId;
  final Map<String, Timer> _giftEffectCompletionTimers = <String, Timer>{};
  String? _activeRainUserId;
  Timer? _activeRainTimer;
  int _gridSlotCount = 12;
  bool _isFollowActionBusy = false;
  bool _isJoiningRoom = false;
  bool _hasAttemptedAutoJoin = false;
  bool _isCamRequestDialogOpen = false;
  final Map<String, String> _resolvedUserNameCache = <String, String>{};
  final Set<String> _handledCamRequestIds = <String>{};

  static final RegExp _generatedHandlePattern = RegExp(
    r'^(User|Guest|Member)\s+[A-Z0-9]{1,6}$',
  );

  List<RoomParticipantModel> _projectParticipantsForRoster({
    required List<RoomParticipantModel> participants,
    required RoomSessionState sessionState,
    required User? currentUser,
    required RoomModel room,
  }) {
    final user = currentUser;
    final currentUserId = user?.uid ?? '';
    if (currentUserId.isEmpty) return participants;
    if (user == null) return participants;

    final now = DateTime.now();
    final projectedMicOn = sessionState.hasJoined && sessionState.isAudioEnabled;
    final projectedCamOn = sessionState.hasJoined && sessionState.isVideoEnabled;
    final profileName = (ref.read(userProvider)?.username ?? '').trim();
    final cachedSessionName =
        (sessionState.userDisplayNames[currentUserId] ?? '').trim();
    final cachedResolvedName = _resolvedUserNameCache[currentUserId]?.trim() ?? '';
    final authDisplayName = _displayNameFromAuthUser(user).trim();

    String resolveRosterDisplayName(String? existingDisplayName) {
      if (profileName.isNotEmpty && !_isPlaceholderIdentity(profileName)) {
        return profileName;
      }
      if (cachedSessionName.isNotEmpty &&
          !_isPlaceholderIdentity(cachedSessionName)) {
        return cachedSessionName;
      }
      final existing = existingDisplayName?.trim() ?? '';
      if (existing.isNotEmpty && !_isPlaceholderIdentity(existing)) {
        return existing;
      }
      if (cachedResolvedName.isNotEmpty && !_isPlaceholderIdentity(cachedResolvedName)) {
        return cachedResolvedName;
      }
      return authDisplayName;
    }

    String resolvedRole = 'audience';
    if (room.hostId == currentUserId) {
      resolvedRole = 'host';
    } else if (room.ownerId == currentUserId) {
      resolvedRole = 'owner';
    } else if (room.adminUserIds.contains(currentUserId)) {
      resolvedRole = 'cohost';
    }

    final index = participants.indexWhere((p) => p.userId == currentUserId);
    if (index >= 0) {
      final current = participants[index];
      final updated = current.copyWith(
        role: current.role.trim().isNotEmpty ? current.role : resolvedRole,
        displayName: resolveRosterDisplayName(current.displayName),
        photoUrl: user.photoURL,
        micOn: projectedMicOn,
        camOn: projectedCamOn,
        lastActiveAt: now,
      );
      return [
        ...participants.take(index),
        updated,
        ...participants.skip(index + 1),
      ];
    }

    return [
      ...participants,
      RoomParticipantModel(
        userId: currentUserId,
        role: resolvedRole,
        displayName: resolveRosterDisplayName(null),
        photoUrl: user.photoURL,
        micOn: projectedMicOn,
        camOn: projectedCamOn,
        joinedAt: now,
        lastActiveAt: now,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    messageController = TextEditingController();
    scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    messageController.dispose();
    scrollController.dispose();
    _activeRainTimer?.cancel();
    for (final timer in _giftEffectCompletionTimers.values) {
      timer.cancel();
    }
    _giftEffectCompletionTimers.clear();
    // Note: sessionState will be automatically cleaned up when room is left
    super.dispose();
  }

  void _triggerCamMoneyRain(String targetUserId) {
    if (targetUserId.trim().isEmpty) return;
    _activeRainTimer?.cancel();
    setState(() {
      _activeRainUserId = targetUserId;
    });
    _activeRainTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _activeRainUserId = null;
      });
    });
  }

  /// Fetch the user's display name from Firestore profile.
  Future<String> _getUserDisplayName(String uid) async {
    try {
      final firestore = ref.read(firestoreProvider);
      final userDoc = await firestore.collection('users').doc(uid).get();
      final data = userDoc.data();
      final displayName = (data?['displayName'] as String?)?.trim() ?? '';
      final username = (data?['username'] as String?)?.trim() ?? '';

      if (displayName.isNotEmpty && !_isPlaceholderIdentity(displayName)) {
        return displayName;
      }
      if (username.isNotEmpty && !_isPlaceholderIdentity(username)) {
        return username;
      }

      final authUser = ref.read(firebaseAuthProvider).currentUser;
      if (authUser != null && authUser.uid == uid) {
        return _displayNameFromAuthUser(authUser);
      }

      return _memberFallback(uid);
    } catch (e) {
      final authUser = ref.read(firebaseAuthProvider).currentUser;
      if (authUser != null && authUser.uid == uid) {
        return _displayNameFromAuthUser(authUser);
      }
      return _memberFallback(uid);
    }
  }

  bool _isPlaceholderIdentity(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return true;
    if (normalized == 'Anonymous' || normalized == 'MixVy Member') return true;
    return _generatedHandlePattern.hasMatch(normalized);
  }

  String _memberFallback(String uid) {
    final compact = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (compact.isEmpty) return 'MixVy Member';
    final suffix = compact.substring(0, compact.length < 4 ? compact.length : 4);
    return 'Member $suffix';
  }

  String _displayNameFromAuthUser(User user) {
    final displayName = user.displayName?.trim() ?? '';
    if (displayName.isNotEmpty && !_isPlaceholderIdentity(displayName)) {
      return displayName;
    }
    final email = user.email?.trim() ?? '';
    if (email.isNotEmpty && email.contains('@')) {
      final localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) {
        return localPart;
      }
    }
    return _memberFallback(user.uid);
  }

  Future<void> _joinCurrentUserToRoom(User currentUser) async {
    if (_isJoiningRoom) return;
    setState(() => _isJoiningRoom = true);
    try {
      final displayName = await _getUserDisplayName(currentUser.uid);
      if (!mounted) return;

      final controller = ref.read(roomControllerProvider(widget.roomId).notifier);
      final result = await controller.joinRoom(
        currentUser.uid,
        displayName: displayName,
        avatarUrl: currentUser.photoURL,
      );

      if (!mounted) return;
      if (result.isSuccess) {
        final resolvedName = displayName.trim().isNotEmpty
            ? displayName.trim()
            : _displayNameFromAuthUser(currentUser);
        final sessionNotifier = ref.read(roomSessionProvider(widget.roomId).notifier);
        sessionNotifier.updateDisplayName(currentUser.uid, resolvedName);
        sessionNotifier.setJoined(true);
        await ref.read(activeRoomWebRTCProvider(widget.roomId).notifier).joinAsAudience();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.errormessage ?? 'Could not enter room. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error entering room: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isJoiningRoom = false);
      }
    }
  }

  void _ensureAutoJoined({
    required User? currentUser,
    required RoomSessionState sessionState,
  }) {
    if (_hasAttemptedAutoJoin || sessionState.hasJoined || currentUser == null) {
      return;
    }
    _hasAttemptedAutoJoin = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_joinCurrentUserToRoom(currentUser));
    });
  }

  String _resolveHostLabel(
    RoomModel room,
    User? currentUser, {
    String selfResolvedName = '',
  }) {
    if (currentUser != null &&
        (room.hostId == currentUser.uid || room.ownerId == currentUser.uid)) {
      if (selfResolvedName.isNotEmpty &&
          !_isPlaceholderIdentity(selfResolvedName)) {
        return selfResolvedName;
      }
      return _displayNameFromAuthUser(currentUser);
    }

    final hostName = room.hostUsername?.trim() ?? '';
    if (hostName.isNotEmpty && !_isPlaceholderIdentity(hostName)) {
      return hostName;
    }

    final hostId = room.hostId.trim().isNotEmpty ? room.hostId : room.ownerId;
    return hostId.trim().isNotEmpty ? _memberFallback(hostId) : 'MixVy Member';
  }

  Future<void> _leaveRoom() async {
    try {
      final auth = ref.read(firebaseAuthProvider);
      final currentUser = auth.currentUser;
      if (currentUser == null) return;

      final firestore = ref.read(firestoreProvider);
      final roomRef = firestore.collection('rooms').doc(widget.roomId);
      
      // Get current room state to remove matching avatar URL
      final roomDoc = await roomRef.get();
      final roomData = roomDoc.data();
      String? avatarUrlToRemove;
      
      if (roomData != null) {
        final audienceIds = List<String>.from(roomData['audienceUserIds'] ?? []);
        final avatarUrls = List<String>.from(roomData['audienceUserAvatarUrls'] ?? []);
        
        // Find the index of current user and get matching avatar URL
        final userIndex = audienceIds.indexOf(currentUser.uid);
        if (userIndex >= 0 && userIndex < avatarUrls.length) {
          avatarUrlToRemove = avatarUrls[userIndex];
        }
      }
      
      // Delete participant doc
      await roomRef.collection('participants').doc(currentUser.uid).delete();
      
      // Update room
      await roomRef.update({
        'audienceUserIds': FieldValue.arrayRemove([currentUser.uid]),
        if (avatarUrlToRemove != null)
          'audienceUserAvatarUrls': FieldValue.arrayRemove([avatarUrlToRemove]),
        'memberCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await ref.read(activeRoomWebRTCProvider(widget.roomId).notifier).disconnect();
      ref.read(roomSessionProvider(widget.roomId).notifier).reset();
    } catch (e) {
      debugPrint('Error leaving room: $e');
    } finally {
      if (mounted) {
        context.go('/rooms');
      }
    }
  }

  Future<void> _syncParticipantMediaFlags({bool? camOn, bool? micOn}) async {
    final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (userId == null || userId.isEmpty) return;

    final payload = <String, Object?>{
      'lastActiveAt': FieldValue.serverTimestamp(),
      if (camOn != null) 'camOn': camOn,
      if (micOn != null) 'micOn': micOn,
    };

    await ref
        .read(firestoreProvider)
        .collection('rooms')
        .doc(widget.roomId)
        .collection('participants')
        .doc(userId)
        .set(payload, SetOptions(merge: true));
  }

  Future<void> _toggleVideo(bool enabled) async {
    final sessionNotifier = ref.read(roomSessionProvider(widget.roomId).notifier);
    final previous = ref.read(roomSessionProvider(widget.roomId)).isVideoEnabled;
    sessionNotifier.setVideoEnabled(enabled);

    try {
      await ref.read(activeRoomWebRTCProvider(widget.roomId).notifier).toggleVideo(enabled);
      await _syncParticipantMediaFlags(camOn: enabled);
    } catch (e) {
      sessionNotifier.setVideoEnabled(previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera toggle failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleAudio(bool enabled) async {
    final sessionNotifier = ref.read(roomSessionProvider(widget.roomId).notifier);
    final previous = ref.read(roomSessionProvider(widget.roomId)).isAudioEnabled;
    sessionNotifier.setAudioEnabled(enabled);

    try {
      await ref.read(activeRoomWebRTCProvider(widget.roomId).notifier).toggleAudio(enabled);
      await _syncParticipantMediaFlags(micOn: enabled);
    } catch (e) {
      sessionNotifier.setAudioEnabled(previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mic toggle failed: $e')),
        );
      }
    }
  }

  void _toggleAudioSharing(bool enabled) {
    ref.read(roomSessionProvider(widget.roomId).notifier).setAudioSharingEnabled(enabled);
    ref.read(activeRoomWebRTCProvider(widget.roomId).notifier).toggleSystemAudioSharing(enabled).catchError((e) {
      // Revert UI state on error
      if (mounted) {
        ref.read(roomSessionProvider(widget.roomId).notifier).setAudioSharingEnabled(!enabled);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share audio: $e')),
        );
      }
    });
  }

  Future<void> _presentCamViewRequest({
    required CamViewRequest request,
    required String ownerUserId,
  }) async {
    if (_isCamRequestDialogOpen || _handledCamRequestIds.contains(request.id)) {
      return;
    }

    _isCamRequestDialogOpen = true;
    _handledCamRequestIds.add(request.id);

    try {
      final requesterLabel = (request.requesterName?.trim().isNotEmpty ?? false)
          ? request.requesterName!.trim()
          : _memberFallback(request.requesterId);

      final approved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: VelvetNoir.surfaceHigh,
            title: Text(
              'Camera request',
              style: GoogleFonts.playfairDisplay(
                color: VelvetNoir.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              '$requesterLabel wants to view your camera.',
              style: GoogleFonts.raleway(
                color: VelvetNoir.onSurface,
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  'Deny',
                  style: GoogleFonts.raleway(color: Colors.redAccent),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetNoir.primary,
                  foregroundColor: VelvetNoir.surface,
                ),
                child: Text(
                  'Allow',
                  style: GoogleFonts.raleway(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      );

      if (approved == null) {
        _handledCamRequestIds.remove(request.id);
        return;
      }

      if (approved) {
        await ref
            .read(roomControllerProvider(widget.roomId).notifier)
            .approveCameraViewer(
              ownerUserId: ownerUserId,
              viewerUserId: request.requesterId,
              approved: true,
            );
      }

      await ref.read(camViewRequestControllerProvider).respondToRequest(
            roomId: widget.roomId,
            requestId: request.id,
            approved: approved,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Camera access granted.'
                : 'Camera request denied.',
          ),
        ),
      );
    } catch (e) {
      _handledCamRequestIds.remove(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera request failed: $e')),
      );
    } finally {
      _isCamRequestDialogOpen = false;
    }
  }

  Future<void> _handleRosterUserTap({
    required RoomParticipantModel participant,
    required String currentUserId,
    required String currentUserLabel,
  }) async {
    final roomState = ref.read(roomControllerProvider(widget.roomId));
    if (currentUserId.isNotEmpty &&
        roomState.canManageStage(currentUserId) &&
        participant.userId != currentUserId) {
      await _showParticipantActionSheet(
        participant: participant,
        currentUserId: currentUserId,
      );
      return;
    }

    await _requestCameraViewAccess(
      participant: participant,
      currentUserId: currentUserId,
      currentUserLabel: currentUserLabel,
    );
  }

  Future<void> _requestCameraViewAccess({
    required RoomParticipantModel participant,
    required String currentUserId,
    required String currentUserLabel,
  }) async {
    final normalizedCurrentUserId = currentUserId.trim();
    final targetUserId = participant.userId.trim();
    if (normalizedCurrentUserId.isEmpty || targetUserId.isEmpty) {
      return;
    }

    final displayName =
        (participant.displayName?.trim().isNotEmpty ?? false)
            ? participant.displayName!.trim()
            : targetUserId;

    if (targetUserId == normalizedCurrentUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This is your camera tile.')),
        );
      }
      return;
    }

    if (!participant.camOn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$displayName camera is currently off.')),
        );
      }
      return;
    }

    final roomState = ref.read(roomControllerProvider(widget.roomId));
    final alreadyAllowed = roomState.canViewCamera(
      targetUserId: targetUserId,
      viewerUserId: normalizedCurrentUserId,
    );
    if (alreadyAllowed) {
      if (mounted) {
        final audioHint = participant.micOn && !participant.isMuted
            ? ''
            : ' They are not broadcasting mic audio right now.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Camera access already allowed for $displayName.$audioHint',
            ),
          ),
        );
      }
      return;
    }

    try {
      final canApproveDirectly =
          roomState.canManageStage(normalizedCurrentUserId) ||
          normalizedCurrentUserId == targetUserId;

      if (canApproveDirectly) {
        await ref
            .read(roomControllerProvider(widget.roomId).notifier)
            .approveCameraViewer(
              ownerUserId: targetUserId,
              viewerUserId: normalizedCurrentUserId,
              approved: true,
            );
        if (mounted) {
          final audioHint = participant.micOn && !participant.isMuted
              ? ''
              : ' They are not broadcasting mic audio right now.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Camera access granted for $displayName.$audioHint',
              ),
            ),
          );
        }
        return;
      }

      await ref.read(camViewRequestControllerProvider).sendRequest(
        roomId: widget.roomId,
        requesterId: normalizedCurrentUserId,
        targetId: targetUserId,
        requesterName: currentUserLabel,
      );

      if (mounted) {
        final audioHint = participant.micOn && !participant.isMuted
            ? ''
            : ' They are not broadcasting mic audio right now.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Camera view request sent to $displayName.$audioHint',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open camera for $displayName: $e')),
        );
      }
    }
  }

  Future<void> _showParticipantActionSheet({
    required RoomParticipantModel participant,
    required String currentUserId,
  }) async {
    final currentUser = ref.read(firebaseAuthProvider).currentUser;
    final currentRoomMap = ref.read(roomDocLiveProvider(widget.roomId)).valueOrNull;
    final room = currentRoomMap == null
        ? null
        : RoomModel.fromJson(currentRoomMap, widget.roomId);
    final displayName =
        (participant.displayName?.trim().isNotEmpty ?? false)
            ? participant.displayName!.trim()
            : _memberFallback(participant.userId);
    final isOnMic = participant.micOn ||
        ref.read(roomControllerProvider(widget.roomId)).isOnMicByAuthority(participant.userId);
    final seatLimit = (room?.maxBroadcasters ?? 1).clamp(1, 4);
    final activeSpeakers = ref
        .read(roomControllerProvider(widget.roomId))
        .speakerIds
        .where((id) => id != participant.userId)
        .toList(growable: false);
    final inviteLabel = seatLimit == 1 && activeSpeakers.isNotEmpty
        ? 'Pass mic to $displayName'
        : 'Invite to mic';

    final actions = <RoomActionItem>[
      if (!isOnMic)
        RoomActionItem(
          label: inviteLabel,
          icon: Icons.record_voice_over_rounded,
          onTap: () async {
            Navigator.of(context).pop();
            await ref
                .read(roomControllerProvider(widget.roomId).notifier)
                .inviteUserToMic(userId: participant.userId);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$displayName is invited to the mic.')),
            );
          },
        )
      else
        RoomActionItem(
          label: 'Remove from mic',
          icon: Icons.mic_off_rounded,
          destructive: true,
          onTap: () async {
            Navigator.of(context).pop();
            await ref
                .read(roomControllerProvider(widget.roomId).notifier)
                .releaseMic(userId: participant.userId);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$displayName was removed from the mic.')),
            );
          },
        ),
      if (participant.camOn)
        RoomActionItem(
          label: 'Request camera view',
          icon: Icons.videocam_outlined,
          onTap: () async {
            Navigator.of(context).pop();
            await _requestCameraViewAccess(
              participant: participant,
              currentUserId: currentUserId,
              currentUserLabel: _displayNameFromAuthUser(
                currentUser ?? FirebaseAuth.instance.currentUser!,
              ),
            );
          },
        ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomParticipantActionSheet(
        participant: participant,
        userPresentation: RoomUserPresentation(
          displayName: displayName,
          avatarUrl: participant.photoUrl,
        ),
        currentUserId: currentUserId,
        hostUserId: room?.hostId ?? '',
        actions: actions,
      ),
    );
  }

  void _showMicQueueSheet({
    required String currentUserId,
    required bool isHostLike,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VelvetNoir.surfaceHigh,
      builder: (sheetContext) => SafeArea(
        child: Consumer(
          builder: (context, sideRef, _) {
            final participants =
                sideRef.watch(roomParticipantsLiveProvider(widget.roomId)).valueOrNull ??
                const [];
            final displayNameById = {
              for (final participant in participants)
                participant.userId: ((participant.displayName?.trim().isNotEmpty ?? false)
                    ? participant.displayName!.trim()
                    : participant.userId),
            };
            final rankTierById = {
              for (final participant in participants) participant.userId: participant.rankTier,
            };
            final diamondById = {
              for (final participant in participants) participant.userId: participant.diamondLevel,
            };

            return Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
              child: MicQueuePanel(
                roomId: widget.roomId,
                currentUserId: currentUserId,
                isHost: isHostLike,
                displayNameById: displayNameById,
                rankTierById: rankTierById,
                diamondLevelById: diamondById,
                onJoinQueue: () {
                  if (currentUserId.isEmpty) return;
                  sideRef
                      .read(roomControllerProvider(widget.roomId).notifier)
                      .requestMic(userId: currentUserId);
                },
                onLeaveQueue: () {
                  if (currentUserId.isEmpty) return;
                  final myRequest = sideRef
                      .read(
                        myMicAccessRequestProvider((
                          roomId: widget.roomId,
                          requesterId: currentUserId,
                        )),
                      )
                      .valueOrNull;
                  if (myRequest == null) return;
                  sideRef
                      .read(roomControllerProvider(widget.roomId).notifier)
                      .cancelMicRequest(myRequest.id);
                },
                onWithdraw: (request) {
                  sideRef
                      .read(roomControllerProvider(widget.roomId).notifier)
                      .cancelMicRequest(request.id);
                },
                onApprove: (request) {
                  sideRef
                      .read(roomControllerProvider(widget.roomId).notifier)
                      .approveMicRequest(request);
                },
                onDeny: (request) {
                  sideRef
                      .read(roomControllerProvider(widget.roomId).notifier)
                      .denyMicRequest(request.id);
                },
                onPromote: (request) {
                  sideRef
                      .read(roomControllerProvider(widget.roomId).notifier)
                      .promoteMicQueueRequest(request.id);
                },
                onDemote: (request) {
                  sideRef
                      .read(roomControllerProvider(widget.roomId).notifier)
                      .demoteMicQueueRequest(request.id);
                },
                onDismiss: (request) {
                  sideRef
                      .read(roomControllerProvider(widget.roomId).notifier)
                      .dismissMicQueueRequest(request.id);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAudioSetupSheet({
    required RoomModel room,
    required User? currentUser,
    required RoomSessionState sessionState,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VelvetNoir.surfaceHigh,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Audio / DJ setup',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: VelvetNoir.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep the live controls focused here and move secondary setup out of the main room column.',
                style: GoogleFonts.raleway(
                  color: VelvetNoir.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  sessionState.isAudioEnabled ? Icons.mic : Icons.mic_off,
                  color: VelvetNoir.primary,
                ),
                title: const Text('Microphone'),
                subtitle: Text(sessionState.isAudioEnabled ? 'Live now' : 'Muted'),
                trailing: Switch.adaptive(
                  value: sessionState.isAudioEnabled,
                  onChanged: (value) => _toggleAudio(value),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  sessionState.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                  color: VelvetNoir.primary,
                ),
                title: const Text('Camera'),
                subtitle: Text(sessionState.isVideoEnabled ? 'Sending video' : 'Camera hidden'),
                trailing: Switch.adaptive(
                  value: sessionState.isVideoEnabled,
                  onChanged: (value) => _toggleVideo(value),
                ),
              ),
              if (kIsWeb)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    sessionState.isAudioSharingEnabled
                        ? Icons.headset
                        : Icons.headset_off,
                    color: VelvetNoir.secondary,
                  ),
                  title: const Text('Share tab / system audio'),
                  subtitle: const Text('Use this for DJ sets or music playback.'),
                  trailing: Switch.adaptive(
                    value: sessionState.isAudioSharingEnabled,
                    onChanged: (value) => _toggleAudioSharing(value),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _showParticipantsPanel(widget.roomId);
                  },
                  icon: const Icon(Icons.people_outline),
                  label: const Text('View participants'),
                ),
              ),
              if (currentUser != null &&
                  (room.hostId == currentUser.uid ||
                      room.ownerId == currentUser.uid ||
                      room.adminUserIds.contains(currentUser.uid))) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _showManagementModal(context, room);
                    },
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Open host controls'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileQuickActions({
    required RoomModel room,
    required User? currentUser,
    required RoomSessionState sessionState,
    required String currentUserId,
    required bool isHostLike,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showParticipantsPanel(widget.roomId),
              icon: const Icon(Icons.people_outline, size: 18),
              label: const Text('People'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showMicQueueSheet(
                currentUserId: currentUserId,
                isHostLike: isHostLike,
              ),
              icon: const Icon(Icons.queue_rounded, size: 18),
              label: Text(isHostLike ? 'Stage Queue' : 'Mic Queue'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => _showAudioSetupSheet(
                room: room,
                currentUser: currentUser,
                sessionState: sessionState,
              ),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Setup'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    try {
      final auth = ref.read(firebaseAuthProvider);
      final currentUser = auth.currentUser;
      if (currentUser == null) return;

      final sessionState = ref.read(roomSessionProvider(widget.roomId));
      final firestore = ref.read(firestoreProvider);
      final fallbackName = _displayNameFromAuthUser(currentUser);
      final cachedName = sessionState.userDisplayNames[currentUser.uid]?.trim() ?? '';
      final senderName = cachedName.isNotEmpty ? cachedName : fallbackName;

      final messageRef = firestore
          .collection('rooms')
          .doc(widget.roomId)
          .collection('messages')
          .doc();
      await messageRef.set({
        'id': messageRef.id,
        'senderId': currentUser.uid,
        'senderName': senderName,
        'roomId': widget.roomId,
        'content': text,
        'createdAt': FieldValue.serverTimestamp(),
        'sentAt': FieldValue.serverTimestamp(),
        'clientSentAt': Timestamp.now(),
      });

      messageController.clear();
      
      // Auto-scroll to bottom
      unawaited(Future.delayed(const Duration(milliseconds: 100), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }));
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void _shareRoom(String roomName) {
    Share.share(
      'Join me in "$roomName" on MIXVY!\nhttps://mixvy-v2.web.app/rooms/room/${widget.roomId}',
      subject: '$roomName – MIXVY live room',
    );
  }

  void _showManagementModal(BuildContext context, RoomModel room) {
    showDialog(
      context: context,
      builder: (context) => RoomManagementModal(
        roomId: widget.roomId,
        room: room,
      ),
    );
  }

  void _showParticipantsPanel(String roomId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Room Participants',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: VelvetNoir.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: VelvetNoir.onSurface,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer(
                builder: (context, consumerRef, _) {
                  final participantsAsync = consumerRef.watch(
                    roomParticipantsLiveProvider(roomId),
                  );
                  final micQueue =
                      consumerRef.watch(roomMicAccessRequestsProvider(roomId)).valueOrNull ??
                      const [];
                  final pendingQueueUserIds = micQueue
                      .where(
                        (request) => request.status == 'pending' && !request.isExpired,
                      )
                      .map((request) => request.requesterId)
                      .toSet();
                  return participantsAsync.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        color: VelvetNoir.primary,
                      ),
                    ),
                    error: (_, __) => Center(
                      child: Text(
                        'Failed to load participants',
                        style: GoogleFonts.raleway(
                          color: VelvetNoir.onSurfaceVariant,
                        ),
                      ),
                    ),
                    data: (participants) {
                      if (participants.isEmpty) {
                        return Center(
                          child: Text(
                            'No participants yet',
                            style: GoogleFonts.raleway(
                              color: VelvetNoir.onSurfaceVariant,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: participants.length,
                        itemBuilder: (context, index) {
                          final participant = participants[index];
                          final userId = participant.userId;
                          final displayName =
                              participant.displayName?.trim().isNotEmpty == true
                              ? participant.displayName!.trim()
                              : 'Anonymous';
                          final role = participant.role;
                          final currentUser = FirebaseAuth.instance.currentUser;
                          final currentUserId = currentUser?.uid ?? '';
                          final currentUserLabel = currentUser == null
                              ? currentUserId
                              : _displayNameFromAuthUser(currentUser);
                          final isYou = userId == currentUserId;
                          final isInQueue = pendingQueueUserIds.contains(userId);

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: currentUserId.isEmpty
                                  ? null
                                  : () => _handleRosterUserTap(
                                        participant: participant,
                                        currentUserId: currentUserId,
                                        currentUserLabel: currentUserLabel,
                                      ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: VelvetNoir.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: VelvetNoir.primary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: role == 'host'
                                          ? VelvetNoir.primary
                                          : VelvetNoir.secondary,
                                      radius: 20,
                                      child: Text(
                                        displayName[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                displayName,
                                                style: GoogleFonts.raleway(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: VelvetNoir.onSurface,
                                                ),
                                              ),
                                              if (isYou)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 8),
                                                  child: Chip(
                                                    label: Text(
                                                      'You',
                                                      style: GoogleFonts.raleway(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    backgroundColor: VelvetNoir.liveGlow,
                                                    labelPadding: const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: role == 'host'
                                                      ? VelvetNoir.primary.withValues(alpha: 0.2)
                                                      : VelvetNoir.secondary.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  role.toUpperCase(),
                                                  style: GoogleFonts.raleway(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: role == 'host'
                                                        ? VelvetNoir.primary
                                                        : VelvetNoir.secondary,
                                                  ),
                                                ),
                                              ),
                                              if (isInQueue)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: VelvetNoir.primary.withValues(alpha: 0.18),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: VelvetNoir.primary.withValues(alpha: 0.45),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'QUEUE',
                                                    style: GoogleFonts.raleway(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: VelvetNoir.primary,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isYou)
                                      Icon(
                                        participant.camOn
                                            ? Icons.videocam_outlined
                                            : Icons.chevron_right,
                                        color: participant.camOn
                                            ? VelvetNoir.primary
                                            : VelvetNoir.onSurfaceVariant,
                                        size: 18,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles audio-only fallback when recovery takes longer than 5+ seconds.
  /// If recovery has been active for more than 1 attempt (>5s due to exponential backoff),
  /// automatically disables video to reduce bandwidth and improve stability.
  void _handleRecoveryTimeout({
    required ConnectionRecoveryState recoveryState,
    required RoomSessionNotifier sessionNotifier,
    required BuildContext context,
    required bool isVideoEnabled,
  }) {
    // Threshold: after 2+ attempts, we've waited 2s + 4s = 6s
    const audioOnlyThreshold = 2;
    
    if (recoveryState.isRecovering &&
        recoveryState.attemptNumber >= audioOnlyThreshold &&
        isVideoEnabled) {
      // Degrade to audio-only
      sessionNotifier.setVideoEnabled(false);
      
      if (context.mounted) {
        // Notify user of degradation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Connection is unstable. Camera disabled for stability. You can re-enable it when connection improves.',
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.orange.shade700,
            action: SnackBarAction(
              label: 'Re-enable Camera',
              textColor: Colors.white,
              onPressed: () {
                sessionNotifier.setVideoEnabled(true);
              },
            ),
          ),
        );
      }
    }
    
    // When recovery succeeds after audio-only degradation, notify user
    if (recoveryState.isConnected &&
        !recoveryState.isRecovering &&
        !isVideoEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Connection recovered! Camera is available again.'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    }
  }

  void _dispatchQueuedGiftEffect(QueuedGiftEffect queuedEffect) {
    final event = queuedEffect.event;
    final definition = queuedEffect.definition;
    final duration = Duration(milliseconds: definition.durationMs);

    switch (definition.type) {
      case GiftEffectType.rainOnCam:
        _triggerCamMoneyRain(event.receiverId);
        break;
      case GiftEffectType.spotlightPulse:
        if (event.receiverId.trim().isNotEmpty) {
          _triggerCamMoneyRain(event.receiverId);
        }
        break;
      case GiftEffectType.confettiBurst:
      case GiftEffectType.emojiTrail:
        break;
    }

    FloatingGiftAnimation.show(
      context,
      emoji: event.emoji,
      duration: duration,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          definition.type == GiftEffectType.rainOnCam
              ? '${event.senderName} sent ${event.emoji} and made it rain on ${event.receiverName ?? 'a guest'}!'
              : '${event.senderName} sent ${event.emoji} to ${event.receiverName ?? 'a guest'}!',
          style: const TextStyle(color: VelvetNoir.onSurface),
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: VelvetNoir.secondary.withValues(alpha: 0.8),
      ),
    );
  }

  void _pumpGiftEffectQueue(WidgetRef ref) {
    if (!mounted) return;
    final queueNotifier = ref.read(giftEffectQueueProvider.notifier);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    while (mounted) {
      final next = queueNotifier.activateNext();
      if (next == null) {
        break;
      }

      final pendingDepth = ref.read(giftEffectQueueProvider).pending.length;
      final qualityTier = _resolveEffectQualityTier(
        definition: next.definition,
        pendingDepth: pendingDepth,
      );
      AppTelemetry.logAction(
        domain: 'room',
        action: 'gift_effect_dispatch_start',
        message: 'Dispatching queued gift effect.',
        roomId: next.event.roomId,
        userId: currentUserId,
        result: 'start',
        metadata: <String, Object?>{
          'effectId': next.definition.effectId,
          'eventId': next.event.eventId,
          'queueDepth': pendingDepth,
          'qualityTier': qualityTier.name,
        },
      );
      if (qualityTier != EffectQualityTier.high) {
        AppTelemetry.recordGiftEffectDegraded(
          roomId: next.event.roomId,
          effectId: next.definition.effectId,
          eventId: next.event.eventId,
          qualityTier: qualityTier.name,
          userId: currentUserId,
          metadata: <String, Object?>{
            'queueDepth': pendingDepth,
          },
        );
      }

      _dispatchQueuedGiftEffect(next);
      _giftEffectCompletionTimers[next.dedupeKey]?.cancel();
      _giftEffectCompletionTimers[next.dedupeKey] = Timer(
        Duration(milliseconds: next.definition.durationMs),
        () {
          _giftEffectCompletionTimers.remove(next.dedupeKey);
          final completed = queueNotifier.markCompleted(next.dedupeKey);
          final now = DateTime.now();
          final latencyMs = now.difference(next.queuedAt).inMilliseconds;
          if (completed) {
            AppTelemetry.recordGiftEffectRendered(
              roomId: next.event.roomId,
              effectId: next.definition.effectId,
              eventId: next.event.eventId,
              latencyMs: latencyMs,
              userId: currentUserId,
              metadata: <String, Object?>{
                'durationMs': next.definition.durationMs,
              },
            );
          } else {
            AppTelemetry.recordGiftEffectDropped(
              roomId: next.event.roomId,
              effectId: next.definition.effectId,
              eventId: next.event.eventId,
              reason: 'completion_missing',
              userId: currentUserId,
            );
          }
          if (!mounted) return;
          _pumpGiftEffectQueue(ref);
        },
      );
    }
  }

  /// Listen to new gift events and route through queue-based effect pipeline.
  void _checkForNewGiftEffects(List<RoomGiftEffectEvent> gifts, WidgetRef ref) {
    if (gifts.isEmpty) {
      _lastSeenGiftId = null;
      return;
    }

    final latestGiftId = gifts.first.eventId;
    if (_lastSeenGiftId == latestGiftId) {
      return;
    }

    final queueNotifier = ref.read(giftEffectQueueProvider.notifier);
    final newlySeen = <RoomGiftEffectEvent>[];
    for (final gift in gifts) {
      if (_lastSeenGiftId != null && gift.eventId == _lastSeenGiftId) {
        break;
      }
      newlySeen.add(gift);
    }

    _lastSeenGiftId = latestGiftId;
    for (final gift in newlySeen.reversed) {
      final definition = GiftEffectCatalog.resolve(gift.effectId);
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      AppTelemetry.recordGiftEffectReceived(
        roomId: gift.roomId,
        effectId: definition.effectId,
        eventId: gift.eventId,
        userId: currentUserId,
        metadata: <String, Object?>{
          'giftId': gift.giftId,
          'coinCost': gift.coinCost,
        },
      );

      final enqueueResult = queueNotifier.enqueueWithResult(gift, definition);
      switch (enqueueResult) {
        case GiftEffectEnqueueResult.enqueued:
          AppTelemetry.logAction(
            domain: 'room',
            action: 'gift_effect_enqueue',
            message: 'Gift effect accepted into queue.',
            roomId: gift.roomId,
            userId: currentUserId,
            result: 'enqueued',
            metadata: <String, Object?>{
              'effectId': definition.effectId,
              'eventId': gift.eventId,
              'pendingDepth': ref.read(giftEffectQueueProvider).pending.length,
            },
          );
          break;
        case GiftEffectEnqueueResult.duplicate:
          AppTelemetry.recordGiftEffectDropped(
            roomId: gift.roomId,
            effectId: definition.effectId,
            eventId: gift.eventId,
            reason: 'duplicate',
            userId: currentUserId,
          );
          break;
        case GiftEffectEnqueueResult.cooldown:
          AppTelemetry.recordGiftEffectDropped(
            roomId: gift.roomId,
            effectId: definition.effectId,
            eventId: gift.eventId,
            reason: 'cooldown',
            userId: currentUserId,
          );
          break;
        case GiftEffectEnqueueResult.overflow:
          AppTelemetry.recordGiftEffectQueueOverflow(
            roomId: gift.roomId,
            effectId: definition.effectId,
            eventId: gift.eventId,
            queueSize: ref.read(giftEffectQueueProvider).pending.length,
            userId: currentUserId,
          );
          break;
      }
    }

    _pumpGiftEffectQueue(ref);
  }

  EffectQualityTier _resolveEffectQualityTier({
    required GiftEffectDefinition definition,
    required int pendingDepth,
  }) {
    if (pendingDepth >= 8) {
      return definition.particleBudgetByTier[EffectQualityTier.low] == 0
          ? EffectQualityTier.off
          : EffectQualityTier.low;
    }
    if (pendingDepth >= 4) {
      return definition.particleBudgetByTier[EffectQualityTier.medium] == 0
          ? EffectQualityTier.low
          : EffectQualityTier.medium;
    }
    return EffectQualityTier.high;
  }

  String _roomAnnouncement(RoomModel room) {
    final rules = room.rules?.trim() ?? '';
    if (rules.isNotEmpty) {
      return rules;
    }
    final description = room.description?.trim() ?? '';
    if (description.isNotEmpty) {
      return description;
    }
    return 'Be respectful. Wait your turn in the mic queue. Support creators with gifts.';
  }

  Future<void> _toggleFollowRoom({
    required String roomId,
    required String userId,
    required bool isFollowing,
  }) async {
    if (_isFollowActionBusy) return;
    setState(() => _isFollowActionBusy = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final docRef = firestore
          .collection('rooms')
          .doc(roomId)
          .collection('followers')
          .doc(userId);
      if (isFollowing) {
        await docRef.delete();
      } else {
        await docRef.set({
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Follow action failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isFollowActionBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final sessionState = ref.watch(roomSessionProvider(widget.roomId));
    final roomDocAsync = currentUser == null
        ? const AsyncValue<Map<String, dynamic>?>.data(null)
        : ref.watch(roomDocLiveProvider(widget.roomId));

    if (currentUser != null) {
      ref.listen<AsyncValue<List<CamViewRequest>>>(
        pendingCamViewRequestsProvider((
          roomId: widget.roomId,
          targetId: currentUser.uid,
        )),
        (_, next) {
          next.whenData((requests) {
            if (!mounted || _isCamRequestDialogOpen) {
              return;
            }

            CamViewRequest? nextRequest;
            for (final request in requests) {
              if (!_handledCamRequestIds.contains(request.id)) {
                nextRequest = request;
                break;
              }
            }
            if (nextRequest == null) {
              return;
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _presentCamViewRequest(
                request: nextRequest!,
                ownerUserId: currentUser.uid,
              );
            });
          });
        },
      );
    }

    RoomModel? parsedRoom;
    final roomDoc = roomDocAsync.valueOrNull;
    if (roomDoc != null) {
      try {
        parsedRoom = RoomModel.fromJson(roomDoc, widget.roomId);
      } catch (_) {
        parsedRoom = null;
      }
    }

    final canManageRoom = parsedRoom != null &&
        ((currentUser?.uid == parsedRoom.ownerId) ||
            parsedRoom.adminUserIds.contains(currentUser?.uid));

    return Scaffold(
      backgroundColor: VelvetNoir.surface,
      appBar: AppBar(
        backgroundColor: VelvetNoir.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (canManageRoom)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _showManagementModal(context, parsedRoom!),
              tooltip: 'Manage room',
            ),
          if (sessionState.hasJoined)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _shareRoom('Live Room'),
              tooltip: 'Share room',
            ),
          if (sessionState.hasJoined)
            IconButton(
              icon: const Icon(Icons.people_outline),
              onPressed: () => _showParticipantsPanel(widget.roomId),
              tooltip: 'Participants',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: currentUser == null
          ? _buildSignInRequiredView(context)
          : roomDocAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _buildRoomLoadError(
                context,
                error: error,
                stackTrace: stackTrace,
              ),
              data: (roomMap) {
                if (roomMap == null) {
                  return Center(
                    child: Text(
                      'Room not found',
                      style: GoogleFonts.raleway(color: VelvetNoir.onSurface),
                    ),
                  );
                }

                final room = RoomModel.fromJson(roomMap, widget.roomId);
                _ensureAutoJoined(currentUser: currentUser, sessionState: sessionState);
                return isDesktop
                    ? _buildDesktopLayout(room, currentUser, sessionState)
                    : _buildMobileLayout(room, currentUser, sessionState);
              },
            ),
    );
  }

  Widget _buildSignInRequiredView(BuildContext context) {
    final destination = Uri.base.path +
        (Uri.base.hasQuery ? '?${Uri.base.query}' : '');
    final encodedDestination = Uri.encodeComponent(destination);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 42,
              color: VelvetNoir.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'Sign in required to join this room.',
              textAlign: TextAlign.center,
              style: GoogleFonts.raleway(
                color: VelvetNoir.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                context.go('/auth?__dl=$encodedDestination');
              },
              child: const Text('Sign In'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomLoadError(
    BuildContext context, {
    required Object error,
    StackTrace? stackTrace,
  }) {
    logFirestoreError(
      context: 'live_room_screen_room_doc',
      error: error,
      stackTrace: stackTrace,
    );
    final info = parseFirestoreError(error);
    final message = friendlyFirestoreMessage(
      error,
      fallbackContext: 'this room',
    );
    final signedInUser = FirebaseAuth.instance.currentUser;
    final shouldAskToResync = info.isPermissionOrAuth && signedInUser != null;
    final destination = Uri.base.path +
        (Uri.base.hasQuery ? '?${Uri.base.query}' : '');
    final encodedDestination = Uri.encodeComponent(destination);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              info.isPermissionOrAuth ? Icons.lock_outline : Icons.warning_amber_rounded,
              size: 40,
              color: info.isPermissionOrAuth
                  ? VelvetNoir.primary
                  : VelvetNoir.secondary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.raleway(
                color: VelvetNoir.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(
                  onPressed: () {
                    if (shouldAskToResync) {
                      ref.invalidate(roomDocLiveProvider(widget.roomId));
                      return;
                    }
                    if (info.isPermissionOrAuth) {
                      context.go('/auth?__dl=$encodedDestination');
                      return;
                    }
                    ref.invalidate(roomDocLiveProvider(widget.roomId));
                  },
                  child: Text(
                    shouldAskToResync
                        ? 'Retry Sync'
                        : info.isPermissionOrAuth
                            ? 'Sign In Again'
                            : 'Retry',
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(RoomModel room, User? currentUser, RoomSessionState sessionState) {
    final currentUserId = currentUser?.uid ?? '';
    final isHostLike = currentUserId.isNotEmpty &&
        (room.hostId == currentUserId ||
            room.ownerId == currentUserId ||
            room.adminUserIds.contains(currentUserId));

    return Column(
      children: [
        // Video Grid Area
        if (sessionState.hasJoined)
          _buildVideoArea(sessionState)
        else
          _buildRoomPreview(room),
        
        // Room Info & Controls
        Expanded(
          child: Column(
            children: [
              _buildRoomHeader(room, ref),
              _buildMobileQuickActions(
                room: room,
                currentUser: currentUser,
                sessionState: sessionState,
                currentUserId: currentUserId,
                isHostLike: isHostLike,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _buildChatArea(sessionState),
              ),
              _buildControlBar(room, currentUser, sessionState),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(RoomModel room, User? currentUser, RoomSessionState sessionState) {
    final currentUserId = currentUser?.uid ?? '';
    final isHostLike = currentUserId.isNotEmpty &&
        (room.hostId == currentUserId || room.ownerId == currentUserId || room.adminUserIds.contains(currentUserId));

    return Row(
      children: [
        // Left: Video Grid
        Expanded(
          flex: 3,
          child: Column(
            children: [
              if (sessionState.hasJoined)
                Expanded(child: _buildVideoArea(sessionState))
              else
                Expanded(child: _buildRoomPreview(room)),
              _buildControlBar(room, currentUser, sessionState),
            ],
          ),
        ),
        VerticalDivider(color: VelvetNoir.surfaceHigh, width: 1),
        // Middle: Chat
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildRoomHeader(room, ref),
              Expanded(child: _buildChatArea(sessionState)),
            ],
          ),
        ),
        VerticalDivider(color: VelvetNoir.surfaceHigh, width: 1),
        // Right: Queue + Roster sidebar
        SizedBox(
          width: 310,
          child: Column(
            children: [
              Consumer(
                builder: (context, sideRef, _) {
                  final participantsAsync = sideRef.watch(roomParticipantsLiveProvider(widget.roomId));

                  final participants = participantsAsync.valueOrNull ?? const [];
                  final displayNameById = {
                    for (final p in participants)
                      p.userId: ((p.displayName?.trim().isNotEmpty ?? false) ? p.displayName!.trim() : p.userId),
                  };
                  final rankTierById = {
                    for (final p in participants) p.userId: p.rankTier,
                  };
                  final diamondById = {
                    for (final p in participants) p.userId: p.diamondLevel,
                  };

                  return MicQueuePanel(
                    roomId: widget.roomId,
                    currentUserId: currentUserId,
                    isHost: isHostLike,
                    displayNameById: displayNameById,
                    rankTierById: rankTierById,
                    diamondLevelById: diamondById,
                    onJoinQueue: () {
                      if (currentUserId.isEmpty) return;
                      sideRef.read(roomControllerProvider(widget.roomId).notifier).requestMic(userId: currentUserId);
                    },
                    onLeaveQueue: () {
                      if (currentUserId.isEmpty) return;
                      final myRequest = sideRef
                          .read(
                            myMicAccessRequestProvider((
                              roomId: widget.roomId,
                              requesterId: currentUserId,
                            )),
                          )
                          .valueOrNull;
                      if (myRequest == null) return;
                      sideRef.read(roomControllerProvider(widget.roomId).notifier).cancelMicRequest(myRequest.id);
                    },
                    onWithdraw: (request) {
                      sideRef.read(roomControllerProvider(widget.roomId).notifier).cancelMicRequest(request.id);
                    },
                    onApprove: (request) {
                      sideRef.read(roomControllerProvider(widget.roomId).notifier).approveMicRequest(request);
                    },
                    onDeny: (request) {
                      sideRef.read(roomControllerProvider(widget.roomId).notifier).denyMicRequest(request.id);
                    },
                    onPromote: (request) {
                      sideRef.read(roomControllerProvider(widget.roomId).notifier).promoteMicQueueRequest(request.id);
                    },
                    onDemote: (request) {
                      sideRef.read(roomControllerProvider(widget.roomId).notifier).demoteMicQueueRequest(request.id);
                    },
                    onDismiss: (request) {
                      sideRef.read(roomControllerProvider(widget.roomId).notifier).dismissMicQueueRequest(request.id);
                    },
                  );
                },
              ),
              Expanded(
                child: Consumer(
                  builder: (context, sideRef, _) {
                    final participants = sideRef.watch(roomParticipantsLiveProvider(widget.roomId)).valueOrNull ?? const [];
                    final presence = sideRef.watch(roomPresenceLiveProvider(widget.roomId)).valueOrNull ?? const [];
                    final queue = sideRef.watch(roomMicAccessRequestsProvider(widget.roomId)).valueOrNull ?? const [];

                    final rosterParticipants = _projectParticipantsForRoster(
                      participants: participants,
                      sessionState: sessionState,
                      currentUser: currentUser,
                      room: room,
                    );

                    final pendingQueueUserIds = queue
                        .where((q) => q.status == 'pending' && !q.isExpired)
                        .map((q) => q.requesterId)
                        .toSet();

                    final displayNameById = {
                      for (final p in rosterParticipants)
                        p.userId: ((p.displayName?.trim().isNotEmpty ?? false) ? p.displayName!.trim() : p.userId),
                    };
                    final avatarById = {
                      for (final p in rosterParticipants) p.userId: p.photoUrl,
                    };
                    final currentUserLabel = currentUser == null
                        ? currentUserId
                        : _displayNameFromAuthUser(currentUser);

                    return UserListPanel(
                      participants: rosterParticipants,
                      currentUserId: currentUserId,
                      presenceList: presence,
                      displayNameById: displayNameById,
                      avatarUrlById: avatarById,
                      micQueueUserIds: pendingQueueUserIds,
                      onTapUser: (participant) => _handleRosterUserTap(
                        participant: participant,
                        currentUserId: currentUserId,
                        currentUserLabel: currentUserLabel,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoArea(RoomSessionState sessionState) {
    return Consumer(
      builder: (context, ref, _) {
        final webrtcState = ref.watch(activeRoomWebRTCProvider(widget.roomId));
        final healthState = ref.watch(connectionHealthProvider);
        final recoveryState = ref.watch(connectionRecoveryProvider);
        final giftsAsync = ref.watch(roomGiftFeedProvider(widget.roomId));
        ref.watch(giftEffectQueueProvider);
        final sessionNotifier = ref.read(roomSessionProvider(widget.roomId).notifier);
        
        // Trigger queued effects for new gifts.
        giftsAsync.whenData((gifts) {
          final mappedEffects = gifts
              .map((gift) => RoomGiftEffectEvent.fromRoomGiftEvent(gift))
              .toList(growable: false);
          _checkForNewGiftEffects(mappedEffects, ref);
        });
        
        // Trigger audio-only fallback if recovery takes >5 seconds
        _handleRecoveryTimeout(
          recoveryState: recoveryState,
          sessionNotifier: sessionNotifier,
          context: context,
          isVideoEnabled: sessionState.isVideoEnabled,
        );
        
        if (webrtcState?.service == null) {
          return Center(
            child: Text(
              'Initializing video...',
              style: GoogleFonts.raleway(
                color: VelvetNoir.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          );
        }

        final service = webrtcState!.service!;
        final remoteUids = service.remoteUids;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final rainTargetUserId = _activeRainUserId;

        final gridEntries = <({
          String key,
          String label,
          String? userId,
          Widget view,
          bool isLocal,
        })>[];
        if (sessionState.isVideoEnabled) {
          gridEntries.add((
            key: 'local',
            label: 'You',
            userId: currentUserId,
            view: service.getLocalView(),
            isLocal: true,
          ));
        }

        for (final uid in remoteUids) {
          final mappedUserId = service.userIdForUid(uid);
          final mappedLabel = mappedUserId != null
              ? (sessionState.userDisplayNames[mappedUserId]?.trim() ?? '')
              : '';
          gridEntries.add((
            key: 'remote_$uid',
            label: mappedLabel.isNotEmpty ? mappedLabel : 'Participant',
            userId: mappedUserId,
            view: service.getRemoteView(uid, widget.roomId),
            isLocal: false,
          ));
        }

        final visibleCount = gridEntries.length > _gridSlotCount
            ? _gridSlotCount
            : gridEntries.length;
        final visibleEntries = gridEntries.take(visibleCount).toList(growable: false);

        if (visibleEntries.isEmpty) {
          return Center(
            child: Text(
              'No active camera feeds yet',
              style: GoogleFonts.raleway(
                color: VelvetNoir.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        return Stack(
          children: [
            Container(
              color: VelvetNoir.surfaceHigh,
              padding: const EdgeInsets.fromLTRB(10, 56, 10, 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width >= 1300
                      ? (width >= 1700 ? 5 : 4)
                      : width >= 900
                      ? 3
                      : width >= 520
                      ? 2
                      : 1;

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 4 / 3,
                    ),
                    itemCount: visibleEntries.length,
                    itemBuilder: (context, index) {
                      final entry = visibleEntries[index];
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: VelvetNoir.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: entry.isLocal
                                ? VelvetNoir.primary.withValues(alpha: 0.75)
                                : VelvetNoir.secondary.withValues(alpha: 0.55),
                            width: 1.4,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              entry.view,
                              Positioned(
                                left: 8,
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.58),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    entry.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.raleway(
                                      color: VelvetNoir.onSurface,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              if (rainTargetUserId != null &&
                                  rainTargetUserId == entry.userId)
                                const _MoneyRainOnCamOverlay(),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: VelvetNoir.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cams',
                      style: GoogleFonts.raleway(
                        color: VelvetNoir.onSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    for (final count in const [4, 8, 12, 16, 20]) ...[
                      GestureDetector(
                        onTap: () => setState(() => _gridSlotCount = count),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _gridSlotCount == count
                                ? VelvetNoir.primary
                                : VelvetNoir.surfaceHigh,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.raleway(
                              color: _gridSlotCount == count
                                  ? VelvetNoir.surface
                                  : VelvetNoir.onSurface,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Reconnecting Banner (prominent top notification)
            if (recoveryState.isRecovering)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.orange.withValues(alpha: 0.9),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Reconnecting... (Attempt ${recoveryState.attemptNumber}/${recoveryState.maxAttempts})',
                              style: GoogleFonts.raleway(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (recoveryState.nextRetryDelayMs > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Next attempt in ${(recoveryState.nextRetryDelayMs / 1000).toStringAsFixed(1)}s',
                                  style: GoogleFonts.raleway(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Connection Failed Banner
            if (recoveryState.isFailed)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.red.withValues(alpha: 0.9),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Connection failed. Please check your network or try leaving and rejoining.',
                          style: GoogleFonts.raleway(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Audio/Video Status Overlays + Recovery Badge
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      _buildStatusBadge(
                        sessionState.isVideoEnabled ? 'Video ON' : 'Video OFF',
                        sessionState.isVideoEnabled ? VelvetNoir.liveGlow : Colors.grey.shade700,
                      ),
                      _buildStatusBadge(
                        sessionState.isAudioEnabled ? 'Mic ON' : 'Mic OFF',
                        sessionState.isAudioEnabled ? VelvetNoir.liveGlow : Colors.grey.shade700,
                      ),
                      NetworkHealthWidget(
                        showLabel: false,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      ),
                    ],
                  ),
                  
                  // Health Badge: Shows when connection is degrading or worse
                  if (healthState.isAtRisk)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: switch (healthState.health) {
                          ConnectionHealth.healthy => Colors.green.withValues(alpha: 0.8),
                          ConnectionHealth.degrading => Colors.orange.withValues(alpha: 0.8),
                          ConnectionHealth.degraded => Colors.red.withValues(alpha: 0.8),
                          ConnectionHealth.unavailable => Colors.grey.withValues(alpha: 0.8),
                        },
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: VelvetNoir.liveGlow.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: [
                          Icon(
                            switch (healthState.health) {
                              ConnectionHealth.healthy => Icons.cloud_done,
                              ConnectionHealth.degrading => Icons.cloud_queue,
                              ConnectionHealth.degraded => Icons.cloud_off,
                              ConnectionHealth.unavailable => Icons.cloud_off_rounded,
                            },
                            color: Colors.white,
                            size: 14,
                          ),
                          Text(
                            healthState.displayStatus,
                            style: GoogleFonts.raleway(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Recovery Badge: Shows during degraded/reconnecting states
                  if (webrtcState.connectionState == RtcConnectionState.degraded ||
                      webrtcState.connectionState == RtcConnectionState.reconnecting)
                    RecoveryBadge(
                      attemptNumber: webrtcState.reconnectAttemptCount,
                      maxAttempts: 3,
                    ),
                ],
              ),
            ),

            // Connection Failed Overlay: Shows after max retries exhausted
            if (webrtcState.connectionState == RtcConnectionState.failed)
              ConnectionFailedOverlay(
                roomId: widget.roomId,
                onRetry: () {
                  // Attempt to recover by calling reconnect on the service
                  // ignore: use_build_context_synchronously
                  ref.read(activeRoomWebRTCProvider(widget.roomId).notifier)
                      .disconnect()
                      .then((_) {
                    // Service will auto-reinitialize on next join
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Retrying connection...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  });
                },
                onLeave: () => Navigator.of(context).pop(),
              ),
            
            // TEMPORARY TEST BUTTONS - DELETE BEFORE COMMIT
            if (kDebugMode)
              Positioned(
                bottom: 120,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Test WARNING trigger
                    FloatingActionButton.extended(
                      heroTag: 'warning-test',
                      label: const Text('⚠️ Test WARNING'),
                      backgroundColor: Colors.orange,
                      tooltip: 'Trigger a test WARNING alert',
                      onPressed: () {
                        logWarning(
                          'Test Warning Triggered - Verifying alert pipeline',
                          metadata: {
                            'test_type': 'warning',
                            'timestamp': DateTime.now().toIso8601String(),
                            'room_id': widget.roomId,
                          },
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ WARNING logged to Crashlytics (check in 2 min)'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Test ERROR trigger
                    FloatingActionButton.extended(
                      heroTag: 'error-test',
                      label: const Text('🔴 Test ERROR'),
                      backgroundColor: Colors.red,
                      tooltip: 'Trigger a test ERROR alert',
                      onPressed: () {
                        logError(
                          'Test Error Triggered - Verifying alert pipeline',
                          error: Exception('Controlled test failure'),
                          metadata: {
                            'test_type': 'error',
                            'timestamp': DateTime.now().toIso8601String(),
                            'room_id': widget.roomId,
                          },
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ ERROR logged to Crashlytics (check in 2 min)'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Test CRITICAL trigger
                    FloatingActionButton.extended(
                      heroTag: 'critical-test',
                      label: const Text('🚨 Test CRITICAL'),
                      backgroundColor: Colors.redAccent,
                      tooltip: 'Trigger a test CRITICAL alert',
                      onPressed: () {
                        logCritical(
                          'Test Critical Triggered - Verifying EMERGENCY alert pipeline',
                          error: Exception('Controlled critical test failure'),
                          metadata: {
                            'test_type': 'critical',
                            'timestamp': DateTime.now().toIso8601String(),
                            'room_id': widget.roomId,
                          },
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ CRITICAL logged to Crashlytics (check in 2 min)'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            
            // Gift Ticker: Shows recent gifts at bottom
            GiftTickerWidget(
              roomId: widget.roomId,
              bottomPadding: 80,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.raleway(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRoomPreview(RoomModel room) {
    return Container(
      color: VelvetNoir.surfaceHigh,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: VelvetNoir.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.videocam_outlined,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              room.name,
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: VelvetNoir.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              room.description ?? 'A live streaming room',
              style: GoogleFonts.raleway(
                fontSize: 14,
                color: VelvetNoir.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (room.isLive)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: VelvetNoir.liveGlow,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '● LIVE',
                        style: GoogleFonts.raleway(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Text(
                  '${room.memberCount} listeners',
                  style: GoogleFonts.raleway(
                    color: VelvetNoir.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomHeader(RoomModel room, WidgetRef ref) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final sessionState = ref.watch(roomSessionProvider(widget.roomId));
    final participants =
        ref.watch(roomParticipantsLiveProvider(widget.roomId)).valueOrNull ??
        const [];
    final totalDiamonds = participants.fold<int>(
      0,
      (total, participant) => total + participant.diamondLevel,
    );
    final liveBroadcasters = participants
        .where((participant) => participant.camOn || participant.micOn)
        .length;
    final selfResolvedName = currentUser != null
        ? (sessionState.userDisplayNames[currentUser.uid]?.trim() ?? '')
        : '';
    final hostLabel = _resolveHostLabel(
      room,
      currentUser,
      selfResolvedName: selfResolvedName,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        border: Border(bottom: BorderSide(color: VelvetNoir.primary.withValues(alpha: 0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  room.name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: VelvetNoir.onSurface,
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (room.isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: VelvetNoir.liveGlow,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'LIVE',
                        style: GoogleFonts.raleway(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0x2239B6FF),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0x664AC6FF)),
                    ),
                    child: Text(
                      'DIAMONDS $totalDiamonds',
                      style: GoogleFonts.raleway(
                        color: const Color(0xFF4AC6FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              FutureBuilder<String>(
                future: _getUserDisplayName(
                  room.hostId.trim().isNotEmpty ? room.hostId : room.ownerId,
                ),
                builder: (context, snapshot) {
                  final resolved = (snapshot.data ?? '').trim();
                  final effectiveHostLabel = resolved.isNotEmpty
                      ? resolved
                      : hostLabel;
                  return Text(
                    'Hosted by $effectiveHostLabel',
                    style: GoogleFonts.raleway(
                      fontSize: 12,
                      color: VelvetNoir.onSurfaceVariant,
                    ),
                  );
                },
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x22781E2B),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0x66781E2B)),
                ),
                child: Text(
                  '$liveBroadcasters broadcasting',
                  style: GoogleFonts.raleway(
                    color: const Color(0xFFD9B8BE),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Consumer(
                builder: (context, consumerRef, _) {
                  final participantCount = consumerRef.watch(participantCountProvider(room.id));
                  return GestureDetector(
                    onTap: () => _showParticipantsPanel(room.id),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Row(
                        children: [
                          const Icon(Icons.people, size: 14, color: VelvetNoir.primary),
                          const SizedBox(width: 4),
                          Text(
                            '$participantCount listeners',
                            style: GoogleFonts.raleway(
                              fontSize: 12,
                              color: VelvetNoir.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (currentUser != null)
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: ref
                      .watch(firestoreProvider)
                      .collection('rooms')
                      .doc(room.id)
                      .collection('followers')
                      .doc(currentUser.uid)
                      .snapshots(),
                  builder: (context, followSnapshot) {
                    final isFollowing = followSnapshot.data?.exists ?? false;
                    return FilledButton.tonalIcon(
                      onPressed: _isFollowActionBusy
                          ? null
                          : () => _toggleFollowRoom(
                                roomId: room.id,
                                userId: currentUser.uid,
                                isFollowing: isFollowing,
                              ),
                      icon: Icon(
                        isFollowing ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                      ),
                      label: Text(isFollowing ? 'Following' : 'Follow Room'),
                      style: FilledButton.styleFrom(
                        foregroundColor: VelvetNoir.primary,
                        backgroundColor: VelvetNoir.surface,
                        textStyle: GoogleFonts.raleway(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    );
                  },
                ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ref
                      .watch(firestoreProvider)
                      .collection('rooms')
                      .doc(room.id)
                      .collection('followers')
                      .limit(2000)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final followerCount = snapshot.data?.docs.length ?? 0;
                    return Text(
                      '$followerCount followers',
                      style: GoogleFonts.raleway(
                        fontSize: 11,
                        color: VelvetNoir.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _RoomAnnouncementMarquee(
            text: _roomAnnouncement(room),
            textStyle: GoogleFonts.raleway(
              color: VelvetNoir.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea(RoomSessionState sessionState) {
    if (!sessionState.hasJoined) {
      return Center(
        child: Text(
          'Join the room to chat',
          style: GoogleFonts.raleway(
            fontSize: 14,
            color: VelvetNoir.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final firestore = ref.watch(firestoreProvider);
    final participants =
        ref.watch(roomParticipantsLiveProvider(widget.roomId)).valueOrNull ??
        const [];
    final rankTierById = {
      for (final participant in participants) participant.userId: participant.rankTier,
    };
    final diamondLevelById = {
      for (final participant in participants) participant.userId: participant.diamondLevel,
    };
    final badgeTitleById = {
      for (final participant in participants)
        if ((participant.badgeTitle ?? '').trim().isNotEmpty)
          participant.userId: participant.badgeTitle!.trim(),
    };

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('rooms')
                .doc(widget.roomId)
                .collection('messages')
                .orderBy('createdAt', descending: false)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: Text(
                    'Loading messages...',
                    style: GoogleFonts.raleway(color: VelvetNoir.onSurfaceVariant),
                  ),
                );
              }

              final messages = snapshot.data!.docs;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!scrollController.hasClients) return;
                final pos = scrollController.position;
                // Guard: position must be attached and laid out before animating.
                if (!pos.hasContentDimensions || !pos.hasPixels) return;
                pos.animateTo(
                  pos.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              });

              return ListView.builder(
                controller: scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final data = msg.data() as Map<String, dynamic>;
                  final rawSender = data['senderName'] as String? ?? '';
                  final senderId = data['senderId'] as String? ?? '';
                  final rawContent = data['content'] as String? ?? '';
                  // Truncate runaway-long content (e.g. accidentally pasted
                  // stack traces) so they never cause layout overflow.
                  final content = rawContent.length > 500
                      ? '${rawContent.substring(0, 500)}…'
                      : rawContent;

                  // Resolve display name synchronously from caches already held
                  // by the session state and the resolved-name cache. Avoids a
                  // FutureBuilder per item (which fires a new Firestore read on
                  // every stream update and causes cascading build exceptions).
                  final cachedSession =
                      sessionState.userDisplayNames[senderId]?.trim() ?? '';
                  final cachedResolved =
                      _resolvedUserNameCache[senderId]?.trim() ?? '';
                  final syncName = rawSender.trim().isNotEmpty &&
                          !_isPlaceholderIdentity(rawSender)
                      ? rawSender.trim()
                      : cachedSession.isNotEmpty &&
                          !_isPlaceholderIdentity(cachedSession)
                      ? cachedSession
                      : cachedResolved.isNotEmpty &&
                          !_isPlaceholderIdentity(cachedResolved)
                      ? cachedResolved
                      : senderId.trim().isNotEmpty
                      ? _memberFallback(senderId)
                      : 'MixVy Member';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: VelvetNoir.primary,
                          child: Text(
                            roomAvatarInitials(syncName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 5,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    syncName,
                                    style: GoogleFonts.raleway(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: VelvetNoir.primary,
                                    ),
                                  ),
                                  RoomRankDiamondBadgeRow(
                                    rankTier: rankTierById[senderId] ?? 0,
                                    diamondLevel: diamondLevelById[senderId] ?? 0,
                                    compact: true,
                                  ),
                                  if (badgeTitleById.containsKey(senderId))
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0x33781E2B),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: const Color(0x55781E2B)),
                                      ),
                                      child: Text(
                                        badgeTitleById[senderId]!,
                                        style: GoogleFonts.raleway(
                                          fontSize: 9,
                                          color: VelvetNoir.onSurface,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                content,
                                style: GoogleFonts.raleway(
                                  fontSize: 12,
                                  color: VelvetNoir.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (sessionState.hasJoined)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: GoogleFonts.raleway(
                        color: VelvetNoir.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: VelvetNoir.surfaceHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: GoogleFonts.raleway(color: VelvetNoir.onSurface),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: VelvetNoir.primary,
                  onPressed: () => _sendMessage(messageController.text),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildControlBar(RoomModel room, User? currentUser, RoomSessionState sessionState) {
    final roomState = ref.watch(roomControllerProvider(widget.roomId));
    final currentUserId = currentUser?.uid ?? '';
    final hasCurrentUser = currentUserId.isNotEmpty;
    final isHostLike =
        hasCurrentUser && roomState.canManageStage(currentUserId);
    final isOnMic =
        hasCurrentUser && roomState.isOnMicByAuthority(currentUserId);
    final maxBroadcasters = room.maxBroadcasters.clamp(1, 4);
    final isMicFree = roomState.speakerIds.length < maxBroadcasters;
    final myMicRequest = hasCurrentUser
        ? ref
              .watch(
                myMicAccessRequestProvider((
                  roomId: widget.roomId,
                  requesterId: currentUserId,
                )),
              )
              .valueOrNull
        : null;
    final hasPendingMicRequest = myMicRequest?.isPending == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        border: Border(top: BorderSide(color: VelvetNoir.primary.withValues(alpha: 0.2))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (!sessionState.hasJoined)
              FilledButton.icon(
                onPressed: (currentUser != null && !_isJoiningRoom)
                    ? () => _joinCurrentUserToRoom(currentUser)
                    : null,
                icon: const Icon(Icons.call_outlined),
                label: Text(_isJoiningRoom ? 'ENTERING…' : 'RETRY ENTRY'),
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetNoir.primary,
                ),
              )
            else ...[
              FilledButton.icon(
                onPressed: () => _toggleVideo(!sessionState.isVideoEnabled),
                icon: Icon(sessionState.isVideoEnabled ? Icons.videocam : Icons.videocam_off),
                label: Text(sessionState.isVideoEnabled ? 'Camera' : 'Camera Off'),
                style: FilledButton.styleFrom(
                  backgroundColor: sessionState.isVideoEnabled ? VelvetNoir.primary : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _toggleAudio(!sessionState.isAudioEnabled),
                icon: Icon(sessionState.isAudioEnabled ? Icons.mic : Icons.mic_off),
                label: Text(sessionState.isAudioEnabled ? 'Mic' : 'Mic Off'),
                style: FilledButton.styleFrom(
                  backgroundColor: sessionState.isAudioEnabled ? VelvetNoir.primary : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _toggleAudioSharing(!sessionState.isAudioSharingEnabled),
                icon: Icon(sessionState.isAudioSharingEnabled ? Icons.volume_up : Icons.volume_mute),
                label: Text(sessionState.isAudioSharingEnabled ? 'Share Audio' : 'No Audio Share'),
                style: FilledButton.styleFrom(
                  backgroundColor: sessionState.isAudioSharingEnabled ? VelvetNoir.secondary : Colors.grey.shade700,
                ),
              ),
              if (!isHostLike && hasCurrentUser) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      final controller = ref.read(
                        roomControllerProvider(widget.roomId).notifier,
                      );

                      if (isOnMic) {
                        await controller.releaseMic(userId: currentUserId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mic released.')),
                          );
                        }
                        return;
                      }

                      if (hasPendingMicRequest &&
                          myMicRequest != null &&
                          myMicRequest.id.trim().isNotEmpty) {
                        await controller.cancelMicRequest(myMicRequest.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Hand lowered.')),
                          );
                        }
                        return;
                      }

                      final result = await controller.requestMic(
                        userId: currentUserId,
                      );
                      if (!mounted) return;
                      final message = result == MicRequestResult.grabbed
                          ? 'You are now on mic.'
                          : 'Hand raised. Waiting for host approval.';
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(message)));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Mic action failed: $e')),
                      );
                    }
                  },
                  icon: Icon(
                    isOnMic
                        ? Icons.mic_off_rounded
                        : hasPendingMicRequest
                    ? Icons.exit_to_app_rounded
                        : isMicFree
                    ? Icons.record_voice_over_rounded
                        : Icons.queue_rounded,
                  ),
                  label: Text(
                    isOnMic
                        ? 'Release Mic'
                        : hasPendingMicRequest
                    ? 'Leave Queue'
                        : isMicFree
                    ? 'Join Queue to Talk'
                    : 'Join Queue to Talk',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isOnMic
                        ? Colors.grey.shade700
                        : hasPendingMicRequest
                        ? const Color(0xFFD4A853)
                        : isMicFree
                        ? VelvetNoir.liveGlow
                        : const Color(0xFFD4A853),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => RoomGiftPickerSheet.show(context, ref, roomId: room.id),
                icon: const Icon(Icons.card_giftcard),
                label: const Text('Gift'),
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetNoir.primary,
                  foregroundColor: VelvetNoir.surface,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: currentUser != null ? _leaveRoom : null,
                icon: const Icon(Icons.logout),
                label: const Text('LEAVE'),
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetNoir.secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoneyRainOnCamOverlay extends StatefulWidget {
  const _MoneyRainOnCamOverlay();

  @override
  State<_MoneyRainOnCamOverlay> createState() => _MoneyRainOnCamOverlayState();
}

class _MoneyRainOnCamOverlayState extends State<_MoneyRainOnCamOverlay>
    with SingleTickerProviderStateMixin {
  static const List<String> _symbols = ['💸', '💵', '🪙'];
  static const List<double> _xFractions = [
    0.05,
    0.14,
    0.22,
    0.31,
    0.40,
    0.49,
    0.58,
    0.67,
    0.76,
    0.85,
    0.10,
    0.28,
    0.54,
    0.80,
  ];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withValues(alpha: 0.08),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final progress = _controller.value;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    for (var i = 0; i < _xFractions.length; i++)
                      Builder(
                        builder: (context) {
                          final laneOffset = (i % 6) * 0.11;
                          final t = (progress + laneOffset) % 1.0;
                          final y = -20 + (constraints.maxHeight + 40) * t;
                          final x =
                              _xFractions[i] * (constraints.maxWidth - 24);
                          final symbol = _symbols[i % _symbols.length];
                          final opacity = (1.0 - t * 0.45).clamp(0.25, 1.0);

                          return Positioned(
                            left: x,
                            top: y,
                            child: Opacity(
                              opacity: opacity,
                              child: Text(
                                symbol,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}






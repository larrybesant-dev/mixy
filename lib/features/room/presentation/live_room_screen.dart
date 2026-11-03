import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../../../models/room_model.dart';
import '../../../models/room_participant_model.dart';
import '../../../models/mic_access_request_model.dart';
import '../../../core/theme.dart';
import '../../../services/diagnostic_logger.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../services/connection_recovery_handler.dart';
import '../../../services/connection_health_check.dart';
import '../../../core/flags/feature_flags.dart';
import 'room_management_modal.dart';
import '../room_controller.dart';
import '../room_permissions.dart';
import '../providers/room_webrtc_provider.dart';
import '../providers/room_session_provider.dart';
import '../providers/participant_providers.dart';
import '../providers/mic_access_provider.dart';
import '../providers/cam_view_request_provider.dart';
import '../providers/presence_provider.dart';
import '../providers/connection_recovery_provider.dart';
import '../providers/room_gift_provider.dart';
import '../repository/room_repository.dart';
import '../widgets/network_health_widget.dart';
import '../widgets/recovery_badge.dart';
import '../widgets/connection_failed_overlay.dart';
import '../widgets/cam_view_request_dialog.dart';
import '../widgets/mic_queue_panel.dart';
import '../widgets/user_list_panel.dart';
import '../widgets/room_text_utils.dart';
import '../widgets/room_rank_diamond_badge_row.dart';
import '../widgets/room_share_sheet.dart';
import '../../friends/providers/friends_providers.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../widgets/floating_gift_animation.dart';
import '../../../widgets/gift_ticker_widget.dart';
import '../../../widgets/room_gift_picker_sheet.dart';
import '../../../widgets/gift_picker_sheet.dart';

const int liveRoomDefaultGridSlotCount = 4;
const double liveRoomDesktopChatWidth = 280;
const double liveRoomDesktopRosterWidth = 184;

class RoomStageBackground extends StatelessWidget {
  const RoomStageBackground({
    super.key,
    required this.imageUrl,
    required this.child,
  });

  final String? imageUrl;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final backgroundUrl = imageUrl?.trim() ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (backgroundUrl.isNotEmpty)
          Image.network(
            backgroundUrl,
            key: const ValueKey('room-stage-background-image'),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) => const ColoredBox(
              key: ValueKey('room-stage-background-fallback'),
              color: VelvetNoir.surfaceHigh,
            ),
          )
        else
          const ColoredBox(
            key: ValueKey('room-stage-background-fallback'),
            color: VelvetNoir.surfaceHigh,
          ),
        if (backgroundUrl.isNotEmpty)
          const DecoratedBox(
            key: ValueKey('room-stage-background-overlay'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x66000000),
                  Color(0xA6000000),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        child,
      ],
    );
  }
}

class _RoomChatEntry {
  const _RoomChatEntry({
    required this.data,
    required this.isWhisper,
  });

  final Map<String, dynamic> data;
  final bool isWhisper;

  DateTime get sentAt {
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();
    final clientSentAt = data['clientSentAt'];
    if (clientSentAt is Timestamp) return clientSentAt.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

Stream<List<_RoomChatEntry>> _watchRoomChatEntries({
  required FirebaseFirestore firestore,
  required String roomId,
  required String userId,
}) {
  late StreamController<List<_RoomChatEntry>> controller;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? publicSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? whisperSubscription;
  var publicEntries = const <_RoomChatEntry>[];
  var whisperEntries = const <_RoomChatEntry>[];

  void emit() {
    if (controller.isClosed) return;
    final combined = [...publicEntries, ...whisperEntries]
      ..sort((left, right) => left.sentAt.compareTo(right.sentAt));
    controller.add(combined);
  }

  controller = StreamController<List<_RoomChatEntry>>(
    onListen: () {
      publicSubscription = firestore
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .limit(100)
          .snapshots()
          .listen(
        (snapshot) {
          publicEntries = snapshot.docs
              .map(
                (doc) => _RoomChatEntry(
                  data: doc.data(),
                  isWhisper: false,
                ),
              )
              .toList(growable: false);
          emit();
        },
        onError: controller.addError,
      );
      whisperSubscription = firestore
          .collection('rooms')
          .doc(roomId)
          .collection('whispers')
          .where('participantIds', arrayContains: userId)
          .limit(100)
          .snapshots()
          .listen(
        (snapshot) {
          whisperEntries = snapshot.docs
              .map(
                (doc) => _RoomChatEntry(
                  data: doc.data(),
                  isWhisper: true,
                ),
              )
              .toList(growable: false);
          emit();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await publicSubscription?.cancel();
      await whisperSubscription?.cancel();
      await controller.close();
    },
  );

  return controller.stream;
}

final RegExp _generatedLiveRoomHandlePattern = RegExp(
  r'^(User|Guest|Member)\s+[A-Z0-9]{1,6}$',
);

String liveRoomMemberFallback(String userId) {
  final compact = userId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  if (compact.isEmpty) return 'MixVy Member';
  final suffix = compact.substring(0, compact.length < 4 ? compact.length : 4);
  return 'Member $suffix';
}

@visibleForTesting
String resolveLiveRoomDisplayName({
  required String userId,
  String? liveProfileName,
  String? sessionName,
  String? participantName,
}) {
  for (final candidate in [
    liveProfileName,
    sessionName,
    participantName,
  ]) {
    final normalized = candidate?.trim() ?? '';
    if (normalized.isNotEmpty &&
        normalized != 'Anonymous' &&
        normalized != 'MixVy Member' &&
        !_generatedLiveRoomHandlePattern.hasMatch(normalized)) {
      return normalized;
    }
  }
  return liveRoomMemberFallback(userId);
}

@visibleForTesting
List<RoomParticipantModel> mergeLiveRoomRemoteCameraParticipants({
  required List<RoomParticipantModel> participants,
  required Set<String> remoteCameraUserIds,
  required Map<String, String> sessionDisplayNames,
  required DateTime now,
}) {
  final merged = participants
      .map(
        (participant) => remoteCameraUserIds.contains(participant.userId)
            ? participant.copyWith(camOn: true)
            : participant,
      )
      .toList();
  final existingUserIds =
      merged.map((participant) => participant.userId).toSet();

  for (final userId in remoteCameraUserIds) {
    if (existingUserIds.contains(userId)) continue;
    final sessionName = sessionDisplayNames[userId]?.trim() ?? '';
    merged.add(
      RoomParticipantModel(
        userId: userId,
        role: 'audience',
        displayName: sessionName.isNotEmpty
            ? sessionName
            : liveRoomMemberFallback(userId),
        camOn: true,
        micOn: false,
        joinedAt: now,
        lastActiveAt: now,
      ),
    );
  }
  return merged;
}

int liveRoomGridColumnCount(int slotCount, double availableWidth) {
  final preferredColumns = switch (slotCount) {
    <= 4 => 2,
    <= 16 => 4,
    _ => 5,
  };
  if (availableWidth < 360) return preferredColumns.clamp(1, 2);
  if (availableWidth < 520) return preferredColumns.clamp(1, 3);
  return preferredColumns;
}

int liveRoomAutomaticGridSlotCount(int cameraCount) {
  if (cameraCount <= 4) return 4;
  if (cameraCount <= 8) return 8;
  if (cameraCount <= 12) return 12;
  if (cameraCount <= 16) return 16;
  return 20;
}

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
  State<_RoomAnnouncementMarquee> createState() =>
      _RoomAnnouncementMarqueeState();
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
  int? _manualGridSlotCount;
  String? _expandedVideoKey;
  bool _isFollowActionBusy = false;
  bool _isJoiningRoom = false;
  bool _toggleVideoInFlight = false;
  bool _isMicActionBusy = false;
  bool _isSendingChatMessage = false;
  String? _whisperTargetUserId;
  String? _whisperTargetName;
  Stream<List<_RoomChatEntry>>? _chatEntriesStream;
  String? _chatEntriesStreamUserId;
  double _micOutputVolume = 1.0;
  double _sharedAudioOutputVolume = 1.0;
  bool _isRoomSoundMuted = false;
  bool _hasAttemptedAutoJoin = false;
  bool _camViewRequestDialogOpen = false;
  final Set<String> _handledCamViewRequestIds = <String>{};
  final Map<String, String> _resolvedUserNameCache = <String, String>{};

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
    final projectedMicOn =
        sessionState.hasJoined && sessionState.isAudioEnabled;
    final projectedCamOn =
        sessionState.hasJoined && sessionState.isVideoEnabled;
    final profileName = (ref.read(userProvider)?.username ?? '').trim();
    final cachedSessionName =
        (sessionState.userDisplayNames[currentUserId] ?? '').trim();
    final cachedResolvedName =
        _resolvedUserNameCache[currentUserId]?.trim() ?? '';

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
      if (cachedResolvedName.isNotEmpty &&
          !_isPlaceholderIdentity(cachedResolvedName)) {
        return cachedResolvedName;
      }
      return _memberFallback(currentUserId);
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
    // Note: sessionState will be automatically cleaned up when room is left
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LiveRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _handledCamViewRequestIds.clear();
      _chatEntriesStream = null;
      _chatEntriesStreamUserId = null;
      _camViewRequestDialogOpen = false;
    }
  }

  void _queueCamViewRequests(List<CamViewRequest> requests) {
    if (!mounted || _camViewRequestDialogOpen) return;
    CamViewRequest? nextRequest;
    for (final request in requests) {
      if (!_handledCamViewRequestIds.contains(request.id)) {
        nextRequest = request;
        break;
      }
    }
    if (nextRequest == null) return;

    _camViewRequestDialogOpen = true;
    _handledCamViewRequestIds.add(nextRequest.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_showCamViewRequest(nextRequest!));
    });
  }

  Future<void> _showCamViewRequest(CamViewRequest request) async {
    final approved = await showCamViewRequestDialog(
      context,
      request: request,
    );
    if (!mounted || approved == null) {
      _camViewRequestDialogOpen = false;
      return;
    }

    try {
      await ref.read(camViewRequestControllerProvider).respondToRequest(
            roomId: widget.roomId,
            requestId: request.id,
            approved: approved,
          );
      if (!mounted) return;
      final requesterName = (request.requesterName ?? '').trim();
      final displayName = requesterName.isEmpty ? 'Room member' : requesterName;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? '$displayName can now view your camera.'
                : 'Camera access declined for $displayName.',
          ),
        ),
      );
    } catch (_) {
      _handledCamViewRequestIds.remove(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not respond to the camera request.'),
        ),
      );
    } finally {
      _camViewRequestDialogOpen = false;
      if (mounted) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId != null) {
          final pending = ref
                  .read(
                    pendingCamViewRequestsProvider((
                      roomId: widget.roomId,
                      targetId: currentUserId,
                    )),
                  )
                  .valueOrNull ??
              const <CamViewRequest>[];
          _queueCamViewRequests(pending);
        }
      }
    }
  }

  /// Fetch the user's public username from Firestore profile.
  Future<String> _getUserDisplayName(String uid) async {
    try {
      final firestore = ref.read(firestoreProvider);
      final userDoc = await firestore.collection('users').doc(uid).get();
      final data = userDoc.data();
      final username = (data?['username'] as String?)?.trim() ?? '';

      if (username.isNotEmpty && !_isPlaceholderIdentity(username)) {
        return username;
      }

      return _memberFallback(uid);
    } catch (e) {
      return _memberFallback(uid);
    }
  }

  bool _isPlaceholderIdentity(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return true;
    if (normalized == 'Anonymous' || normalized == 'MixVy Member') return true;
    return _generatedLiveRoomHandlePattern.hasMatch(normalized);
  }

  String _memberFallback(String uid) {
    return liveRoomMemberFallback(uid);
  }

  String _displayNameFromAuthUser(User user) {
    return _memberFallback(user.uid);
  }

  Future<void> _joinCurrentUserToRoom(User currentUser) async {
    if (_isJoiningRoom) return;
    setState(() => _isJoiningRoom = true);
    try {
      final displayName = await _getUserDisplayName(currentUser.uid);
      if (!mounted) return;

      final controller =
          ref.read(roomControllerProvider(widget.roomId).notifier);
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
        final sessionNotifier =
            ref.read(roomSessionProvider(widget.roomId).notifier);
        sessionNotifier.updateDisplayName(currentUser.uid, resolvedName);
        sessionNotifier.setJoined(true);
        await ref
            .read(activeRoomWebRTCProvider(widget.roomId).notifier)
            .joinAsAudience();
        ref.read(activeRoomIdProvider.notifier).state = widget.roomId;
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
    if (_hasAttemptedAutoJoin ||
        sessionState.hasJoined ||
        currentUser == null) {
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
      final hostName = room.hostUsername?.trim() ?? '';
      if (hostName.isNotEmpty && !_isPlaceholderIdentity(hostName)) {
        return hostName;
      }
      return _memberFallback(currentUser.uid);
    }

    final hostName = room.hostUsername?.trim() ?? '';
    if (hostName.isNotEmpty && !_isPlaceholderIdentity(hostName)) {
      return hostName;
    }

    final hostId = room.hostId.trim().isNotEmpty ? room.hostId : room.ownerId;
    return hostId.trim().isNotEmpty ? _memberFallback(hostId) : 'MixVy Member';
  }

  Future<String> _resolveMessageSenderName({
    required String rawSenderName,
    required String senderId,
    required RoomSessionState sessionState,
  }) async {
    final raw = rawSenderName.trim();
    if (raw.isNotEmpty && !_isPlaceholderIdentity(raw)) {
      return raw;
    }

    final cachedSession = sessionState.userDisplayNames[senderId]?.trim() ?? '';
    if (cachedSession.isNotEmpty && !_isPlaceholderIdentity(cachedSession)) {
      return cachedSession;
    }

    final cachedResolved = _resolvedUserNameCache[senderId]?.trim() ?? '';
    if (cachedResolved.isNotEmpty && !_isPlaceholderIdentity(cachedResolved)) {
      return cachedResolved;
    }

    if (senderId.trim().isNotEmpty) {
      final resolved = await _getUserDisplayName(senderId);
      final normalized = resolved.trim();
      if (normalized.isNotEmpty) {
        _resolvedUserNameCache[senderId] = normalized;
        return normalized;
      }
      return _memberFallback(senderId);
    }

    return 'MixVy Member';
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
        final audienceIds =
            List<String>.from(roomData['audienceUserIds'] ?? []);
        final avatarUrls =
            List<String>.from(roomData['audienceUserAvatarUrls'] ?? []);

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
    } catch (e) {
      debugPrint('Error leaving room: $e');
    } finally {
      await ref
          .read(activeRoomWebRTCProvider(widget.roomId).notifier)
          .disconnect();
      ref.read(roomSessionProvider(widget.roomId).notifier).reset();
      if (ref.read(activeRoomIdProvider) == widget.roomId) {
        ref.read(activeRoomIdProvider.notifier).state = null;
      }
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

  /// Requests the given runtime permission on native platforms (web handles
  /// camera/mic access via the browser's own getUserMedia prompt). Agora's
  /// native SDK does not request Android/iOS runtime permissions itself, so
  /// without this the camera/mic can silently fail to start while leaving no
  /// catchable error for the caller to react to.
  Future<bool> _ensurePermission(
    ph.Permission permission,
    String label,
  ) async {
    if (kIsWeb) return true;
    var status = await permission.status;
    if (status.isGranted) return true;
    status = await permission.request();
    if (status.isGranted) return true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.isPermanentlyDenied
                ? '$label permission is blocked. Enable it in system settings to continue.'
                : '$label permission is required to continue.',
          ),
          action: status.isPermanentlyDenied
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: ph.openAppSettings,
                )
              : null,
        ),
      );
    }
    return false;
  }

  Future<void> _toggleVideo(bool enabled) async {
    if (enabled && !await _ensurePermission(ph.Permission.camera, 'Camera')) {
      return;
    }
    final sessionNotifier =
        ref.read(roomSessionProvider(widget.roomId).notifier);
    final previous =
        ref.read(roomSessionProvider(widget.roomId)).isVideoEnabled;
    sessionNotifier.setVideoEnabled(enabled);

    // Suppress the "camera stopped unexpectedly" reconciliation listener
    // while we're deliberately turning the camera off/on here, since that
    // listener only exists to catch the camera stopping on its own.
    _toggleVideoInFlight = true;
    try {
      await ref
          .read(activeRoomWebRTCProvider(widget.roomId).notifier)
          .toggleVideo(enabled);
      await _syncParticipantMediaFlags(camOn: enabled);
    } catch (e) {
      sessionNotifier.setVideoEnabled(previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera toggle failed: $e')),
        );
      }
    } finally {
      _toggleVideoInFlight = false;
    }
  }

  Future<void> _switchCamera() async {
    try {
      await ref
          .read(activeRoomWebRTCProvider(widget.roomId).notifier)
          .switchCamera();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera switch failed: $error')),
        );
      }
    }
  }

  Future<void> _toggleAudio(
    bool enabled, {
    bool micClaimConfirmed = false,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (enabled &&
        !micClaimConfirmed &&
        !RoomPermissions.canBroadcastAudio(
          userId: currentUserId,
          speakerIds:
              ref.read(roomControllerProvider(widget.roomId)).speakerIds,
        )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Only the mic holder and invited speakers can turn on audio.',
            ),
          ),
        );
      }
      return;
    }
    if (enabled &&
        !await _ensurePermission(ph.Permission.microphone, 'Microphone')) {
      return;
    }
    final sessionNotifier =
        ref.read(roomSessionProvider(widget.roomId).notifier);
    final previous =
        ref.read(roomSessionProvider(widget.roomId)).isAudioEnabled;

    if (!enabled &&
        ref.read(roomSessionProvider(widget.roomId)).isAudioSharingEnabled) {
      await _toggleAudioSharing(false);
      if (ref.read(roomSessionProvider(widget.roomId)).isAudioSharingEnabled) {
        return;
      }
    }

    sessionNotifier.setAudioEnabled(enabled);

    try {
      await ref
          .read(activeRoomWebRTCProvider(widget.roomId).notifier)
          .toggleAudio(
            enabled,
            micClaimConfirmed: micClaimConfirmed,
          );
      await _syncParticipantMediaFlags(micOn: enabled);
      if (!enabled) {
        try {
          await ref
              .read(roomControllerProvider(widget.roomId).notifier)
              .releaseMic(userId: currentUserId);
        } catch (error) {
          logError(
            'Mic seat release failed after audio stopped',
            error: error,
            metadata: {
              'room_id': widget.roomId,
              'user_id': currentUserId,
            },
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Microphone is off, but the mic seat could not be released: '
                  '$error',
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      sessionNotifier.setAudioEnabled(previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mic toggle failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleAudioSharing(bool enabled) async {
    ref
        .read(roomSessionProvider(widget.roomId).notifier)
        .setAudioSharingEnabled(enabled);
    try {
      await ref
          .read(activeRoomWebRTCProvider(widget.roomId).notifier)
          .toggleSystemAudioSharing(enabled);
    } catch (e) {
      if (mounted) {
        ref
            .read(roomSessionProvider(widget.roomId).notifier)
            .setAudioSharingEnabled(!enabled);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share audio: $e')),
        );
      }
    }
  }

  Future<void> _setMicOutputVolume(double volume) async {
    setState(() => _micOutputVolume = volume);
    try {
      await ref
          .read(activeRoomWebRTCProvider(widget.roomId).notifier)
          .setMicOutputVolume(volume);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change mic output: $error')),
        );
      }
    }
  }

  Future<void> _setSharedAudioOutputVolume(double volume) async {
    setState(() => _sharedAudioOutputVolume = volume);
    try {
      await ref
          .read(activeRoomWebRTCProvider(widget.roomId).notifier)
          .setSharedAudioOutputVolume(volume);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change shared audio output: $error'),
          ),
        );
      }
    }
  }

  Future<void> _toggleRoomSound() async {
    final nextMuted = !_isRoomSoundMuted;
    try {
      await ref
          .read(activeRoomWebRTCProvider(widget.roomId).notifier)
          .setRoomOutputMuted(nextMuted);
      if (mounted) {
        setState(() => _isRoomSoundMuted = nextMuted);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change room sound: $error')),
        );
      }
    }
  }

  Future<void> _showAudioOutputControls() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: VelvetNoir.surfaceHigh,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildSlider({
              required String label,
              required IconData icon,
              required double value,
              required ValueChanged<double> onChanged,
            }) {
              return Semantics(
                label: '$label ${(value * 100).round()} percent',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: VelvetNoir.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label,
                            style: GoogleFonts.raleway(
                              color: VelvetNoir.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${(value * 100).round()}%',
                          style: GoogleFonts.raleway(
                            color: VelvetNoir.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: value,
                      min: 0,
                      max: 2,
                      divisions: 40,
                      label: '${(value * 100).round()}%',
                      onChanged: (next) {
                        setSheetState(() => onChanged(next));
                      },
                    ),
                  ],
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outgoing Audio Levels',
                      style: GoogleFonts.playfairDisplay(
                        color: VelvetNoir.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Controls what everyone in the room hears.',
                      style: GoogleFonts.raleway(
                        color: VelvetNoir.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 18),
                    buildSlider(
                      label: 'Mic Output',
                      icon: Icons.mic,
                      value: _micOutputVolume,
                      onChanged: (next) {
                        unawaited(_setMicOutputVolume(next));
                      },
                    ),
                    const SizedBox(height: 12),
                    buildSlider(
                      label: 'Shared Audio Output',
                      icon: Icons.screen_share,
                      value: _sharedAudioOutputVolume,
                      onChanged: (next) {
                        unawaited(_setSharedAudioOutputVolume(next));
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleRosterUserTap({
    required RoomParticipantModel participant,
    required String currentUserId,
  }) async {
    final normalizedCurrentUserId = currentUserId.trim();
    final targetUserId = participant.userId.trim();
    if (normalizedCurrentUserId.isEmpty || targetUserId.isEmpty) {
      return;
    }

    final displayName = (participant.displayName?.trim().isNotEmpty ?? false)
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

    final service = ref.read(activeRoomWebRTCProvider(widget.roomId))?.service;
    int? remoteUid;
    for (final uid in service?.remoteVideoUids ?? const <int>[]) {
      if (service?.userIdForUid(uid) == targetUserId) {
        remoteUid = uid;
        break;
      }
    }

    if (remoteUid != null && mounted) {
      setState(() => _expandedVideoKey = 'remote_$remoteUid');
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$displayName camera stream is still connecting.'),
        ),
      );
    }
  }

  String _rosterDisplayName(RoomParticipantModel participant) {
    final resolved = participant.displayName?.trim() ?? '';
    return resolved.isNotEmpty
        ? resolved
        : liveRoomMemberFallback(participant.userId);
  }

  void _openRosterWhisper(RoomParticipantModel participant) {
    final targetUserId = participant.userId.trim();
    if (targetUserId.isEmpty) return;
    setState(() {
      _whisperTargetUserId = targetUserId;
      _whisperTargetName = _rosterDisplayName(participant);
    });
    messageController.clear();
  }

  void _sendRosterGift(RoomParticipantModel participant) {
    GiftPickerSheet.show(
      context,
      ref,
      recipientId: participant.userId,
      recipientName: _rosterDisplayName(participant),
    );
  }

  void _sendRosterMoney(RoomParticipantModel participant) {
    final name = _rosterDisplayName(participant);
    final message = kPaymentsEnabled
        ? 'Open Payments to send money to $name.'
        : 'Send Money is unavailable during beta testing.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    if (kPaymentsEnabled) {
      context.go('/profile/payments');
    }
  }

  Future<void> _sendMessage(String text) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty || _isSendingChatMessage) return;
    setState(() => _isSendingChatMessage = true);

    try {
      final auth = ref.read(firebaseAuthProvider);
      final currentUser = auth.currentUser;
      if (currentUser == null) return;

      final sessionState = ref.read(roomSessionProvider(widget.roomId));
      final firestore = ref.read(firestoreProvider);
      final fallbackName = _displayNameFromAuthUser(currentUser);
      final cachedName =
          sessionState.userDisplayNames[currentUser.uid]?.trim() ?? '';
      final senderName = cachedName.isNotEmpty ? cachedName : fallbackName;
      final whisperTargetUserId = _whisperTargetUserId?.trim() ?? '';

      if (whisperTargetUserId.isNotEmpty) {
        final whisperRef = firestore
            .collection('rooms')
            .doc(widget.roomId)
            .collection('whispers')
            .doc();
        await whisperRef.set({
          'id': whisperRef.id,
          'roomId': widget.roomId,
          'senderId': currentUser.uid,
          'senderName': senderName,
          'recipientId': whisperTargetUserId,
          'recipientName': _whisperTargetName ?? '',
          'participantIds': [currentUser.uid, whisperTargetUserId],
          'content': normalizedText,
          'createdAt': FieldValue.serverTimestamp(),
          'clientSentAt': Timestamp.now(),
        });
        messageController.clear();
        return;
      }

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
        'content': normalizedText,
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
    } catch (error) {
      logError(
        'Room chat send failed',
        error: error,
        metadata: {
          'room_id': widget.roomId,
          'is_whisper': (_whisperTargetUserId ?? '').isNotEmpty,
          'target_user_id': _whisperTargetUserId,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send message: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingChatMessage = false);
      }
    }
  }

  Stream<List<_RoomChatEntry>> _roomChatEntriesStream({
    required FirebaseFirestore firestore,
    required String userId,
  }) {
    if (_chatEntriesStream == null || _chatEntriesStreamUserId != userId) {
      _chatEntriesStreamUserId = userId;
      _chatEntriesStream = _watchRoomChatEntries(
        firestore: firestore,
        roomId: widget.roomId,
        userId: userId,
      );
    }
    return _chatEntriesStream!;
  }

  String get _roomShareUrl =>
      'https://mixvy-v2.web.app/rooms/room/${widget.roomId}';

  Future<void> _copyRoomLink() async {
    await Clipboard.setData(ClipboardData(text: _roomShareUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room link copied to clipboard.')),
    );
  }

  Future<void> _shareRoom(String roomName) async {
    try {
      await Share.share(
        'Join me in "$roomName" on MIXVY!\n$_roomShareUrl',
        subject: '$roomName – MIXVY live room',
      );
    } catch (error) {
      logError(
        'External room share failed; copying link instead',
        error: error,
        metadata: {'room_id': widget.roomId},
      );
      await _copyRoomLink();
    }
  }

  void _showRoomShareSheet(RoomModel room) {
    final currentUser = ref.read(userProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to invite friends.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VelvetNoir.surfaceHigh,
      builder: (sheetContext) => Consumer(
        builder: (context, sheetRef, _) => RoomShareSheet(
          roomName: room.name,
          friends: sheetRef.watch(friendsListProvider),
          onShareExternally: () => _shareRoom(room.name),
          onCopyLink: _copyRoomLink,
          onRetry: () => sheetRef.invalidate(friendsListProvider),
          onSendInvites: (friendIds) =>
              sheetRef.read(roomRepositoryProvider).sendRoomInviteToFriends(
                    friendIds: friendIds,
                    inviterId: currentUser.id,
                    inviterName: currentUser.username,
                    roomId: widget.roomId,
                    roomName: room.name,
                  ),
        ),
      ),
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
                          final currentUserId =
                              FirebaseAuth.instance.currentUser?.uid;
                          final isYou = userId == currentUserId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: VelvetNoir.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    VelvetNoir.primary.withValues(alpha: 0.2),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              padding: const EdgeInsets.only(
                                                  left: 8),
                                              child: Chip(
                                                label: Text(
                                                  'You',
                                                  style: GoogleFonts.raleway(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                backgroundColor:
                                                    VelvetNoir.liveGlow,
                                                labelPadding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                ),
                                                padding: EdgeInsets.zero,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: role == 'host'
                                              ? VelvetNoir.primary
                                                  .withValues(alpha: 0.2)
                                              : VelvetNoir.secondary
                                                  .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
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
                                    ],
                                  ),
                                ),
                              ],
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
            content:
                const Text('Connection recovered! Camera is available again.'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    }
  }

  /// Listen to new gift events and show toast + floating animation.
  void _checkForNewGift(List<RoomGiftEvent> gifts) {
    if (gifts.isEmpty) {
      _lastSeenGiftId = null;
      return;
    }

    final latestGift = gifts.first;

    // Only trigger animation for new gifts (first time seeing this ID)
    if (_lastSeenGiftId == null || _lastSeenGiftId != latestGift.id) {
      _lastSeenGiftId = latestGift.id;

      // Show floating emoji animation
      FloatingGiftAnimation.show(
        context,
        emoji: latestGift.emoji,
        duration: const Duration(milliseconds: 3000),
      );

      // Show toast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${latestGift.senderName} sent ${latestGift.emoji} to ${latestGift.receiverName ?? 'a guest'}!',
              style: const TextStyle(color: VelvetNoir.onSurface),
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: VelvetNoir.secondary.withValues(alpha: 0.8),
          ),
        );
      }
    }
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

  Future<void> _requestMic(String userId) async {
    if (_isMicActionBusy) return;
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in again to request the mic.')),
      );
      return;
    }

    setState(() => _isMicActionBusy = true);
    try {
      final result = await ref
          .read(roomControllerProvider(widget.roomId).notifier)
          .requestMic(userId: normalizedUserId);
      if (result == MicRequestResult.grabbed &&
          !ref.read(roomSessionProvider(widget.roomId)).isAudioEnabled) {
        await _toggleAudio(true, micClaimConfirmed: true);
      }
      if (!mounted) return;
      final message = result == MicRequestResult.grabbed
          ? 'You are now on mic.'
          : 'Hand raised. Waiting for host approval.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      logError(
        'Mic request failed',
        error: error,
        metadata: {'room_id': widget.roomId, 'user_id': normalizedUserId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mic request failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isMicActionBusy = false);
      }
    }
  }

  Future<void> _leaveMicQueue(MicAccessRequestModel request) async {
    if (_isMicActionBusy) return;
    setState(() => _isMicActionBusy = true);
    try {
      await ref
          .read(roomControllerProvider(widget.roomId).notifier)
          .cancelMicRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You left the mic queue.')),
        );
      }
    } catch (error) {
      logError(
        'Mic queue cancellation failed',
        error: error,
        metadata: {
          'room_id': widget.roomId,
          'request_id': request.id,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not leave the mic queue: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMicActionBusy = false);
      }
    }
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
    final sessionState = ref.watch(roomSessionProvider(widget.roomId));
    final roomDocAsync = ref.watch(roomDocLiveProvider(widget.roomId));
    if (currentUser != null) {
      ref.listen(
        pendingCamViewRequestsProvider((
          roomId: widget.roomId,
          targetId: currentUser.uid,
        )),
        (previous, next) => next.whenData(_queueCamViewRequests),
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

    // Reconcile the optimistic "Video ON" session flag with the real Agora
    // engine capture state. enableVideo() only throws (and reverts the
    // session flag) if the camera fails to start in the first place; if the
    // camera stops later on its own (hardware interruption, OS revoking
    // access, etc.) the session flag would otherwise stay stuck "on" forever
    // with no way to recover (e.g. "switch camera" then fails with
    // camera-switch-unavailable even though the UI still claims video is on).
    //
    // Only wire this up once the room actually exists: watching/creating the
    // WebRTC transport for a room that is still loading or was not found
    // wastes a real Agora connection attempt and can throw a Riverpod
    // "disposed during loading" error if the user navigates away before it
    // resolves.
    if (roomDoc != null) {
      ref.listen(activeRoomWebRTCProvider(widget.roomId), (previous, next) {
        final wasCapturing = previous?.isLocalVideoCapturing ?? false;
        final isCapturing = next?.isLocalVideoCapturing ?? false;
        if (wasCapturing &&
            !isCapturing &&
            !_toggleVideoInFlight &&
            ref.read(roomSessionProvider(widget.roomId)).isVideoEnabled) {
          ref
              .read(roomSessionProvider(widget.roomId).notifier)
              .setVideoEnabled(false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Camera stopped unexpectedly. Tap Camera to retry.'),
              ),
            );
          }
        }
      });
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
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: parsedRoom == null
                  ? null
                  : () => _showRoomShareSheet(parsedRoom!),
              tooltip: 'Invite friends or share room',
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
      body: roomDocAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildUnavailableRoom(
          message: 'Could not load this room. Check your connection and retry.',
          onRetry: () => ref.invalidate(roomDocStreamProvider(widget.roomId)),
        ),
        data: (roomMap) {
          if (roomMap == null) {
            return _buildUnavailableRoom(
              message: 'Room not found. It may have ended or been removed.',
              onRetry: () =>
                  ref.invalidate(roomDocStreamProvider(widget.roomId)),
            );
          }

          final room = RoomModel.fromJson(roomMap, widget.roomId);
          _ensureAutoJoined(
              currentUser: currentUser, sessionState: sessionState);
          return LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth > 1200
                ? _buildDesktopLayout(room, currentUser, sessionState)
                : _buildMobileLayout(room, currentUser, sessionState),
          );
        },
      ),
    );
  }

  Widget _buildUnavailableRoom({
    required String message,
    required VoidCallback onRetry,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.meeting_room_outlined,
                  color: VelvetNoir.primary,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.raleway(color: VelvetNoir.onSurface),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    FilledButton.icon(
                      onPressed: () => context.go('/rooms'),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Rooms'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
      RoomModel room, User? currentUser, RoomSessionState sessionState) {
    final currentUserId = currentUser?.uid ?? '';
    final stageHeight = (MediaQuery.sizeOf(context).height * 0.32)
        .clamp(220.0, 320.0)
        .toDouble();
    final isHostLike = currentUserId.isNotEmpty &&
        (room.hostId == currentUserId ||
            room.ownerId == currentUserId ||
            room.adminUserIds.contains(currentUserId));

    return Column(
      children: [
        // Video Grid Area
        SizedBox(
          height: stageHeight,
          child: sessionState.hasJoined
              ? _buildVideoArea(room, sessionState)
              : _buildRoomPreview(room),
        ),

        // Room Info & Controls
        Expanded(
          child: Column(
            children: [
              _buildRoomHeader(room, ref),
              Consumer(
                builder: (context, sideRef, _) {
                  final participants = sideRef
                          .watch(roomParticipantsLiveProvider(widget.roomId))
                          .valueOrNull ??
                      const [];
                  final displayNameById = {
                    for (final participant in participants)
                      participant.userId:
                          ((participant.displayName?.trim().isNotEmpty ?? false)
                              ? participant.displayName!.trim()
                              : participant.userId),
                  };
                  final rankTierById = {
                    for (final participant in participants)
                      participant.userId: participant.rankTier,
                  };
                  final diamondById = {
                    for (final participant in participants)
                      participant.userId: participant.diamondLevel,
                  };

                  return MicQueuePanel(
                    roomId: widget.roomId,
                    currentUserId: currentUserId,
                    isHost: isHostLike,
                    displayNameById: displayNameById,
                    rankTierById: rankTierById,
                    diamondLevelById: diamondById,
                    onJoinQueue: _isMicActionBusy
                        ? null
                        : () => _requestMic(currentUserId),
                    onLeaveQueue: _isMicActionBusy ? null : _leaveMicQueue,
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
                  );
                },
              ),
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

  Widget _buildDesktopLayout(
      RoomModel room, User? currentUser, RoomSessionState sessionState) {
    final currentUserId = currentUser?.uid ?? '';
    final isHostLike = currentUserId.isNotEmpty &&
        (room.hostId == currentUserId ||
            room.ownerId == currentUserId ||
            room.adminUserIds.contains(currentUserId));

    return Row(
      children: [
        // Left: Video Grid
        Expanded(
          child: Column(
            children: [
              if (sessionState.hasJoined)
                Expanded(child: _buildVideoArea(room, sessionState))
              else
                Expanded(child: _buildRoomPreview(room)),
              _buildControlBar(room, currentUser, sessionState),
            ],
          ),
        ),
        VerticalDivider(color: VelvetNoir.surfaceHigh, width: 1),
        // Middle: Chat
        SizedBox(
          width: liveRoomDesktopChatWidth,
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
          width: liveRoomDesktopRosterWidth,
          child: Column(
            children: [
              Consumer(
                builder: (context, sideRef, _) {
                  final participantsAsync = sideRef
                      .watch(roomParticipantsLiveProvider(widget.roomId));

                  final participants =
                      participantsAsync.valueOrNull ?? const [];
                  final displayNameById = {
                    for (final p in participants)
                      p.userId: ((p.displayName?.trim().isNotEmpty ?? false)
                          ? p.displayName!.trim()
                          : p.userId),
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
                    onJoinQueue: _isMicActionBusy
                        ? null
                        : () => _requestMic(currentUserId),
                    onLeaveQueue: _isMicActionBusy ? null : _leaveMicQueue,
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
                  );
                },
              ),
              Expanded(
                child: Consumer(
                  builder: (context, sideRef, _) {
                    final participants = sideRef
                            .watch(roomParticipantsLiveProvider(widget.roomId))
                            .valueOrNull ??
                        const [];
                    final presence = sideRef
                            .watch(roomPresenceLiveProvider(widget.roomId))
                            .valueOrNull ??
                        const [];
                    final queue = sideRef
                            .watch(roomMicAccessRequestsProvider(widget.roomId))
                            .valueOrNull ??
                        const [];

                    final projectedParticipants = _projectParticipantsForRoster(
                      participants: participants,
                      sessionState: sessionState,
                      currentUser: currentUser,
                      room: room,
                    );
                    final rtcService = sideRef
                        .watch(activeRoomWebRTCProvider(widget.roomId))
                        ?.service;
                    final activeRemoteCameraUserIds = <String>{
                      for (final uid
                          in rtcService?.remoteVideoUids ?? const <int>[])
                        if (rtcService?.userIdForUid(uid) case final userId?)
                          userId,
                    };
                    final rosterParticipants = kIsWeb
                        ? mergeLiveRoomRemoteCameraParticipants(
                            participants: projectedParticipants,
                            remoteCameraUserIds: activeRemoteCameraUserIds,
                            sessionDisplayNames: sessionState.userDisplayNames,
                            now: DateTime.now(),
                          )
                        : projectedParticipants;

                    final resolvedRosterParticipants = rosterParticipants.map(
                      (participant) {
                        final userId = participant.userId.trim();
                        final liveProfileName = userId.isEmpty
                            ? null
                            : sideRef
                                .watch(displayNameLiveProvider(userId))
                                .valueOrNull;
                        return participant.copyWith(
                          displayName: resolveLiveRoomDisplayName(
                            userId: userId,
                            liveProfileName: liveProfileName,
                            sessionName: sessionState.userDisplayNames[userId],
                            participantName: participant.displayName,
                          ),
                        );
                      },
                    ).toList(growable: false);

                    final pendingQueueUserIds = queue
                        .where((q) => q.status == 'pending' && !q.isExpired)
                        .map((q) => q.requesterId)
                        .toSet();

                    final displayNameById = {
                      for (final p in resolvedRosterParticipants)
                        p.userId: ((p.displayName?.trim().isNotEmpty ?? false)
                            ? p.displayName!.trim()
                            : p.userId),
                    };
                    final avatarById = {
                      for (final p in resolvedRosterParticipants)
                        p.userId: p.photoUrl,
                    };
                    return UserListPanel(
                      participants: resolvedRosterParticipants,
                      currentUserId: currentUserId,
                      presenceList: presence,
                      displayNameById: displayNameById,
                      avatarUrlById: avatarById,
                      micQueueUserIds: pendingQueueUserIds,
                      onTapUser: (participant) => _handleRosterUserTap(
                        participant: participant,
                        currentUserId: currentUserId,
                      ),
                      onWhisper: _openRosterWhisper,
                      onGift: _sendRosterGift,
                      onSendMoney: _sendRosterMoney,
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

  Widget _buildVideoArea(RoomModel room, RoomSessionState sessionState) {
    return Consumer(
      builder: (context, ref, _) {
        final webrtcState = ref.watch(activeRoomWebRTCProvider(widget.roomId));
        final healthState = ref.watch(connectionHealthProvider);
        final recoveryState = ref.watch(connectionRecoveryProvider);
        final giftsAsync = ref.watch(roomGiftFeedProvider(widget.roomId));
        final roomParticipants = ref
                .watch(roomParticipantsLiveProvider(widget.roomId))
                .valueOrNull ??
            const [];
        final sessionNotifier =
            ref.read(roomSessionProvider(widget.roomId).notifier);

        // Trigger animations for new gifts
        giftsAsync.whenData((gifts) {
          _checkForNewGift(gifts);
        });

        // Trigger audio-only fallback if recovery takes >5 seconds
        _handleRecoveryTimeout(
          recoveryState: recoveryState,
          sessionNotifier: sessionNotifier,
          context: context,
          isVideoEnabled: sessionState.isVideoEnabled,
        );

        if (webrtcState?.service == null) {
          return RoomStageBackground(
            imageUrl: room.thumbnailUrl,
            child: Center(
              child: Text(
                'Initializing video...',
                style: GoogleFonts.raleway(
                  color: VelvetNoir.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }

        final service = webrtcState!.service!;
        final remoteUids = service.remoteVideoUids;

        final gridEntries =
            <({String key, String label, Widget view, bool isLocal})>[];
        if (sessionState.isVideoEnabled) {
          gridEntries.add((
            key: 'local',
            label: 'You',
            view: service.getLocalView(),
            isLocal: true,
          ));
        }

        for (final uid in remoteUids) {
          final mappedUserId = service.userIdForUid(uid);
          final participantNames = roomParticipants
              .where((p) => mappedUserId != null && p.userId == mappedUserId)
              .map((p) => p.displayName?.trim() ?? '');
          final sessionName = mappedUserId == null
              ? ''
              : (sessionState.userDisplayNames[mappedUserId]?.trim() ?? '');
          final liveProfileName = mappedUserId == null
              ? null
              : ref.watch(displayNameLiveProvider(mappedUserId)).valueOrNull;
          final resolvedLabel = resolveLiveRoomDisplayName(
            userId: mappedUserId ?? '$uid',
            liveProfileName: liveProfileName,
            sessionName: sessionName,
            participantName:
                participantNames.isEmpty ? null : participantNames.first,
          );
          gridEntries.add((
            key: 'remote_$uid',
            label: resolvedLabel,
            view: service.getRemoteView(uid, widget.roomId),
            isLocal: false,
          ));
        }

        final gridSlotCount = _manualGridSlotCount ??
            liveRoomAutomaticGridSlotCount(gridEntries.length);
        final visibleCount = gridEntries.length > gridSlotCount
            ? gridSlotCount
            : gridEntries.length;
        final visibleEntries =
            gridEntries.take(visibleCount).toList(growable: false);
        final placeholders = gridSlotCount - visibleEntries.length;

        return Stack(
          children: [
            RoomStageBackground(
              imageUrl: room.thumbnailUrl,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 46, 2, 2),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const tileGap = 3.0;
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    final crossAxisCount =
                        liveRoomGridColumnCount(gridSlotCount, width);
                    final rowCount = (gridSlotCount / crossAxisCount).ceil();
                    final tileWidth =
                        (width - ((crossAxisCount - 1) * tileGap)) /
                            crossAxisCount;
                    final tileHeight =
                        (height - ((rowCount - 1) * tileGap)) / rowCount;
                    final childAspectRatio = tileWidth.isFinite &&
                            tileHeight.isFinite &&
                            tileWidth > 0 &&
                            tileHeight > 0
                        ? tileWidth / tileHeight
                        : 4 / 3;

                    Widget buildVideoTile({
                      required String videoKey,
                      required String label,
                      required Widget view,
                      required bool isLocal,
                      required bool expanded,
                    }) {
                      return DecoratedBox(
                        key: ValueKey('live-video-$videoKey'),
                        decoration: BoxDecoration(
                          color: VelvetNoir.surface,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: isLocal
                                ? VelvetNoir.primary.withValues(alpha: 0.75)
                                : VelvetNoir.secondary.withValues(alpha: 0.55),
                            width: 1.4,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              view,
                              Positioned(
                                top: 6,
                                right: 6,
                                child: IconButton(
                                  tooltip: expanded
                                      ? 'Return to camera grid'
                                      : 'Expand camera',
                                  onPressed: () => setState(() {
                                    _expandedVideoKey =
                                        expanded ? null : videoKey;
                                  }),
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.black.withValues(alpha: 0.62),
                                    foregroundColor: VelvetNoir.onSurface,
                                    minimumSize: const Size(34, 34),
                                    padding: const EdgeInsets.all(7),
                                  ),
                                  icon: Icon(
                                    expanded
                                        ? Icons.close_fullscreen
                                        : Icons.open_in_full,
                                    size: 17,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                right: 48,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.58),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    label,
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
                            ],
                          ),
                        ),
                      );
                    }

                    final expandedIndex = visibleEntries.indexWhere(
                      (entry) => entry.key == _expandedVideoKey,
                    );
                    if (expandedIndex >= 0) {
                      final entry = visibleEntries[expandedIndex];
                      return buildVideoTile(
                        videoKey: entry.key,
                        label: entry.label,
                        view: entry.view,
                        isLocal: entry.isLocal,
                        expanded: true,
                      );
                    }

                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      primary: false,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: tileGap,
                        mainAxisSpacing: tileGap,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: visibleEntries.length + placeholders,
                      itemBuilder: (context, index) {
                        if (index < visibleEntries.length) {
                          final entry = visibleEntries[index];
                          return buildVideoTile(
                            videoKey: entry.key,
                            label: entry.label,
                            view: entry.view,
                            isLocal: entry.isLocal,
                            expanded: false,
                          );
                        }

                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: VelvetNoir.onSurfaceVariant
                                  .withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.person,
                            color: VelvetNoir.onSurfaceVariant
                                .withValues(alpha: 0.32),
                            size: 38,
                          ),
                        );
                      },
                    );
                  },
                ),
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
                  border: Border.all(
                      color: VelvetNoir.primary.withValues(alpha: 0.35)),
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
                    GestureDetector(
                      onTap: () => setState(() => _manualGridSlotCount = null),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _manualGridSlotCount == null
                              ? VelvetNoir.primary
                              : VelvetNoir.surfaceHigh,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Auto',
                          style: GoogleFonts.raleway(
                            color: _manualGridSlotCount == null
                                ? VelvetNoir.surface
                                : VelvetNoir.onSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    for (final count in const [4, 8, 12, 16, 20]) ...[
                      GestureDetector(
                        onTap: () =>
                            setState(() => _manualGridSlotCount = count),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _manualGridSlotCount == count
                                ? VelvetNoir.primary
                                : VelvetNoir.surfaceHigh,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.raleway(
                              color: _manualGridSlotCount == count
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.white, size: 18),
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
                        sessionState.isVideoEnabled
                            ? VelvetNoir.liveGlow
                            : VelvetNoir.surfaceHighest,
                      ),
                      _buildStatusBadge(
                        sessionState.isAudioEnabled ? 'Mic ON' : 'Mic OFF',
                        sessionState.isAudioEnabled
                            ? VelvetNoir.liveGlow
                            : VelvetNoir.surfaceHighest,
                      ),
                      NetworkHealthWidget(
                        showLabel: false,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                      ),
                    ],
                  ),

                  // Health Badge: Shows when connection is degrading or worse
                  if (healthState.isAtRisk)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: switch (healthState.health) {
                          ConnectionHealth.healthy =>
                            Colors.green.withValues(alpha: 0.8),
                          ConnectionHealth.degrading =>
                            Colors.orange.withValues(alpha: 0.8),
                          ConnectionHealth.degraded =>
                            Colors.red.withValues(alpha: 0.8),
                          ConnectionHealth.unavailable =>
                            Colors.grey.withValues(alpha: 0.8),
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
                              ConnectionHealth.unavailable =>
                                Icons.cloud_off_rounded,
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
                  if (webrtcState.connectionState ==
                          RtcConnectionState.degraded ||
                      webrtcState.connectionState ==
                          RtcConnectionState.reconnecting)
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
                  ref
                      .read(activeRoomWebRTCProvider(widget.roomId).notifier)
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
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
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
          ),
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
    final rtcService =
        ref.watch(activeRoomWebRTCProvider(widget.roomId))?.service;
    final remoteCameraUserIds = <String>{
      for (final uid in rtcService?.remoteVideoUids ?? const <int>[])
        if (rtcService?.userIdForUid(uid) case final userId?) userId,
    };
    final totalDiamonds = participants.fold<int>(
      0,
      (total, participant) => total + participant.diamondLevel,
    );
    final liveBroadcasters = {
      ...participants
          .where((participant) => participant.camOn || participant.micOn)
          .map((participant) => participant.userId),
      ...remoteCameraUserIds,
    }.length;
    final observedListenerIds = {
      ...participants.map((participant) => participant.userId),
      ...remoteCameraUserIds,
      if (currentUser != null) currentUser.uid,
    };
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
        border: Border(
            bottom:
                BorderSide(color: VelvetNoir.primary.withValues(alpha: 0.2))),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: FutureBuilder<String>(
                  future: _getUserDisplayName(
                    room.hostId.trim().isNotEmpty ? room.hostId : room.ownerId,
                  ),
                  builder: (context, snapshot) {
                    final resolved = (snapshot.data ?? '').trim();
                    final effectiveHostLabel =
                        resolved.isNotEmpty ? resolved : hostLabel;
                    return Text(
                      'Hosted by $effectiveHostLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.raleway(
                        fontSize: 12,
                        color: VelvetNoir.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
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
              Consumer(
                builder: (context, consumerRef, _) {
                  final participantCount =
                      consumerRef.watch(participantCountProvider(room.id));
                  final displayedParticipantCount =
                      participantCount > observedListenerIds.length
                          ? participantCount
                          : observedListenerIds.length;
                  return GestureDetector(
                    onTap: () => _showParticipantsPanel(room.id),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Row(
                        children: [
                          const Icon(Icons.people,
                              size: 14, color: VelvetNoir.primary),
                          const SizedBox(width: 4),
                          Text(
                            '$displayedParticipantCount listeners',
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
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
      for (final participant in participants)
        participant.userId: participant.rankTier,
    };
    final diamondLevelById = {
      for (final participant in participants)
        participant.userId: participant.diamondLevel,
    };
    final badgeTitleById = {
      for (final participant in participants)
        if ((participant.badgeTitle ?? '').trim().isNotEmpty)
          participant.userId: participant.badgeTitle!.trim(),
    };

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<_RoomChatEntry>>(
            stream: _roomChatEntriesStream(
              firestore: firestore,
              userId: ref.read(firebaseAuthProvider).currentUser?.uid ?? '',
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Could not load room chat: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.raleway(
                        color: VelvetNoir.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return Center(
                  child: Text(
                    'Loading messages...',
                    style:
                        GoogleFonts.raleway(color: VelvetNoir.onSurfaceVariant),
                  ),
                );
              }

              final messages = snapshot.data!;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scrollController.hasClients) {
                  scrollController.animateTo(
                    scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });

              return ListView.builder(
                controller: scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final data = msg.data;
                  final senderName = data['senderName'] as String? ?? '';
                  final senderId = data['senderId'] as String? ?? '';
                  final content = data['content'] as String? ?? '';
                  final currentUserId =
                      ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
                  final recipientId = data['recipientId'] as String? ?? '';
                  final recipientName = data['recipientName'] as String? ?? '';
                  final otherWhisperUserId =
                      senderId == currentUserId ? recipientId : senderId;
                  final otherWhisperName =
                      senderId == currentUserId ? recipientName : senderName;

                  return FutureBuilder<String>(
                    future: _resolveMessageSenderName(
                      rawSenderName: senderName,
                      senderId: senderId,
                      sessionState: sessionState,
                    ),
                    builder: (context, senderSnapshot) {
                      final effectiveSenderName =
                          (senderSnapshot.data ?? senderName).trim().isNotEmpty
                              ? (senderSnapshot.data ?? senderName).trim()
                              : (senderId.trim().isNotEmpty
                                  ? _memberFallback(senderId)
                                  : 'MixVy Member');

                      return InkWell(
                        onTap: msg.isWhisper &&
                                otherWhisperUserId.trim().isNotEmpty
                            ? () {
                                setState(() {
                                  _whisperTargetUserId = otherWhisperUserId;
                                  _whisperTargetName =
                                      otherWhisperName.trim().isEmpty
                                          ? liveRoomMemberFallback(
                                              otherWhisperUserId,
                                            )
                                          : otherWhisperName.trim();
                                });
                              }
                            : null,
                        child: Container(
                          color: msg.isWhisper
                              ? const Color(0x33781E2B)
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: VelvetNoir.primary,
                                child: Text(
                                  roomAvatarInitials(effectiveSenderName),
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
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          msg.isWhisper
                                              ? '🔒 WHISPER · $effectiveSenderName'
                                              : effectiveSenderName,
                                          style: GoogleFonts.raleway(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: msg.isWhisper
                                                ? VelvetNoir.secondaryBright
                                                : VelvetNoir.primary,
                                          ),
                                        ),
                                        RoomRankDiamondBadgeRow(
                                          rankTier: rankTierById[senderId] ?? 0,
                                          diamondLevel:
                                              diamondLevelById[senderId] ?? 0,
                                          compact: true,
                                        ),
                                        if (badgeTitleById
                                            .containsKey(senderId))
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0x33781E2B),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                  color:
                                                      const Color(0x55781E2B)),
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
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        if ((_whisperTargetUserId ?? '').isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x33781E2B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x55781E2B)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: VelvetNoir.secondaryBright,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Whispering to ${_whisperTargetName ?? 'room member'} · only you two can see this',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.raleway(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: VelvetNoir.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Return to room chat',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      _whisperTargetUserId = null;
                      _whisperTargetName = null;
                    });
                    messageController.clear();
                  },
                  icon: const Icon(Icons.close_rounded, size: 16),
                ),
              ],
            ),
          ),
        if (sessionState.hasJoined)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: (_whisperTargetUserId ?? '').isNotEmpty
                          ? 'Whisper to ${_whisperTargetName ?? 'room member'}...'
                          : 'Message...',
                      hintStyle: GoogleFonts.raleway(
                        color: VelvetNoir.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: VelvetNoir.surfaceHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: GoogleFonts.raleway(color: VelvetNoir.onSurface),
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _isSendingChatMessage ? null : _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSendingChatMessage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  color: VelvetNoir.primary,
                  onPressed: _isSendingChatMessage
                      ? null
                      : () => _sendMessage(messageController.text),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildControlBar(
      RoomModel room, User? currentUser, RoomSessionState sessionState) {
    final supportsCameraSwitch = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final roomState = ref.watch(roomControllerProvider(widget.roomId));
    final canBroadcastAudio = RoomPermissions.canBroadcastAudio(
      userId: currentUser?.uid ?? '',
      speakerIds: roomState.speakerIds,
    );
    final canTakeOpenMic = RoomPermissions.canTakeOpenMic(
      userId: currentUser?.uid ?? '',
      speakerIds: roomState.speakerIds,
    );
    final currentUserId = currentUser?.uid ?? '';
    final myMicRequest = currentUserId.isEmpty
        ? null
        : ref
            .watch(
              myMicAccessRequestProvider((
                roomId: widget.roomId,
                requesterId: currentUserId,
              )),
            )
            .valueOrNull;
    final myPendingMicRequest =
        myMicRequest?.status == 'pending' && myMicRequest?.isExpired == false
            ? myMicRequest
            : null;
    final canShareAudio = RoomPermissions.canShareAudio(
      userId: currentUser?.uid ?? '',
      speakerIds: roomState.speakerIds,
      isMicEnabled: sessionState.isAudioEnabled,
    );
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceHigh,
          border: Border(
              top:
                  BorderSide(color: VelvetNoir.primary.withValues(alpha: 0.2))),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
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
                  foregroundColor: VelvetNoir.surface,
                ),
              )
            else ...[
              FilledButton.icon(
                onPressed: () => _toggleVideo(!sessionState.isVideoEnabled),
                icon: Icon(sessionState.isVideoEnabled
                    ? Icons.videocam
                    : Icons.videocam_off),
                label:
                    Text(sessionState.isVideoEnabled ? 'Camera' : 'Camera Off'),
                style: FilledButton.styleFrom(
                  backgroundColor: sessionState.isVideoEnabled
                      ? VelvetNoir.primary
                      : VelvetNoir.surfaceHighest,
                  foregroundColor: sessionState.isVideoEnabled
                      ? VelvetNoir.surface
                      : VelvetNoir.onSurfaceVariant,
                ),
              ),
              if (sessionState.isVideoEnabled && supportsCameraSwitch)
                FilledButton.icon(
                  onPressed: _switchCamera,
                  icon: const Icon(Icons.cameraswitch_outlined),
                  label: const Text('Swap Cam'),
                  style: FilledButton.styleFrom(
                    backgroundColor: VelvetNoir.surfaceHighest,
                    foregroundColor: VelvetNoir.onSurface,
                  ),
                ),
              FilledButton.icon(
                onPressed: _toggleRoomSound,
                icon: Icon(
                  _isRoomSoundMuted ? Icons.volume_off : Icons.volume_up,
                ),
                label: Text(
                  _isRoomSoundMuted ? 'Room Muted' : 'Room Sound',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _isRoomSoundMuted
                      ? VelvetNoir.secondary
                      : VelvetNoir.surfaceHighest,
                  foregroundColor: _isRoomSoundMuted
                      ? VelvetNoir.surface
                      : VelvetNoir.onSurfaceVariant,
                ),
              ),
              FilledButton.icon(
                onPressed: sessionState.isAudioEnabled
                    ? () => _toggleAudio(false)
                    : canBroadcastAudio
                        ? () => _toggleAudio(true)
                        : canTakeOpenMic
                            ? () => _requestMic(currentUserId)
                            : myPendingMicRequest != null
                                ? () => _leaveMicQueue(myPendingMicRequest)
                                : _isMicActionBusy
                                    ? null
                                    : () => _requestMic(currentUserId),
                icon: Icon(
                  sessionState.isAudioEnabled
                      ? Icons.mic
                      : canTakeOpenMic
                          ? Icons.record_voice_over
                          : myPendingMicRequest != null
                              ? Icons.exit_to_app_rounded
                              : Icons.queue_music_rounded,
                ),
                label: Text(
                  sessionState.isAudioEnabled
                      ? 'Mic'
                      : canBroadcastAudio
                          ? 'Mic Off'
                          : canTakeOpenMic
                              ? 'Take Mic'
                              : myPendingMicRequest != null
                                  ? 'Leave Queue'
                                  : 'Join Queue',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: sessionState.isAudioEnabled
                      ? VelvetNoir.primary
                      : VelvetNoir.surfaceHighest,
                  foregroundColor: sessionState.isAudioEnabled
                      ? VelvetNoir.surface
                      : VelvetNoir.onSurfaceVariant,
                ),
              ),
              if (canShareAudio) ...[
                FilledButton.icon(
                  onPressed: () => _toggleAudioSharing(
                    !sessionState.isAudioSharingEnabled,
                  ),
                  icon: Icon(sessionState.isAudioSharingEnabled
                      ? Icons.volume_up
                      : Icons.volume_mute),
                  label: Text(sessionState.isAudioSharingEnabled
                      ? 'Stop Audio Share'
                      : 'Share Audio'),
                  style: FilledButton.styleFrom(
                    backgroundColor: sessionState.isAudioSharingEnabled
                        ? VelvetNoir.secondary
                        : VelvetNoir.surfaceHighest,
                    foregroundColor: sessionState.isAudioSharingEnabled
                        ? VelvetNoir.surface
                        : VelvetNoir.onSurfaceVariant,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _showAudioOutputControls,
                  icon: const Icon(Icons.tune),
                  label: const Text('Audio Levels'),
                  style: FilledButton.styleFrom(
                    backgroundColor: VelvetNoir.surfaceHighest,
                    foregroundColor: VelvetNoir.onSurfaceVariant,
                  ),
                ),
              ],
              FilledButton.icon(
                onPressed: () =>
                    RoomGiftPickerSheet.show(context, ref, roomId: room.id),
                icon: const Icon(Icons.card_giftcard),
                label: const Text('Gift'),
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetNoir.primary,
                  foregroundColor: VelvetNoir.surface,
                ),
              ),
              FilledButton.icon(
                onPressed: currentUser != null ? _leaveRoom : null,
                icon: const Icon(Icons.logout),
                label: const Text('LEAVE'),
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetNoir.error,
                  foregroundColor: VelvetNoir.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

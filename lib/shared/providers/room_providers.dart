import 'package:flutter/material.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/infra/firestore_service.dart';
import '../../services/room/room_discovery_service.dart';
import '../../services/room/room_manager_service.dart';
import '../../services/room/room_service.dart';
import '../models/room.dart';
import '../models/user.dart';
import '../models/room_role.dart';
import '../models/agora_participant.dart';
import '../../features/room/providers/room_subcollection_providers.dart';
import 'agora_participant_provider.dart';
import 'auth_providers.dart';

final roomServiceProvider = Provider<RoomService>((ref) => RoomService());
final roomManagerServiceProvider =
    Provider<RoomManagerService>((ref) => RoomManagerService());
final roomDiscoveryServiceProvider =
    Provider<RoomDiscoveryService>((ref) => RoomDiscoveryService());

final roomStreamProvider = StreamProvider.family<Room?, String>((ref, roomId) {
  final stream = ref.watch(roomManagerServiceProvider).getRoomStream(roomId);
  return stream.map((snapshot) => null);
});

final liveRoomsStreamProvider =
    StreamProvider.family<List<Room>, String?>((ref, category) {
  return ref
      .watch(roomManagerServiceProvider)
      .getLiveRoomsStream()
      .map((snapshot) => []);
});

final raisedHandsProvider =
    StreamProvider.family<List<String>, String>((ref, roomId) {
  return ref.watch(roomStreamProvider(roomId)).maybeWhen(
        data: (room) => Stream.value(room?.raisedHands ?? const []),
        orElse: () => const Stream<List<String>>.empty(),
      );
});

final moderatorsProvider =
    StreamProvider.family<List<String>, String>((ref, roomId) {
  return ref.watch(roomStreamProvider(roomId)).maybeWhen(
        data: (room) => Stream.value(room?.moderators ?? const []),
        orElse: () => const Stream<List<String>>.empty(),
      );
});

final speakersProvider =
    StreamProvider.family<List<String>, String>((ref, roomId) {
  return ref.watch(roomStreamProvider(roomId)).maybeWhen(
        data: (room) => Stream.value(room?.speakers ?? const []),
        orElse: () => const Stream<List<String>>.empty(),
      );
});

final mutedUsersProvider =
    StreamProvider.family<List<String>, String>((ref, roomId) {
  return ref.watch(roomStreamProvider(roomId)).maybeWhen(
        data: (room) => Stream.value(room?.mutedUsers ?? const []),
        orElse: () => const Stream<List<String>>.empty(),
      );
});

final kickedUsersProvider =
    StreamProvider.family<List<String>, String>((ref, roomId) {
  return ref.watch(roomStreamProvider(roomId)).maybeWhen(
        data: (room) => Stream.value(room?.kickedUsers ?? const []),
        orElse: () => const Stream<List<String>>.empty(),
      );
});

// ðŸ”¥ PHASE 3.1b: Enriched participants provider
// Merges Agora real-time state (audio/video/speaking) with Firestore metadata (roles/timestamps)
final enrichedParticipantsProvider =
    StreamProvider.family<List<EnrichedParticipant>, String>((ref, roomId) {
  final agoraParticipants = ref.watch(agoraParticipantsProvider);
  final firestoreParticipantsAsync =
      ref.watch(roomParticipantsFirestoreProvider(roomId));
  final roomAsync = ref.watch(roomProvider(roomId));

  return firestoreParticipantsAsync.when(
    data: (firestoreParticipants) {
      final room = roomAsync.asData?.value;
      final enriched = <EnrichedParticipant>[];

      for (final fsParticipant in firestoreParticipants) {
        // Find matching Agora participant by userId
        final agoraParticipant = agoraParticipants.values.firstWhere(
          (ap) => ap.userId == fsParticipant.userId,
          orElse: () => AgoraParticipant(
            uid: fsParticipant.agoraUid,
            userId: fsParticipant.userId,
            displayName: fsParticipant.displayName,
            hasVideo: fsParticipant.isOnCam,
            hasAudio: !fsParticipant.isMuted,
            isSpeaking: fsParticipant.isSpeaking,
            joinedAt: fsParticipant.joinedAt,
          ),
        );

        enriched.add(EnrichedParticipant(
          userId: fsParticipant.userId,
          displayName: fsParticipant.displayName,
          avatarUrl: fsParticipant.avatarUrl,
          agoraUid: agoraParticipant.uid,
          role: fsParticipant.role,
          joinedAt: fsParticipant.joinedAt,
          hasVideo: agoraParticipant.hasVideo,
          hasAudio: agoraParticipant.hasAudio,
          isSpeaking: agoraParticipant.isSpeaking,
          connectionQuality: fsParticipant.connectionQuality,
          isHost: room != null && fsParticipant.userId == room.hostId,
          isModerator:
              room != null && room.moderators.contains(fsParticipant.userId),
          hasRaisedHand:
              room != null && room.raisedHands.contains(fsParticipant.userId),
        ));
      }

      return Stream.value(enriched);
    },
    loading: () => const Stream<List<EnrichedParticipant>>.empty(),
    error: (_, __) => const Stream<List<EnrichedParticipant>>.empty(),
  );
});

/// Enriched participant model combining Agora + Firestore data
class EnrichedParticipant {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int agoraUid;
  final RoomRole role;
  final DateTime joinedAt;
  final bool hasVideo;
  final bool hasAudio;
  final bool isSpeaking;
  final String connectionQuality;
  final bool isHost;
  final bool isModerator;
  final bool hasRaisedHand;

  const EnrichedParticipant({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.agoraUid,
    required this.role,
    required this.joinedAt,
    required this.hasVideo,
    required this.hasAudio,
    required this.isSpeaking,
    required this.connectionQuality,
    required this.isHost,
    required this.isModerator,
    required this.hasRaisedHand,
  });

  String get roleLabel {
    if (isHost) return 'Host';
    if (isModerator) return 'Moderator';
    switch (role) {
      case RoomRole.owner:
        return 'Owner';
      case RoomRole.admin:
        return 'Admin';
      case RoomRole.member:
        return 'Member';
      case RoomRole.muted:
        return 'Muted';
      case RoomRole.banned:
        return 'Banned';
    }
  }
}

final roomsProvider = FutureProvider.autoDispose<List<Room>>((ref) async {
  try {
    final snapshot =
        await FirebaseFirestore.instance.collection('rooms').limit(50).get();

    final rooms = snapshot.docs
        .map((doc) {
          try {
            return Room.fromDocument(doc);
          } catch (e) {
            debugPrint('Error parsing room ${doc.id}: $e');
            debugPrint('Room data: ${doc.data()}');
            return null;
          }
        })
        .whereType<Room>()
        .toList();

    debugPrint('Loaded ${rooms.length} rooms');
    return rooms;
  } catch (e) {
    debugPrint('Failed to load rooms: $e');
    return <Room>[];
  }
});

final paginatedRoomsProvider = StreamProvider.autoDispose
    .family<List<Room>, DocumentSnapshot?>((ref, startAfter) {
  var query = FirebaseFirestore.instance
      .collection('rooms')
      .orderBy('createdAt', descending: true)
      .limit(20);
  if (startAfter != null) {
    query = query.startAfterDocument(startAfter);
  }

  return query.snapshots().map((snapshot) {
    return snapshot.docs
        .map((doc) {
          try {
            return Room.fromDocument(doc);
          } catch (e) {
            debugPrint('Error parsing paginated room ${doc.id}: $e');
            return null;
          }
        })
        .whereType<Room>()
        .toList();
  }).handleError((error) {
    debugPrint('Paginated rooms error: $error');
    return <Room>[];
  });
});

final roomProvider = StreamProvider.family<Room?, String>((ref, roomId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getRoomStream(roomId);
});

final activeRoomsProvider = FutureProvider.autoDispose<List<Room>>((ref) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('rooms')
        .where('isLive', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    final rooms = snapshot.docs
        .map((doc) {
          try {
            return Room.fromDocument(doc);
          } catch (e) {
            debugPrint('Error parsing active room ${doc.id}: $e');
            return null;
          }
        })
        .whereType<Room>()
        .toList();

    return rooms;
  } catch (e) {
    debugPrint('Failed to load active rooms: $e');
    return <Room>[];
  }
});

final userRoomsProvider =
    FutureProvider.autoDispose.family<List<Room>, String>((ref, userId) async {
  try {
    final allRooms = await ref.watch(roomsProvider.future);
    return allRooms.where((room) => room.hostId == userId).toList();
  } catch (e) {
    debugPrint('Failed to load user rooms: $e');
    return <Room>[];
  }
});

final roomParticipantsProvider =
    StreamProvider.family<List<User>, String>((ref, roomId) async* {
  final room = await ref.watch(roomProvider(roomId).future);
  if (room == null) {
    yield [];
    return;
  }

  yield [];
});

final roomCategoriesProvider = Provider<List<String>>((ref) {
  return const [
    'All',
    'Music',
    'Gaming',
    'Chat',
    'Entertainment',
    'Education',
    'Business',
    'Sports',
    'Other',
  ];
});

final roomControllerProvider =
    NotifierProvider<RoomController, AsyncValue<Room?>>(() {
  return RoomController();
});

class RoomController extends Notifier<AsyncValue<Room?>> {
  late final RoomService _roomService;
  late final FirestoreService _firestoreService;
  StreamSubscription<Room?>? _roomSubscription;

  @override
  AsyncValue<Room?> build() {
    _roomService = ref.watch(roomServiceProvider);
    _firestoreService = ref.watch(firestoreServiceProvider);
    ref.onDispose(() {
      _roomSubscription?.cancel();
    });
    return const AsyncValue.data(null);
  }

  Future<String?> createRoom({
    required String name,
    required String description,
    bool isPrivate = false,
    RoomType roomType = RoomType.voice,
    String category = 'Other',
    List<String> tags = const [],
  }) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final room = Room(
        id: '',
        title: name,
        description: description,
        hostId: currentUser.id,
        tags: tags,
        category: category,
        createdAt: DateTime.now(),
        isLive: true,
        viewerCount: 0,
        isLocked: isPrivate,
        roomType: roomType,
      );

      await _firestoreService.createRoom(room);
      final roomId = room.id;
      _listenToRoom(roomId);
      return roomId;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  Future<void> joinRoom(String roomId) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _roomService.joinVoiceRoom(
        roomId,
        currentUser.id,
        currentUser.displayName ?? currentUser.username,
      );
      _listenToRoom(roomId);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  Future<void> leaveRoom(String roomId) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _roomService.leaveVoiceRoom(roomId, currentUser.id);
      _roomSubscription?.cancel();
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteRoom(String roomId) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _roomService.deleteRoom(roomId, currentUser.id);
      _roomSubscription?.cancel();
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  Future<void> inviteUserToRoom(String roomId, String userId) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _roomService.inviteUser(roomId, currentUser.id, userId);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  Future<void> kickUserFromRoom(String roomId, String userId) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _roomService.kickUser(roomId, currentUser.id, userId);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  Future<void> banUserFromRoom(String roomId, String userId) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _roomService.banUser(roomId, currentUser.id, userId);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  Future<void> promoteToSpeaker(String roomId, String userId) async {
    try {
      await _roomService.promoteToSpeaker(roomId, userId);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  Future<void> demoteToListener(String roomId, String userId) async {
    try {
      await _roomService.demoteToListener(roomId, userId);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  void _listenToRoom(String roomId) {
    _roomSubscription?.cancel();
    _roomSubscription = _firestoreService.getRoomStream(roomId).listen(
      (room) {
        if (room != null) {
          state = AsyncValue.data(room);
        } else {
          state = const AsyncValue.data(null);
        }
      },
      onError: (error, stackTrace) {
        state = AsyncValue.error(error, stackTrace);
      },
    );
  }

  void stopListening() {
    _roomSubscription?.cancel();
    state = const AsyncValue.data(null);
  }
}

final roomSearchControllerProvider =
    NotifierProvider<RoomSearchController, AsyncValue<List<Room>>>(() {
  return RoomSearchController();
});

class RoomSearchController extends Notifier<AsyncValue<List<Room>>> {
  String _searchQuery = '';
  String? _categoryFilter;
  RoomType? _typeFilter;

  @override
  AsyncValue<List<Room>> build() {
    return const AsyncValue.loading();
  }

  Future<void> searchRooms(String query) async {
    _searchQuery = query;
    await _performSearch();
  }

  void filterByCategory(String? category) {
    _categoryFilter = category;
    _performSearch();
  }

  void filterByType(RoomType? type) {
    _typeFilter = type;
    _performSearch();
  }

  void clearFilters() {
    _searchQuery = '';
    _categoryFilter = null;
    _typeFilter = null;
    _performSearch();
  }

  Future<void> _performSearch() async {
    state = const AsyncValue.loading();
    try {
      final rooms = await ref.read(roomsProvider.future);

      var filteredRooms = rooms.where((room) => room.isActive).toList();

      if (_searchQuery.isNotEmpty) {
        filteredRooms = filteredRooms.where((room) {
          return (room.name ?? room.title)
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              room.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              room.tags.any((tag) =>
                  tag.toLowerCase().contains(_searchQuery.toLowerCase()));
        }).toList();
      }

      if (_categoryFilter != null) {
        filteredRooms = filteredRooms
            .where((room) => room.category == _categoryFilter)
            .toList();
      }

      if (_typeFilter != null) {
        filteredRooms = filteredRooms
            .where((room) => room.roomType == _typeFilter)
            .toList();
      }

      state = AsyncValue.data(filteredRooms);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

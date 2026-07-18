import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/room_model.dart';
import '../../services/room_service.dart';

/// Emergency polling provider for real-time Firestore listeners
/// 
/// This provider replaces WebSocket/long-polling with simple HTTP polling
/// when real-time listeners fail (e.g., due to browser extensions blocking WebSocket).
/// 
/// Usage: Replace `userDocStreamProvider` with `userDocPollingProvider` in providers
/// that are failing. This will poll every 5 seconds instead of using real-time listeners.

/// Poll the user document every 5 seconds (HTTP REST API, not WebSocket)
final userDocPollingProvider = StreamProvider.autoDispose.family<
    DocumentSnapshot<Map<String, dynamic>>?, String>((ref, userId) {
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) {
    return Stream<DocumentSnapshot<Map<String, dynamic>>?>.value(null);
  }

  // Use HTTP polling instead of WebSocket real-time listeners
  return Stream.periodic(
    const Duration(seconds: 5), // Poll every 5 seconds
    (_) => null,
  ).asyncExpand((_) async* {
    try {
      final firestore = FirebaseFirestore.instance;
      final docSnapshot = await firestore
          .collection('users')
          .doc(normalizedUserId)
          .get(const GetOptions(source: Source.server)); // Force fresh from server
      
      yield docSnapshot;
    } catch (e) {
      debugPrint('[Polling] Error fetching user doc: $e');
      yield null; // On error, yield null to show cached value
    }
  });
});

/// Poll all live rooms every 5 seconds (HTTP REST API, not WebSocket)
///
/// Discovery/visibility reads are owned by [RoomService] (FSL-007); this
/// provider only decides the polling cadence.
final liveRoomsPollingProvider = StreamProvider.autoDispose<List<RoomModel>?>((
  ref,
) {
  final roomService = ref.watch(roomServiceProvider);
  return Stream.periodic(
    const Duration(seconds: 5),
    (_) => null,
  ).asyncExpand((_) async* {
    try {
      yield await roomService.fetchLiveRoomsOnce(limit: 50);
    } catch (e) {
      debugPrint('[Polling] Error fetching live rooms: $e');
      yield []; // Return empty list on error
    }
  });
});

/// Poll room details every 3 seconds (HTTP REST API, not WebSocket)
final roomDetailPollingProvider = StreamProvider.autoDispose.family<
    DocumentSnapshot<Map<String, dynamic>>?, String>((ref, roomId) {
  if (roomId.isEmpty) {
    return Stream<DocumentSnapshot<Map<String, dynamic>>?>.value(null);
  }

  return Stream.periodic(
    const Duration(seconds: 3),
    (_) => null,
  ).asyncExpand((_) async* {
    try {
      final firestore = FirebaseFirestore.instance;
      final docSnapshot = await firestore
          .collection('rooms')
          .doc(roomId)
          .get(const GetOptions(source: Source.server)); // Force fresh from server
      
      yield docSnapshot;
    } catch (e) {
      debugPrint('[Polling] Error fetching room detail: $e');
      yield null;
    }
  });
});

/// Poll room participants every 2 seconds (HTTP REST API, not WebSocket)
final roomParticipantsPollingProvider = StreamProvider.autoDispose.family<
    List<QueryDocumentSnapshot<Map<String, dynamic>>>, String>((ref, roomId) {
  if (roomId.isEmpty) {
    return Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.value([]);
  }

  return Stream.periodic(
    const Duration(seconds: 2),
    (_) => null,
  ).asyncExpand((_) async* {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('rooms')
          .doc(roomId)
          .collection('participants')
          .get(const GetOptions(source: Source.server)); // Force fresh from server
      
      yield snapshot.docs;
    } catch (e) {
      debugPrint('[Polling] Error fetching room participants: $e');
      yield []; // Return empty list on error
    }
  });
});

/// Emergency mode flag: set this to true to enable polling instead of real-time listeners
/// 
/// Usage:
/// ```dart
/// // In main.dart or app.dart, after Firebase initialization:
/// if (kDebugMode) {
///   debugPrint('[Emergency] Enabling polling mode due to WebSocket failures');
/// }
/// // Then use pollingProviders instead of real-time providers
/// ```
const bool useEmergencyPollingMode = false; // Set to true to enable

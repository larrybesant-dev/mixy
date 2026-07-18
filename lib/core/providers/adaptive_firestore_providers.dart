import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'emergency_polling_providers.dart';
import 'firebase_providers.dart';
import '../../services/firestore_connection_fallback.dart';

/// Adaptive user doc stream that automatically switches between real-time and polling.
/// 
/// This provider is the recommended replacement for `userDocStreamProvider`.
/// It will automatically use polling mode if WebSocket connections fail due to
/// browser extensions or network filters.
final adaptiveUserDocStreamProvider = StreamProvider.autoDispose
    .family<DocumentSnapshot<Map<String, dynamic>>?, String>((ref, userId) {
  final firestore = ref.watch(firestoreProvider);
  
  // Check if we should use polling mode
  if (FirestoreConnectionFallback.isPollingModeEnabled) {
    if (kDebugMode) {
      debugPrint('[AdaptiveProvider] Using POLLING mode for user doc: $userId');
    }
    return ref.watch(userDocPollingProvider(userId)).when(
      data: (data) => Stream.value(data),
      loading: () => Stream.value(null),
      error: (error, stack) => Stream.error(error, stack),
    );
  }
  
  // Use real-time listener (default mode)
  if (kDebugMode) {
    debugPrint('[AdaptiveProvider] Using REAL-TIME mode for user doc: $userId');
  }
  
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) {
    return Stream<DocumentSnapshot<Map<String, dynamic>>?>.value(null);
  }

  return firestore
      .collection('users')
      .doc(normalizedUserId)
      .snapshots();
});

/// Adaptive live rooms stream that automatically switches between real-time and polling.
/// 
/// Use this instead of `liveRoomsStreamProvider` when available.
final adaptiveLiveRoomsStreamProvider =
    StreamProvider.autoDispose<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  
  // Check if we should use polling mode
  if (FirestoreConnectionFallback.isPollingModeEnabled) {
    if (kDebugMode) {
      debugPrint('[AdaptiveProvider] Using POLLING mode for live rooms');
    }
    return ref.watch(liveRoomsPollingProvider).whenData((data) => data ?? []);
  }
  
  // Use real-time listener (default mode)
  if (kDebugMode) {
    debugPrint('[AdaptiveProvider] Using REAL-TIME mode for live rooms');
  }
  
  return firestore
      .collection('rooms')
      .where('isLive', isEqualTo: true)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

/// Adaptive room detail stream that automatically switches between real-time and polling.
final adaptiveRoomDetailStreamProvider = StreamProvider.autoDispose
    .family<DocumentSnapshot<Map<String, dynamic>>?, String>((ref, roomId) {
  final firestore = ref.watch(firestoreProvider);
  
  if (roomId.isEmpty) {
    return Stream<DocumentSnapshot<Map<String, dynamic>>?>.value(null);
  }
  
  // Check if we should use polling mode
  if (FirestoreConnectionFallback.isPollingModeEnabled) {
    if (kDebugMode) {
      debugPrint('[AdaptiveProvider] Using POLLING mode for room detail: $roomId');
    }
    return ref.watch(roomDetailPollingProvider(roomId)).when(
      data: (data) => Stream.value(data),
      loading: () => Stream.value(null),
      error: (error, stack) => Stream.error(error, stack),
    );
  }
  
  // Use real-time listener (default mode)
  if (kDebugMode) {
    debugPrint('[AdaptiveProvider] Using REAL-TIME mode for room detail: $roomId');
  }
  
  return firestore
      .collection('rooms')
      .doc(roomId)
      .snapshots();
});

/// Adaptive room participants stream that automatically switches between real-time and polling.
final adaptiveRoomParticipantsStreamProvider = StreamProvider.autoDispose
    .family<List<QueryDocumentSnapshot<Map<String, dynamic>>>, String>((ref, roomId) {
  final firestore = ref.watch(firestoreProvider);
  
  if (roomId.isEmpty) {
    return Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.value([]);
  }
  
  // Check if we should use polling mode
  if (FirestoreConnectionFallback.isPollingModeEnabled) {
    if (kDebugMode) {
      debugPrint('[AdaptiveProvider] Using POLLING mode for room participants: $roomId');
    }
    return ref.watch(roomParticipantsPollingProvider(roomId)).when(
      data: (data) => Stream.value(data),
      loading: () => Stream.value([]),
      error: (error, stack) => Stream.value([]),
    );
  }
  
  // Use real-time listener (default mode)
  if (kDebugMode) {
    debugPrint('[AdaptiveProvider] Using REAL-TIME mode for room participants: $roomId');
  }
  
  return firestore
      .collection('rooms')
      .doc(roomId)
      .collection('participants')
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

/// Convenience provider to check current connection mode
final connectionStatusProvider = Provider((ref) {
  return FirestoreConnectionFallback.getStatus();
});

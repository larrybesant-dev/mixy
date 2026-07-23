import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Service to read user data from Realtime Database.
///
/// RTDB is the source of truth for user identity fields like `displayName`.
/// This service provides both one-time reads and real-time streams to bridge
/// RTDB user data into the app's Firestore-centric architecture.
class RtdbUserService {
  final FirebaseDatabase? _rtdb;

  RtdbUserService({required FirebaseDatabase? rtdb}) : _rtdb = rtdb;

  /// Reads displayName from /users/{userId}/displayName (one-time read).
  ///
  /// Returns null if the user ID is empty, RTDB is unavailable, or the field
  /// does not exist.
  Future<String?> getDisplayName(String userId) async {
    final normalizedUserId = userId.trim();
    final rtdb = _rtdb;
    if (normalizedUserId.isEmpty || rtdb == null) return null;
    try {
      final snapshot = await rtdb.ref('users/$normalizedUserId/displayName').get();
      if (snapshot.exists) {
        final value = snapshot.value;
        if (value is String) {
          final trimmed = value.trim();
          return trimmed.isEmpty ? null : trimmed;
        }
      }
    } catch (e) {
      debugPrint('[RTDB] Failed to load displayName for $normalizedUserId: $e');
    }
    return null;
  }

  /// Streams displayName from /users/{userId}/displayName (real-time updates).
  ///
  /// Returns an empty stream if the user ID is empty or RTDB is unavailable.
  /// The stream emits null when the field is absent or empty.
  Stream<String?> watchDisplayName(String userId) {
    final normalizedUserId = userId.trim();
    final rtdb = _rtdb;
    if (normalizedUserId.isEmpty || rtdb == null) {
      return Stream<String?>.value(null);
    }

    try {
      return rtdb
          .ref('users/$normalizedUserId/displayName')
          .onValue
          .map((event) {
            try {
              if (!event.snapshot.exists) return null;
              final value = event.snapshot.value;
              if (value is String) {
                final trimmed = value.trim();
                return trimmed.isEmpty ? null : trimmed;
              }
              return null;
            } catch (e) {
              debugPrint('[RTDB] Error processing displayName snapshot: $e');
              return null;
            }
          })
          .handleError((e) {
            debugPrint('[RTDB] Error watching displayName: $e');
            return null;
          });
    } catch (e) {
      debugPrint('[RTDB] Failed to create displayName watch stream: $e');
      return Stream<String?>.value(null);
    }
  }
}

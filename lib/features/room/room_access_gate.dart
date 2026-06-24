import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/app_logger.dart';

/// Room access states
enum RoomAccessState {
  loading,
  authenticated, // User is logged in with complete profile
  unauthenticated, // User not logged in
  profileIncomplete, // User logged in but profile incomplete
  noPermission, // User authenticated but no access to this room
  allowed, // User can access the room
  error, // Error checking access
}

/// Exception for room access denial
class RoomAccessDeniedException implements Exception {
  final RoomAccessState state;
  final String message;

  RoomAccessDeniedException({
    required this.state,
    required this.message,
  });

  @override
  String toString() => message;
}

/// Checks if user can access a specific room
/// Enforces: auth â†’ profile â†’ room permissions
Future<bool> canAccessRoom({
  required String roomId,
  required String userId,
}) async {
  try {
    // Check auth status
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw RoomAccessDeniedException(
        state: RoomAccessState.unauthenticated,
        message: 'You must be authenticated to access this room',
      );
    }

    // Check profile completion
    final profileDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (!profileDoc.exists) {
      throw RoomAccessDeniedException(
        state: RoomAccessState.profileIncomplete,
        message: 'Please complete your profile to access rooms',
      );
    }

    final profileData = profileDoc.data() ?? {};
    final hasProfile = profileData.containsKey('displayName') &&
        (profileData['displayName'] as String?)?.isNotEmpty == true;

    if (!hasProfile) {
      throw RoomAccessDeniedException(
        state: RoomAccessState.profileIncomplete,
        message: 'Please complete your profile to access rooms',
      );
    }

    // TODO: Check room permissions if needed
    // For now, all authenticated users with profiles can access any room

    return true;
  } on RoomAccessDeniedException {
    rethrow;
  } catch (e) {
    AppLogger.error('Error checking room access: $e');
    throw RoomAccessDeniedException(
      state: RoomAccessState.error,
      message: 'Error checking room access: $e',
    );
  }
}

/// Gets the access state for a room
/// Does NOT throw - returns state as AsyncValue
Future<RoomAccessState> getRoomAccessState({
  required String roomId,
  required String userId,
}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return RoomAccessState.unauthenticated;
    }

    if (!user.emailVerified) {
      return RoomAccessState.unauthenticated;
    }

    // Check profile
    final profileDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (!profileDoc.exists) {
      return RoomAccessState.profileIncomplete;
    }

    final profileData = profileDoc.data() ?? {};
    final hasProfile = profileData.containsKey('displayName') &&
        (profileData['displayName'] as String?)?.isNotEmpty == true;

    if (!hasProfile) {
      return RoomAccessState.profileIncomplete;
    }

    // Access allowed
    return RoomAccessState.allowed;
  } catch (e) {
    AppLogger.error('Error getting room access state: $e');
    return RoomAccessState.error;
  }
}

/// Riverpod provider for room access state
final roomAccessStateProvider =
    FutureProvider.family<RoomAccessState, ({String roomId, String userId})>(
        (ref, params) async {
  return getRoomAccessState(
    roomId: params.roomId,
    userId: params.userId,
  );
});

/// Riverpod provider to check room access (throws on denial)
final roomAccessCheckProvider =
    FutureProvider.family<bool, ({String roomId, String userId})>(
        (ref, params) async {
  return canAccessRoom(
    roomId: params.roomId,
    userId: params.userId,
  );
});

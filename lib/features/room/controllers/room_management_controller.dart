import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/services/room_management_gateway.dart';

/// Permission check for room management operations
class RoomPermissions {
  final String currentUserId;
  final RoomModel room;

  RoomPermissions({
    required this.currentUserId,
    required this.room,
  });

  /// Check if user is the room owner
  bool get isOwner => currentUserId == room.ownerId;

  /// Check if user is an admin of the room
  bool get isAdmin => room.adminUserIds.contains(currentUserId);

  /// Check if user has any management permissions (owner or admin)
  bool get canManage => isOwner || isAdmin;

  /// Check if user can manage admins (owner only)
  bool get canManageAdmins => isOwner;

  /// Check if user can upload/manage room photos (owner or admin)
  bool get canManagePhotos => canManage;

  /// Check if user can edit room settings (owner or admin)
  bool get canEditSettings => canManage;

  /// Check if user can remove members (owner or admin)
  bool get canRemoveMembers => canManage;

  /// Check if user can lock/unlock room (owner or admin)
  bool get canManageLocking => canManage;
}

/// State for room management operations
class RoomManagementState {
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const RoomManagementState({
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  RoomManagementState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return RoomManagementState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

/// Controller for room management operations (admin/owner actions)
class RoomManagementController extends Notifier<RoomManagementState> {
  late final RoomManagementGateway _roomGateway;
  late final FirebaseAuth _auth;

  @override
  RoomManagementState build() {
    _roomGateway = ref.read(roomManagementGatewayProvider);
    _auth = ref.read(firebaseAuthProvider);
    return const RoomManagementState();
  }

  /// Add a user as an admin for the room
  /// Only the room owner can perform this action
  Future<void> addAdmin({
    required String roomId,
    required String adminUserId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      state = state.copyWith(error: 'User not authenticated');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get current room to check permissions
      final room = await _roomGateway.getRoomModel(roomId);
      if (room == null) {
        state = state.copyWith(error: 'Room not found');
        return;
      }
      final permissions = RoomPermissions(
        currentUserId: currentUser.uid,
        room: room,
      );

      if (!permissions.canManageAdmins) {
        state = state.copyWith(error: 'Only room owner can manage admins');
        return;
      }

      if (room.adminUserIds.contains(adminUserId)) {
        state = state.copyWith(error: 'User is already an admin');
        return;
      }

      // Add admin
      await _roomGateway.updateRoom(roomId, {
        'adminUserIds': FieldValue.arrayUnion([adminUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Admin added successfully',
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to add admin: ${e.toString()}');
    }
  }

  /// Remove a user as an admin from the room
  /// Only the room owner can perform this action
  Future<void> removeAdmin({
    required String roomId,
    required String adminUserId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      state = state.copyWith(error: 'User not authenticated');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get current room to check permissions
      final room = await _roomGateway.getRoomModel(roomId);
      if (room == null) {
        state = state.copyWith(error: 'Room not found');
        return;
      }
      final permissions = RoomPermissions(
        currentUserId: currentUser.uid,
        room: room,
      );

      if (!permissions.canManageAdmins) {
        state = state.copyWith(error: 'Only room owner can manage admins');
        return;
      }

      if (!room.adminUserIds.contains(adminUserId)) {
        state = state.copyWith(error: 'User is not an admin');
        return;
      }

      // Remove admin
      await _roomGateway.updateRoom(roomId, {
        'adminUserIds': FieldValue.arrayRemove([adminUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Admin removed successfully',
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to remove admin: ${e.toString()}');
    }
  }

  /// Upload a photo to the room's photo gallery
  /// Owner and admins can upload photos
  Future<void> addRoomPhoto({
    required String roomId,
    required String photoUrl,
    String? caption,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      state = state.copyWith(error: 'User not authenticated');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get current room to check permissions
      final room = await _roomGateway.getRoomModel(roomId);
      if (room == null) {
        state = state.copyWith(error: 'Room not found');
        return;
      }
      final permissions = RoomPermissions(
        currentUserId: currentUser.uid,
        room: room,
      );

      if (!permissions.canManagePhotos) {
        state = state.copyWith(error: 'You do not have permission to upload photos');
        return;
      }

      // Add photo to room's photos subcollection
      await _roomGateway.addRoomPhoto(
        roomId: roomId,
        photoUrl: photoUrl,
        caption: caption,
        uploadedBy: currentUser.uid,
      );

      // Update room's photo count
      await _roomGateway.updateRoom(roomId, {
        'photoCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Photo uploaded successfully',
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to upload photo: ${e.toString()}');
    }
  }

  /// Remove a photo from the room's gallery
  /// Owner and admins can remove photos
  Future<void> removeRoomPhoto({
    required String roomId,
    required String photoId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      state = state.copyWith(error: 'User not authenticated');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get current room to check permissions
      final room = await _roomGateway.getRoomModel(roomId);
      if (room == null) {
        state = state.copyWith(error: 'Room not found');
        return;
      }
      final permissions = RoomPermissions(
        currentUserId: currentUser.uid,
        room: room,
      );

      if (!permissions.canManagePhotos) {
        state = state.copyWith(error: 'You do not have permission to remove photos');
        return;
      }

      // Remove photo from subcollection
      await _roomGateway.removeRoomPhoto(roomId: roomId, photoId: photoId);

      // Decrement photo count
      await _roomGateway.updateRoom(roomId, {
        'photoCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Photo removed successfully',
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to remove photo: ${e.toString()}');
    }
  }

  /// Update room settings (name, description, rules, etc.)
  /// Owner and admins can update settings
  Future<void> updateRoomSettings({
    required String roomId,
    String? name,
    String? description,
    String? rules,
    bool? isLocked,
    bool? isAdult,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      state = state.copyWith(error: 'User not authenticated');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get current room to check permissions
      final room = await _roomGateway.getRoomModel(roomId);
      if (room == null) {
        state = state.copyWith(error: 'Room not found');
        return;
      }
      final permissions = RoomPermissions(
        currentUserId: currentUser.uid,
        room: room,
      );

      if (!permissions.canEditSettings) {
        state = state.copyWith(error: 'You do not have permission to edit room settings');
        return;
      }

      // Build update map with only provided values
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (rules != null) updates['rules'] = rules;
      if (isLocked != null) updates['isLocked'] = isLocked;
      if (isAdult != null) updates['isAdult'] = isAdult;

      await _roomGateway.updateRoom(roomId, updates);

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Room settings updated successfully',
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to update settings: ${e.toString()}');
    }
  }

  /// Remove a member from the room
  /// Owner and admins can remove members
  Future<void> removeMember({
    required String roomId,
    required String userId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      state = state.copyWith(error: 'User not authenticated');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get current room to check permissions
      final room = await _roomGateway.getRoomModel(roomId);
      if (room == null) {
        state = state.copyWith(error: 'Room not found');
        return;
      }
      final permissions = RoomPermissions(
        currentUserId: currentUser.uid,
        room: room,
      );

      if (!permissions.canRemoveMembers) {
        state = state.copyWith(error: 'You do not have permission to remove members');
        return;
      }

      // Remove from stage and audience
      await _roomGateway.updateRoom(roomId, {
        'stageUserIds': FieldValue.arrayRemove([userId]),
        'audienceUserIds': FieldValue.arrayRemove([userId]),
        'memberCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Delete participant doc
      await _roomGateway.removeParticipant(roomId: roomId, userId: userId);

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Member removed successfully',
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to remove member: ${e.toString()}');
    }
  }
}

/// Riverpod provider for room management controller
final roomManagementProvider =
    NotifierProvider<RoomManagementController, RoomManagementState>(
  () => RoomManagementController(),
);

/// Provider to check permissions for a specific room
final roomPermissionsProvider = FutureProvider.family<RoomPermissions, String>(
  (ref, roomId) async {
    final roomGateway = ref.watch(roomManagementGatewayProvider);
    final auth = ref.watch(firebaseAuthProvider);
    
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final room = await roomGateway.getRoomModel(roomId);
    if (room == null) {
      throw Exception('Room not found');
    }
    return RoomPermissions(
      currentUserId: currentUser.uid,
      room: room,
    );
  },
);

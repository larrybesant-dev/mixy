import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/shared/models/room.dart';
import 'category_service.dart';

/// Service for managing rooms in Firestore.
class RoomService {
  final FirebaseFirestore _firestore;
  final CategoryService _categoryService;

  static const String _collectionName = 'rooms';

  RoomService({
    FirebaseFirestore? firestore,
    CategoryService? categoryService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _categoryService = categoryService ?? CategoryService();

  /// Creates a new room in Firestore.
  ///
  /// Automatically computes the category from tags.
  Future<Room> createRoom(Room room) async {
    // Normalize tags
    final normalizedTags = _categoryService.normalizeTags(room.tags);

    // Validate tags
    final validationError = _categoryService.validateTags(normalizedTags);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    // Compute category from tags
    final category = _categoryService.classifyRoom(normalizedTags);

    // Create room with computed category
    final roomWithCategory = room.copyWith(
      tags: normalizedTags,
      category: category,
    );

    // Save to Firestore
    final docRef = await _firestore
        .collection(_collectionName)
        .add(roomWithCategory.toFirestore());

    // Return room with Firestore-generated ID
    return roomWithCategory.copyWith(id: docRef.id);
  }

  /// Updates an existing room in Firestore.
  ///
  /// Recomputes category if tags have changed.
  Future<void> updateRoom(Room room) async {
    if (room.id.isEmpty) {
      throw ArgumentError('Room ID cannot be empty');
    }

    // Normalize tags
    final normalizedTags = _categoryService.normalizeTags(room.tags);

    // Validate tags
    final validationError = _categoryService.validateTags(normalizedTags);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    // Recompute category from tags
    final category = _categoryService.classifyRoom(normalizedTags);

    // Update room with new category
    final updatedRoom = room.copyWith(
      tags: normalizedTags,
      category: category,
    );

    await _firestore
        .collection(_collectionName)
        .doc(room.id)
        .update(updatedRoom.toFirestore());
  }

  /// Fetches a single room by ID.
  Future<Room?> fetchRoomById(String roomId) async {
    final doc = await _firestore.collection(_collectionName).doc(roomId).get();

    if (!doc.exists) {
      return null;
    }

    return Room.fromFirestore(doc);
  }

  /// Fetches rooms by category as a stream.
  Stream<List<Room>> fetchRoomsByCategory(String category) {
    if (!_categoryService.isValidCategory(category)) {
      throw ArgumentError('Invalid category: $category');
    }

    return _firestore
        .collection(_collectionName)
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Room.fromFirestore(doc)).toList();
    });
  }

  /// Fetches all rooms as a stream.
  Stream<List<Room>> fetchAllRooms() {
    return _firestore
        .collection(_collectionName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Room.fromFirestore(doc)).toList();
    });
  }

  /// Fetches live rooms as a stream (all active rooms).
  Stream<List<Room>> fetchLiveRooms() {
    return _firestore
        .collection(_collectionName)
        .orderBy('viewerCount', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Room.fromFirestore(doc)).toList();
    });
  }

  /// Fetches rooms by host ID as a stream.
  Stream<List<Room>> fetchRoomsByHost(String hostId) {
    return _firestore
        .collection(_collectionName)
        .where('hostId', isEqualTo: hostId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Room.fromFirestore(doc)).toList();
    });
  }

  /// Deletes a room by ID (only room host/moderators can delete).
  /// [roomId] - The room to delete
  /// [currentUserId] - The user attempting to delete (for authorization check)
  Future<void> deleteRoom(String roomId, String currentUserId) async {
    if (roomId.isEmpty) {
      throw ArgumentError('Room ID cannot be empty');
    }
    if (currentUserId.isEmpty) {
      throw ArgumentError('Current user ID cannot be empty');
    }

    // Get room to verify authorization
    final roomDoc =
        await _firestore.collection(_collectionName).doc(roomId).get();
    if (!roomDoc.exists) {
      throw Exception('Room not found');
    }

    final room = Room.fromFirestore(roomDoc);

    // Check if user is host or moderator
    final isAuthorized =
        room.hostId == currentUserId || room.moderators.contains(currentUserId);
    if (!isAuthorized) {
      throw Exception('Only room host or moderators can delete rooms');
    }

    await _firestore.collection(_collectionName).doc(roomId).delete();
  }

  /// Updates the live status of a room.
  Future<void> updateLiveStatus(String roomId, bool isLive) async {
    if (roomId.isEmpty) {
      throw ArgumentError('Room ID cannot be empty');
    }

    await _firestore.collection(_collectionName).doc(roomId).update({
      'isLive': isLive,
    });
  }

  /// Updates the viewer count of a room.
  Future<void> updateViewerCount(String roomId, int viewerCount) async {
    if (roomId.isEmpty) {
      throw ArgumentError('Room ID cannot be empty');
    }

    if (viewerCount < 0) {
      throw ArgumentError('Viewer count cannot be negative');
    }

    await _firestore.collection(_collectionName).doc(roomId).update({
      'viewerCount': viewerCount,
    });
  }

  /// Increments the viewer count atomically.
  Future<void> incrementViewerCount(String roomId) async {
    if (roomId.isEmpty) {
      throw ArgumentError('Room ID cannot be empty');
    }

    await _firestore.collection(_collectionName).doc(roomId).update({
      'viewerCount': FieldValue.increment(1),
    });
  }

  /// Decrements the viewer count atomically.
  Future<void> decrementViewerCount(String roomId) async {
    if (roomId.isEmpty) {
      throw ArgumentError('Room ID cannot be empty');
    }

    await _firestore.collection(_collectionName).doc(roomId).update({
      'viewerCount': FieldValue.increment(-1),
    });
  }

  /// Searches rooms by tags.
  Stream<List<Room>> searchRoomsByTags(List<String> tags) {
    if (tags.isEmpty) {
      return fetchAllRooms();
    }

    final normalizedTags = _categoryService.normalizeTags(tags);

    return _firestore
        .collection(_collectionName)
        .where('tags', arrayContainsAny: normalizedTags)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Room.fromFirestore(doc)).toList();
    });
  }
}


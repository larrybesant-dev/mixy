import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/room_service.dart';
import '../models/room_model.dart';
import 'package:mixvy/shared/models/room.dart' as shared_room;

/// Cache RoomService as a singleton
final roomServiceProvider = Provider<RoomService>((ref) {
  return RoomService();
});

/// Stream rooms and filter by ID via cached service
final roomProvider = StreamProvider.family<Room?, String>((ref, roomId) {
  final roomService = ref.watch(roomServiceProvider);
  return roomService.streamRooms().map((rooms) {
    try {
      return rooms.firstWhere((room) => room.id == roomId);
    } catch (e) {
      return null;
    }
  });
});

/// 🔴 FIX #1: Real-time room updates via direct Firestore stream
/// Streams a single room document with all real-time changes
/// This replaces FutureBuilder pattern to enable live member counts, status updates, etc.
final roomStreamProvider = StreamProvider.family<shared_room.Room?, String>((ref, roomId) {
  return FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists) {
          return null;
        }
        return shared_room.Room.fromFirestore(snapshot);
      });
});

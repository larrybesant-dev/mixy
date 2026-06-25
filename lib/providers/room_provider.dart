import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';
import '../services/room_service.dart';
import '../models/room_model.dart';

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

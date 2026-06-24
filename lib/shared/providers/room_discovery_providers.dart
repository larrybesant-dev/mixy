// lib/providers/room_discovery_providers.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/room/room_discovery_service.dart';
import '../models/room.dart';

final roomDiscoveryServiceProvider =
    Provider<RoomDiscoveryService>((ref) => RoomDiscoveryService());

final trendingRoomsProvider =
    FutureProvider<List<Room>>((ref) async {
  final service = ref.read(roomDiscoveryServiceProvider);
  final docs = await service.getTrendingRooms();
  return docs.map((doc) => Room.fromFirestore(doc)).toList();
});

final activeRoomsProvider = FutureProvider<List<DocumentSnapshot>>((ref) async {
  final service = ref.read(roomDiscoveryServiceProvider);
  return service.getRoomsByCategory('active');
});

/// Provider for newly created rooms
final newRoomsProvider = FutureProvider.autoDispose<List<Room>>((ref) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection('rooms')
        .where('isLive', isEqualTo: true)
        .where('isHidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Room.fromMap(data);
        })
        .toList();
  } catch (e) {
    return [];
  }
});

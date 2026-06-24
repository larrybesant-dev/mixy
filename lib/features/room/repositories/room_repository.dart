// lib/features/room/repositories/room_repository.dart
//
// Firestore implementation of IRoomRepository.
// UID validation is enforced before every write here — never in the UI.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/models/room.dart';
import 'i_room_repository.dart';

class RoomRepository implements IRoomRepository {
  final FirebaseFirestore _db;

  RoomRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');

  @override
  Future<Room?> getRoom(String roomId) async {
    final doc = await _rooms.doc(roomId).get();
    if (!doc.exists) return null;
    return Room.fromMap(doc.data()!, doc.id);
  }

  @override
  Stream<Room?> watchRoom(String roomId) {
    return _rooms.doc(roomId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Room.fromMap(doc.data()!, doc.id);
    });
  }

  @override
  Stream<List<Room>> watchLiveRooms({int limit = 50}) {
    return _rooms
        .where('status', isEqualTo: 'live')
        .orderBy('participantCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => Room.fromMap(d.data(), d.id)).toList());
  }

  @override
  Future<String> createRoom({
    required String hostUid,
    required Map<String, dynamic> roomData,
  }) async {
    _assertUid(hostUid);
    final doc = await _rooms.add({
      ...roomData,
      'hostUid': hostUid,
      'status': 'live',
      'participantCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  @override
  Future<void> updateRoom({
    required String roomId,
    required String requestingUid,
    required Map<String, dynamic> fields,
  }) async {
    _assertUid(requestingUid);
    await _assertRoomHost(roomId, requestingUid);
    return _rooms.doc(roomId).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> closeRoom({
    required String roomId,
    required String requestingUid,
  }) async {
    _assertUid(requestingUid);
    await _assertRoomHost(roomId, requestingUid);
    return _rooms.doc(roomId).update({
      'status': 'closed',
      'closedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> joinRoom({
    required String roomId,
    required String uid,
    required Map<String, dynamic> participantData,
  }) async {
    _assertUid(uid);
    await _rooms.doc(roomId).collection('participants').doc(uid).set({
      ...participantData,
      'uid': uid,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await _rooms
        .doc(roomId)
        .update({'participantCount': FieldValue.increment(1)});
  }

  @override
  Future<void> leaveRoom({required String roomId, required String uid}) async {
    _assertUid(uid);
    await _rooms.doc(roomId).collection('participants').doc(uid).delete();
    await _rooms
        .doc(roomId)
        .update({'participantCount': FieldValue.increment(-1)});
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------
  void _assertUid(String uid) {
    if (uid.trim().isEmpty) throw ArgumentError('UID must not be empty');
  }

  Future<void> _assertRoomHost(String roomId, String uid) async {
    final doc = await _rooms.doc(roomId).get();
    if (!doc.exists) throw Exception('Room $roomId not found');
    final hostUid = doc.data()?['hostUid'] as String?;
    if (hostUid != uid) throw Exception('Permission denied: not room host');
  }
}

final roomRepositoryProvider = Provider<IRoomRepository>(
  (ref) => RoomRepository(),
);


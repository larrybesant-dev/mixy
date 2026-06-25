import 'package:cloud_firestore/cloud_firestore.dart';

class HostControlsRepository {
  final FirebaseFirestore _db;
  HostControlsRepository(this._db);

  Future<void> toggleRoomLock(String roomId, bool value) async {
    await _db.collection('rooms').doc(roomId).update({'isLocked': value});
  }

  Future<void> setSlowMode(String roomId, int seconds) async {
    await _db.collection('rooms').doc(roomId).update({
      'slowModeSeconds': seconds,
    });
  }

  Future<void> muteUser(String roomId, String userId) async {
    await _db.collection('rooms').doc(roomId).update({
      'mutedUsers': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> unmuteUser(String roomId, String userId) async {
    await _db.collection('rooms').doc(roomId).update({
      'mutedUsers': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> banUser(String roomId, String userId) async {
    await _db.collection('rooms').doc(roomId).update({
      'bannedUsers': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> unbanUser(String roomId, String userId) async {
    await _db.collection('rooms').doc(roomId).update({
      'bannedUsers': FieldValue.arrayRemove([userId]),
    });
  }
}





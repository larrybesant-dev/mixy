import 'package:firebase_database/firebase_database.dart';

class PresenceService {
  final _db = FirebaseDatabase.instance.ref();

  Future<void> setOnline(String userId) async {
    await _db.child('status').child(userId).set({'online': true, 'lastSeen': DateTime.now().toIso8601String()});
  }

  Future<void> setOffline(String userId) async {
    await _db.child('status').child(userId).set({'online': false, 'lastSeen': DateTime.now().toIso8601String()});
  }

  Stream<bool> streamPresence(String userId) {
    return _db.child('status').child(userId).onValue.map((event) {
      final data = event.snapshot.value as Map?;
      return data?['online'] ?? false;
    });
  }
}

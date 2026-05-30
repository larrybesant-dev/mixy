import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/query_policy.dart';

class TypingRepository {
  final FirebaseFirestore _db;
  TypingRepository(this._db);

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return fallback;
  }

  Stream<Map<String, bool>> typingStream(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('typing')
        .limit(QueryPolicy.typingUsersLimit)
        .snapshots()
        .map(
          (snap) => {
            for (var doc in snap.docs) doc.id: _asBool(doc.data()['typing']),
          },
        );
  }

  Future<void> setTyping(String roomId, String userId, bool typing) async {
    await _db
        .collection('rooms')
        .doc(roomId)
        .collection('typing')
        .doc(userId)
        .set({'typing': typing, 'timestamp': FieldValue.serverTimestamp()});
  }
}





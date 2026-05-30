import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/reaction_model.dart';
import '../../../core/constants/query_policy.dart';

class ReactionRepository {
  final FirebaseFirestore _db;
  ReactionRepository(this._db);

  Stream<List<ReactionModel>> reactionsStream(String roomId, String messageId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .limit(QueryPolicy.messageReactionsLimit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => ReactionModel.fromJson(d.data())).toList(),
        );
  }

  Future<void> setReaction(
    String roomId,
    String messageId,
    String userId,
    String emoji,
  ) async {
    await _db
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .doc(userId)
        .set({
          'userId': userId,
          'emoji': emoji,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  Future<void> removeReaction(
    String roomId,
    String messageId,
    String userId,
  ) async {
    await _db
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .doc(userId)
        .delete();
  }
}





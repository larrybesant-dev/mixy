import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/firebase_providers.dart';

final messagingPresenceGatewayProvider = Provider<MessagingPresenceGateway>((ref) {
  return MessagingPresenceGateway(ref.watch(firestoreProvider));
});

class MessagingPresenceGateway {
  MessagingPresenceGateway(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> userRef(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  DocumentReference<Map<String, dynamic>> conversationRef(String conversationId) {
    return _firestore.collection('conversations').doc(conversationId);
  }

  DocumentReference<Map<String, dynamic>> messageRef(
    String conversationId,
    String messageId,
  ) {
    return conversationRef(conversationId).collection('messages').doc(messageId);
  }

  Future<void> updateUserPresence(
    String userId,
    Map<String, dynamic> updates,
  ) {
    return userRef(userId).update(updates);
  }

  Future<void> setUserPresenceMerge(
    String userId,
    Map<String, dynamic> data,
  ) {
    return userRef(userId).set(data, SetOptions(merge: true));
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String userId) {
    return userRef(userId).get();
  }

  Future<void> updateMessage(
    String conversationId,
    String messageId,
    Map<String, dynamic> updates,
  ) {
    return messageRef(conversationId, messageId).update(updates);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getMessagesFromOthers(
    String conversationId,
    String userId,
  ) {
    return conversationRef(conversationId)
        .collection('messages')
        .where('senderId', isNotEqualTo: userId)
        .get();
  }

  Future<void> updateConversation(
    String conversationId,
    Map<String, dynamic> updates,
  ) {
    return conversationRef(conversationId).update(updates);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getConversation(
    String conversationId,
  ) {
    return conversationRef(conversationId).get();
  }
}

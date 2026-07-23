import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/firebase_providers.dart';

final groupsGatewayProvider = Provider<GroupsGateway>((ref) {
  return GroupsGateway(ref.watch(firestoreProvider));
});

class GroupsGateway {
  GroupsGateway(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> groupsCollection() {
    return _firestore.collection('groups');
  }

  DocumentReference<Map<String, dynamic>> groupRef(String groupId) {
    return groupsCollection().doc(groupId);
  }

  CollectionReference<Map<String, dynamic>> groupPostsCollection(String groupId) {
    return groupRef(groupId).collection('posts');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> groupsStream() {
    return groupsCollection()
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> groupDetailsStream(String groupId) {
    return groupRef(groupId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> userGroupsStream(String userId) {
    return groupsCollection()
        .where('memberIds', arrayContains: userId)
        .limit(100)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> groupPostsStream(String groupId) {
    return groupPostsCollection(groupId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> createGroup({
    required String userId,
    required String name,
    required String description,
  }) {
    return groupsCollection().add({
      'name': name,
      'description': description,
      'creatorId': userId,
      'adminId': userId,
      'memberIds': [userId],
      'memberCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> joinGroup({
    required String groupId,
    required String userId,
  }) {
    return groupRef(groupId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
      'memberCount': FieldValue.increment(1),
    });
  }

  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) {
    return groupRef(groupId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'memberCount': FieldValue.increment(-1),
    });
  }

  Future<void> postToGroup({
    required String groupId,
    required String userId,
    required String username,
    required String? avatarUrl,
    required String content,
    required List<String> tags,
  }) {
    return groupPostsCollection(groupId).add({
      'groupId': groupId,
      'authorId': userId,
      'authorName': username,
      'authorAvatarUrl': avatarUrl,
      'content': content,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': 0,
      'likedBy': <String>[],
    });
  }

  Future<void> deleteGroup({required String groupId}) {
    return groupRef(groupId).delete();
  }
}

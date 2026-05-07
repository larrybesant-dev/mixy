import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import '../models/group_model.dart';

// Get all groups
final groupsProvider = StreamProvider<List<Group>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('groups')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Group.fromJson(doc.data(), doc.id))
            .toList(),
      );
});

// Get single group details
final groupDetailsProvider = StreamProvider.autoDispose.family<Group?, String>((
  ref,
  groupId,
) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('groups')
      .doc(groupId) // Single-document read — .limit(1) not applicable here.
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists) return null;
        final data = snapshot.data();
        if (data == null) return null;
        return Group.fromJson(data, snapshot.id);
      });
});

// Get user's groups
final userGroupsProvider = StreamProvider.autoDispose
    .family<List<Group>, String>((ref, userId) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .collection('groups')
          .where('memberIds', arrayContains: userId)
          .limit(100)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => Group.fromJson(doc.data(), doc.id))
                .toList(),
          );
    });

// Get posts in a group
final groupPostsProvider = StreamProvider.autoDispose
    .family<List<GroupPost>, String>((ref, groupId) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .collection('groups')
          .doc(groupId)
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => GroupPost.fromJson(doc.data(), doc.id))
                .toList(),
          );
    });

// Groups controller
class GroupsController {
  final FirebaseFirestore _firestore;

  GroupsController({required FirebaseFirestore firestore})
    : _firestore = firestore;

  Future<void> createGroup({
    required String userId,
    required String name,
    required String description,
  }) async {
    await _firestore.collection('groups').add({
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
  }) async {
    await _firestore.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
      'memberCount': FieldValue.increment(1),
    });
  }

  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    await _firestore.collection('groups').doc(groupId).update({
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
  }) async {
    await _firestore.collection('groups').doc(groupId).collection('posts').add({
      'groupId': groupId,
      'authorId': userId,
      'authorName': username,
      'authorAvatarUrl': avatarUrl,
      'content': content,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': 0,
      'likedBy': [],
    });
  }

  Future<void> deleteGroup({required String groupId}) async {
    await _firestore.collection('groups').doc(groupId).delete();
  }
}

final groupsControllerProvider = Provider<GroupsController>((ref) {
  return GroupsController(firestore: ref.watch(firestoreProvider));
});

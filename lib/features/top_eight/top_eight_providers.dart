import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

// Family provider that allows different profile pages to load their specific Top 8 grid dynamically
final topEightDisplayProvider = StreamProvider.family
    .autoDispose<List<UserModel>, String>((ref, targetUserId) {
  if (targetUserId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(targetUserId)
      .collection('top_friends')
      .orderBy('slotIndex')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return UserModel(
        id: doc.id,
        username: data['username'] ?? 'MixVy User',
        email: data['email'] ?? '',
        avatarUrl: data['avatarUrl'] ?? '',
        createdAt: data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
    }).toList();
  });
});

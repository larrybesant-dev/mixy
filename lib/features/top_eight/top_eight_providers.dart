import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/providers/firebase_providers.dart';
import '../../models/user_model.dart';
import '../../services/top_eight_stream_service.dart';

final topEightStreamServiceProvider = Provider<TopEightStreamService>((ref) {
  return TopEightStreamService(firestore: ref.watch(firestoreProvider));
});

// Family provider that allows different profile pages to load their specific Top 8 grid dynamically
final topEightDisplayProvider = StreamProvider.family.autoDispose<List<UserModel>, String>((ref, targetUserId) {
  if (targetUserId.isEmpty) return Stream.value([]);

  final streamService = ref.watch(topEightStreamServiceProvider);

  return streamService
      .watchTopFriends(targetUserId)
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


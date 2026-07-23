import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/firebase_providers.dart';
import '../../models/user_model.dart';
import '../../services/moderation_service.dart';

abstract class PaymentRecipientRepository {
  Future<List<UserModel>> searchRecipients(
    String query, {
    String? currentUserId,
  });
}

class FirestorePaymentRecipientRepository
    implements PaymentRecipientRepository {
  FirestorePaymentRecipientRepository({
    required FirebaseFirestore firestore,
    ModerationService? moderationService,
  }) : _firestore = firestore,
       _moderationService =
           moderationService ?? ModerationService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final ModerationService _moderationService;

  @override
  Future<List<UserModel>> searchRecipients(
    String query, {
    String? currentUserId,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .orderBy('balance', descending: true)
        .limit(25)
        .get();

    final normalizedQuery = query.trim().toLowerCase();
    final blockedIds = currentUserId == null
        ? const <String>{}
        : await _moderationService.getExcludedUserIds(currentUserId);

    return snapshot.docs
        .map((doc) => UserModel.fromJson({'id': doc.id, ...doc.data()}))
        .where((user) => user.id != currentUserId)
        .where((user) => !blockedIds.contains(user.id))
        .where((user) {
          if (normalizedQuery.isEmpty) {
            return true;
          }

          final username = user.username.toLowerCase();
          return username.contains(normalizedQuery);
        })
        .toList(growable: false);
  }
}

final paymentRecipientRepositoryProvider = Provider<PaymentRecipientRepository>(
  (ref) => FirestorePaymentRecipientRepository(
    firestore: ref.read(firestoreProvider),
  ),
);

final currentPaymentUserIdProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

final paymentRecipientSearchProvider =
    FutureProvider.family<List<UserModel>, String>((ref, query) {
      final repository = ref.read(paymentRecipientRepositoryProvider);
      final currentUserId = ref.read(currentPaymentUserIdProvider);
      return repository.searchRecipients(query, currentUserId: currentUserId);
    });





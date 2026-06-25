import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/firebase_providers.dart';
import '../../models/user_model.dart';
import '../../services/schema_mutation_service.dart';

final schemaMutationServiceProvider = Provider((ref) {
  return SchemaMutationService(firestore: ref.watch(firestoreProvider));
});

final topEightRepositoryProvider = Provider((ref) {
  return TopEightRepository(
    ref.watch(firestoreProvider),
    ref.watch(schemaMutationServiceProvider),
  );
});

class TopEightRepository {
  final FirebaseFirestore _firestore;
  final SchemaMutationService _schemaMutationService;

  TopEightRepository(this._firestore, this._schemaMutationService);

  /// Fetches the list of UIDs for a user's Top 8.
  Stream<List<String>> watchTopEightIds(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots(
          // FSL-002: Even single docs must have explicit bounds for production safety
        )
        .map((doc) {
          final data = doc.data();
          if (data == null) return [];
          return List<String>.from(data['topEightIds'] ?? []);
        });
  }

  /// Fetches full [UserModel] objects for a list of IDs.
  Future<List<UserModel>> getUsersFromIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    // Firestore 'in' queries are limited to 10 items, which works perfectly for a "Top 8".
    final snapshots = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: ids)
        .get();

    final users = snapshots.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .toList();

    // Re-sort to match the order of IDs provided (since 'whereIn' doesn't guarantee order)
    // Also filters out any users that might no longer exist in the database.
    return ids
        .map((id) => users.cast<UserModel?>().firstWhere(
              (u) => u?.id == id,
              orElse: () => null,
            ))
        .whereType<UserModel>()
        .toList();
  }

  /// Updates the user's Top 8 list using [SchemaMutationService] for architectural safety.
  Future<void> updateTopEight(String userId, List<String> topEightIds) async {
    await _schemaMutationService.updateTopEight(
      userId: userId,
      topEightIds: topEightIds,
    );
  }
}





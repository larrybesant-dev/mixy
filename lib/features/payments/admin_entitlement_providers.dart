import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/firebase_providers.dart';

final adminEntitlementFirestoreProvider = firestoreProvider;

final entitlementUserDocProvider = Provider.autoDispose
    .family<AsyncValue<Map<String, dynamic>?>, String>((ref, userId) {
      return ref.watch(userDataStreamProvider(userId));
    });

final entitlementEventsProvider = StreamProvider.autoDispose
    .family<List<QueryDocumentSnapshot<Map<String, dynamic>>>, String>((
      ref,
      userId,
    ) {
      return ref
          .watch(adminEntitlementFirestoreProvider)
          .collection('entitlement_events')
          .where('userId', isEqualTo: userId)
          .limit(25)
          .snapshots()
          .map((snap) => snap.docs);
    });

final entitlementLookupProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, rawInput) async {
      final input = rawInput.trim();
      if (input.isEmpty) {
        return null;
      }

      final users = ref
          .watch(adminEntitlementFirestoreProvider)
          .collection('users');

      if (input.contains('@')) {
        final emailMatch = await users
            .where('email', isEqualTo: input)
            .limit(1)
            .get();
        if (emailMatch.docs.isNotEmpty) {
          return emailMatch.docs.first.id;
        }
        return null;
      }

      final exactDoc = await users.doc(input).get();
      if (exactDoc.exists) {
        return exactDoc.id;
      }
      return null;
    });





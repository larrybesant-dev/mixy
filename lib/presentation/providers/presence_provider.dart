import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import '../../models/presence_model.dart';

// final presenceListProvider = StateProvider<List<PresenceModel>>(() => []);
final presenceListProvider = StateProvider<List<PresenceModel>>((ref) => []);

final debugFirestorePresenceWatch = Provider.autoDispose
    .family<Stream<Map<String, dynamic>?>, String>((ref, userId) {
      final uid = userId.trim();
      if (uid.isEmpty) {
        return Stream.value(null);
      }
      return ref
          .watch(firestoreProvider)
          .collection('presence')
          .doc(
            uid,
          ) // Single-document read — .limit(1) not applicable for document snapshots.
          .snapshots()
          .map((doc) => doc.data());
    });

final debugRtdbSessionsWatch = Provider.autoDispose
    .family<Stream<Map<dynamic, dynamic>>, String>((ref, userId) {
      final uid = userId.trim();
      if (uid.isEmpty) {
        return Stream.value(const <dynamic, dynamic>{});
      }

      final databaseUrl = Firebase.app().options.databaseURL?.trim() ?? '';
      if (!databaseUrl.startsWith('https://')) {
        return Stream.value(const <dynamic, dynamic>{});
      }

      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: databaseUrl,
      ).ref('status/$uid/sessions').onValue.map((event) {
        final raw = event.snapshot.value;
        if (raw is Map) {
          return Map<dynamic, dynamic>.from(raw);
        }
        return const <dynamic, dynamic>{};
      });
    });





import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/rtdb_presence_service.dart';

/// Canonical Firebase singleton providers.
///
/// All feature providers and services should read Firebase instances from here
/// rather than calling [FirebaseFirestore.instance] / [FirebaseAuth.instance]
/// directly. This allows tests to inject fakes via [ProviderScope.overrides].
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firebaseDatabaseProvider = Provider<FirebaseDatabase?>(
  (ref) {
    try {
      // RTDB requires a configured databaseURL on web. If absent/invalid,
      // gracefully disable presence instead of triggering runtime exceptions.
      final app = Firebase.app();
      final databaseUrl = app.options.databaseURL?.trim() ?? '';
      if (!databaseUrl.startsWith('https://')) {
        return null;
      }
      return FirebaseDatabase.instanceFor(app: app, databaseURL: databaseUrl);
    } catch (e) {
      return null;
    }
  },
);

final firebaseFunctionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instance,
);

final rtdbPresenceServiceProvider = Provider<RtdbPresenceService>(
  (ref) {
    final db = ref.watch(firebaseDatabaseProvider);
    return RtdbPresenceService(db);
  },
);

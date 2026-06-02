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

/// Canonical per-user Firestore document stream.
///
/// All user-domain feature providers should derive from this provider instead
/// of opening their own `users/{uid}` snapshots streams.
final userDocStreamProvider = StreamProvider.autoDispose
    .family<DocumentSnapshot<Map<String, dynamic>>?, String>((ref, userId) {
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) {
    return Stream<DocumentSnapshot<Map<String, dynamic>>?>.value(null);
  }

  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(normalizedUserId)
      .snapshots();
});

final userDataStreamProvider = Provider.autoDispose
    .family<AsyncValue<Map<String, dynamic>?>, String>((ref, userId) {
  return ref
      .watch(userDocStreamProvider(userId))
      .whenData((doc) => doc?.data());
});

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// Canonical Firebase auth state stream.
///
/// This is the ONLY authStateChanges() listener in the app. All services
/// (auth controller, push messaging, providers) subscribe to this provider
/// rather than opening their own streams. This ensures:
/// - One auth event timeline (no race conditions)
/// - Synchronized auth state across UI, push, and services
/// - Single cancellation path (managed by Riverpod)
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final firebaseDatabaseProvider = Provider<FirebaseDatabase?>((ref) {
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
});

final firebaseFunctionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instance,
);

final rtdbPresenceServiceProvider = Provider<RtdbPresenceService>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return RtdbPresenceService(db);
});

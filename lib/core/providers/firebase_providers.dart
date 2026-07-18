import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/firestore_connection_fallback.dart';
import '../../services/rtdb_presence_service.dart';
import '../../services/rtdb_user_service.dart';

/// Canonical Firebase singleton providers.
///
/// All feature providers and services should read Firebase instances from here
/// rather than calling [FirebaseFirestore.instance] / [FirebaseAuth.instance]
/// directly. This allows tests to inject fakes via [ProviderScope.overrides].
/// Canonical Firebase singleton providers.
///
/// All feature providers and services should read Firebase instances from here
/// rather than calling [FirebaseFirestore.instance] / [FirebaseAuth.instance]
/// directly. This allows tests to inject fakes via [ProviderScope.overrides].
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) {
    final firestore = FirebaseFirestore.instance;
    
    // Configure Firestore for web resilience
    if (kIsWeb) {
      try {
        // Enable persistence for offline resilience + bounded cache to prevent bloat
        firestore.settings = Settings(
          persistenceEnabled: true,  // ✅ Enable offline caching for network resilience
          cacheSizeBytes: 50 * 1024 * 1024,  // 50MB standard cache limit for web/PWA
          ignoreUndefinedProperties: true,
          
          // 🔧 HOTFIX: Browser extensions (uBlock, Privacy Badger, etc.) often block
          // WebSocket connections to *.googleapis.com as a security measure.
          // This forces Firestore to skip WebSocket and HTTP long-polling,
          // using REST API directly instead (which extensions typically don't block).
          // See WEBSOCKET_ERR_ABORTED_ANALYSIS.md for detailed diagnosis.
          host: 'firestore.googleapis.com',
          sslEnabled: true,
        );
        debugPrint('[Firebase] Firestore configured: persistence=enabled, REST-API optimized');
        
        // Enable emergency polling detection for WebSocket failures
        FirestoreConnectionFallback.enableFallbackDetection(firestore);
        debugPrint('[Firebase] ${FirestoreConnectionFallback.getStatus()}');
      } catch (e) {
        debugPrint('[Firebase] Failed to configure Firestore settings: $e');
      }
    }
    
    return firestore;
  },
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

final firebaseStorageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);

final rtdbPresenceServiceProvider = Provider<RtdbPresenceService>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return RtdbPresenceService(db);
});

/// RTDB user service — reads user identity data from Realtime Database.
final rtdbUserServiceProvider = Provider<RtdbUserService>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return RtdbUserService(rtdb: db);
});

/// Real-time displayName stream from RTDB at /users/{userId}/displayName.
///
/// Returns null if the user ID is empty, RTDB is unavailable, or the field
/// does not exist. Use this provider to get fresh displayName that bypasses
/// Firestore and reads directly from the source of truth.
final displayNameStreamProvider = StreamProvider.autoDispose
    .family<String?, String>((ref, userId) {
      final normalizedUserId = userId.trim();
      if (normalizedUserId.isEmpty) {
        return Stream<String?>.value(null);
      }
      final service = ref.watch(rtdbUserServiceProvider);
      return service.watchDisplayName(normalizedUserId);
    });




import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_call_tracker.dart';

/// Zero-boilerplate Firestore instrumentation via Dart extension methods.
///
/// Drop-in replacements for the raw Firestore APIs:
///
/// ```dart
/// // BEFORE
/// final snap = await ref.get();
/// final stream = ref.snapshots();
/// await ref.set(data);
/// await ref.update(data);
/// await ref.delete();
///
/// // AFTER (auto-tracked)
/// final snap = await ref.trackedGet();
/// final stream = ref.trackedSnapshots();
/// await ref.trackedSet(data);
/// await ref.trackedUpdate(data);
/// await ref.trackedDelete();
/// ```
///
/// All extensions are no-ops in release mode — the [FirestoreCallTracker]
/// itself guards with `kDebugMode`.

// ─── DocumentReference extensions ─────────────────────────────────────────

extension TrackedDocRef<T extends Object?> on DocumentReference<T> {
  /// Performs a [get] and records it as a Firestore read.
  Future<DocumentSnapshot<T>> trackedGet([GetOptions? options]) {
    if (kDebugMode) FirestoreCallTracker.trackRead(path);
    return options != null ? get(options) : get();
  }

  /// Listens to [snapshots] and records each new snapshot as a Firestore read.
  Stream<DocumentSnapshot<T>> trackedSnapshots({
    bool includeMetadataChanges = false,
  }) {
    return snapshots(
      includeMetadataChanges: includeMetadataChanges,
    ).map((snap) {
      if (kDebugMode) FirestoreCallTracker.trackRead(path);
      return snap;
    });
  }

  /// Performs a [set] and records it as a Firestore write.
  Future<void> trackedSet(T data, [SetOptions? options]) {
    if (kDebugMode) FirestoreCallTracker.trackWrite(path);
    return options != null ? set(data, options) : set(data);
  }

  /// Performs an [update] and records it as a Firestore write.
  Future<void> trackedUpdate(Map<String, Object?> data) {
    if (kDebugMode) FirestoreCallTracker.trackWrite(path);
    return update(data);
  }

  /// Performs a [delete] and records it as a Firestore write.
  Future<void> trackedDelete() {
    if (kDebugMode) FirestoreCallTracker.trackWrite(path);
    return delete();
  }
}

// ─── CollectionReference / Query extensions ────────────────────────────────

extension TrackedQueryRef<T extends Object?> on Query<T> {
  /// Performs a [get] and records it as a Firestore read.
  Future<QuerySnapshot<T>> trackedGet([GetOptions? options]) {
    if (kDebugMode) FirestoreCallTracker.trackRead(_queryPath(this));
    return options != null ? get(options) : get();
  }

  /// Listens to [snapshots] and records each delivery as a Firestore read.
  Stream<QuerySnapshot<T>> trackedSnapshots({
    bool includeMetadataChanges = false,
  }) {
    return snapshots(
      includeMetadataChanges: includeMetadataChanges,
    ).map((snap) {
      if (kDebugMode) FirestoreCallTracker.trackRead(_queryPath(this));
      return snap;
    });
  }
}

/// Best-effort path label for a [Query] (CollectionReference exposes its path;
/// generic queries do not, so we fall back to runtimeType).
String _queryPath(Query<Object?> q) {
  if (q is CollectionReference) return q.path;
  return q.runtimeType.toString();
}

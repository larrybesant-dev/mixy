import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final entitlementAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final entitlementFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final entitlementUserIdProvider = Provider<String?>((ref) {
  return ref.watch(entitlementAuthProvider).currentUser?.uid;
});

final vipEntitlementProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(entitlementUserIdProvider);
  if (uid == null || uid.isEmpty) {
    return Stream<bool>.value(false);
  }

  final firestore = ref.watch(entitlementFirestoreProvider);
  return firestore.collection('users').doc(uid).snapshots().map((snapshot) {
    return hasVipEntitlement(snapshot.data());
  });
});

bool hasVipEntitlement(Map<String, dynamic>? userData) {
  if (userData == null) {
    return false;
  }

  final entitlements = userData['entitlements'];
  if (entitlements is! Map<String, dynamic>) {
    return false;
  }

  final vip = entitlements['vip'];
  if (vip is! Map<String, dynamic>) {
    return false;
  }

  return vip['active'] == true;
}

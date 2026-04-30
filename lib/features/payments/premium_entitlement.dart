import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';

final entitlementAuthProvider = firebaseAuthProvider;

final entitlementUserIdProvider = Provider<String?>((ref) {
  return ref.watch(entitlementAuthProvider).currentUser?.uid;
});

final vipEntitlementProvider = Provider<AsyncValue<bool>>((ref) {
  final uid = ref.watch(entitlementUserIdProvider);
  if (uid == null || uid.isEmpty) {
    return const AsyncData(false);
  }

  return ref.watch(userDataStreamProvider(uid)).whenData((userData) {
    return hasVipEntitlement(userData);
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

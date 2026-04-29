import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/config/schema_migration_flags.dart';
import 'package:mixvy/services/schema_mutation_service.dart';

bool _asBool(dynamic value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return fallback;
}

// Check if user is verified
final userVerificationProvider =
    StreamProvider.family<bool, String>((ref, userId) {
  final firestore = ref.watch(firestoreProvider);
  final verificationRef = firestore.collection('verification').doc(userId);
  final usersRef = firestore.collection('users').doc(userId);

  return verificationRef.snapshots().asyncMap((snapshot) async {
    if (snapshot.exists && snapshot.data() != null) {
      return _asBool(snapshot.data()?['isVerified'], fallback: false);
    }

    if (!SchemaMigrationFlags.enableVerificationLegacyRead) {
      return false;
    }

    final userSnapshot = await usersRef.get();
    if (!userSnapshot.exists) return false;
    return _asBool(userSnapshot.data()?['isVerified'], fallback: false);
  });
});

// Get all verified users (for admin purposes)
final verifiedUsersProvider = StreamProvider<List<String>>((ref) {
  final firestore = ref.watch(firestoreProvider);

  // Source-of-truth is now the 'verification' root collection
  return firestore
      .collection('verification')
      .where('isVerified', isEqualTo: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => doc.id).toList());
});

// Verification controller (admin only)
class VerificationController {
  final SchemaMutationService _mutationService;

  VerificationController({required FirebaseFirestore firestore})
      : _mutationService = SchemaMutationService(firestore: firestore);

  Future<void> verifyUser({
    required String userId,
    required String verifiedBy,
  }) async {
    await _mutationService.setVerificationStatus(
      userId: userId,
      isVerified: true,
      verifiedBy: verifiedBy,
    );
  }

  Future<void> unverifyUser({required String userId}) async {
    await _mutationService.setVerificationStatus(
      userId: userId,
      isVerified: false,
    );
  }
}

final verificationControllerProvider = Provider<VerificationController>((ref) {
  return VerificationController(firestore: ref.watch(firestoreProvider));
});

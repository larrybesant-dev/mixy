import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/config/schema_migration_flags.dart';
import 'package:mixvy/services/schema_mutation_service.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';

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
final userVerificationProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, userId) {
      final userDataAsync = ref.watch(userDataStreamProvider(userId));

      return ref.watch(verificationDocStreamProvider(userId).stream).map((snapshot) {
        final verificationData = snapshot?.data();
        if (snapshot?.exists == true && verificationData != null) {
          return _asBool(verificationData['isVerified'], fallback: false);
        }

        if (!SchemaMigrationFlags.enableVerificationLegacyRead) {
          return false;
        }

        return _asBool(userDataAsync.valueOrNull?['isVerified'], fallback: false);
      });
    });

// Get all verified users — ADMIN ONLY context. autoDispose so it releases
// when the admin screen is closed. Hard-limited to 200 docs; use server-side
// pagination for larger admin queries. Do NOT watch this from a user-facing
// widget — it scans the entire verification collection.
final verifiedUsersProvider = StreamProvider.autoDispose<List<String>>((ref) {
  return ref.watch(verifiedUserIdsStreamProvider.stream);
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

final verificationRequestProvider =
    StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
      final uid = ref.watch(authControllerProvider).uid;
      if (uid == null || uid.trim().isEmpty) {
        return Stream.value(null);
      }

      return ref
          .watch(verificationRequestDocStreamProvider(uid).stream)
          .map((doc) => doc?.exists == true ? doc?.data() : null);
    });





import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/firebase_providers.dart';

abstract class AccountDeletionService {
  Future<void> deleteCurrentAccount();
}

class AccountDeletionException implements Exception {
  const AccountDeletionException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  bool get requiresRecentLogin => code == 'requires-recent-login';

  @override
  String toString() => message;
}

class FirebaseAccountDeletionService implements AccountDeletionService {
  FirebaseAccountDeletionService({
    required FirebaseFunctions functions,
  }) : _deleteAccount = (() async {
          await functions
              .httpsCallable('deleteCurrentUserAccount')
              .call<void>();
        });

  FirebaseAccountDeletionService.forTesting({
    required Future<void> Function() deleteAccount,
  }) : _deleteAccount = deleteAccount;

  final Future<void> Function() _deleteAccount;

  @override
  Future<void> deleteCurrentAccount() async {
    try {
      await _deleteAccount();
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final reason = details is Map ? details['reason'] : null;
      final code = reason == 'requires-recent-login'
          ? 'requires-recent-login'
          : error.code;
      throw AccountDeletionException(
        code: code,
        message: error.message ?? 'Account deletion failed.',
      );
    }
  }
}

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  return FirebaseAccountDeletionService(
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

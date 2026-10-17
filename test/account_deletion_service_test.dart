import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/services/account_deletion_service.dart';

void main() {
  test('account deletion service invokes the configured backend operation',
      () async {
    var invocationCount = 0;
    final service = FirebaseAccountDeletionService.forTesting(
      deleteAccount: () async {
        invocationCount++;
      },
    );

    await service.deleteCurrentAccount();

    expect(invocationCount, 1);
  });

  test('recent-login errors are identifiable by the account screen', () {
    const error = AccountDeletionException(
      code: 'requires-recent-login',
      message: 'Sign in again.',
    );

    expect(error.requiresRecentLogin, isTrue);
    expect(error.toString(), 'Sign in again.');
  });
}

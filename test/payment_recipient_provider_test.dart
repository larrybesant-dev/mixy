import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/payments/payment_recipient_provider.dart';
import 'package:mixvy/models/user_model.dart';

class FakePaymentRecipientRepository implements PaymentRecipientRepository {
  FakePaymentRecipientRepository(this.users);

  final List<UserModel> users;

  @override
  Future<List<UserModel>> searchRecipients(
    String query, {
    String? currentUserId,
  }) async {
    final normalizedQuery = query.trim().toLowerCase();

    return users
        .where((user) => user.id != currentUserId)
        .where((user) {
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return user.username.toLowerCase().contains(normalizedQuery) ||
              user.email.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
  }
}

void main() {
  test('paymentRecipientSearchProvider filters available users', () async {
    final container = ProviderContainer(
      overrides: [
        paymentRecipientRepositoryProvider.overrideWithValue(
          FakePaymentRecipientRepository([
            UserModel(
              id: 'u1',
              email: 'alice@mixvy.com',
              username: 'Alice',
              createdAt: DateTime(2026, 1, 1),
            ),
            UserModel(
              id: 'u2',
              email: 'bruno@mixvy.com',
              username: 'Bruno',
              createdAt: DateTime(2026, 1, 1),
            ),
          ]),
        ),
        currentPaymentUserIdProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    final results = await container.read(
      paymentRecipientSearchProvider('ali').future,
    );

    expect(results, hasLength(1));
    expect(results.single.username, 'Alice');
  });
}

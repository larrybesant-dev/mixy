import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mixvy/features/payments/payments_screen.dart';
import 'package:mixvy/features/payments/payments_controller.dart';
import 'package:mixvy/features/payments/payment_recipient_provider.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/models/wallet_model.dart';
import 'package:mixvy/presentation/providers/coin_transaction_provider.dart';
import 'package:mixvy/presentation/providers/referral_provider.dart';
import 'package:mixvy/presentation/providers/wallet_provider.dart';
import 'package:mixvy/services/payment_api.dart';
import 'package:mixvy/services/cash_out_service.dart';

import 'test_helpers.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPaymentGateway extends Mock implements PaymentGateway {}

class MockPaymentRecipientRepository extends Mock
    implements PaymentRecipientRepository {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp({
  MockPaymentGateway? gateway,
  MockPaymentRecipientRepository? recipientRepo,
}) {
  final gw = gateway ?? MockPaymentGateway();
  when(() => gw.currentUser).thenReturn(null);
  when(() => gw.sendPayment(any(), any())).thenAnswer((_) async {});
  when(() => gw.requestPayment(any(), any(), any())).thenAnswer((_) async {});

  final repo = recipientRepo ?? MockPaymentRecipientRepository();
  when(
    () => repo.searchRecipients(
      any(),
      currentUserId: any(named: 'currentUserId'),
    ),
  ).thenAnswer((_) async => <UserModel>[]);

  final fakeFirestore = FakeFirebaseFirestore();
  final mockAuth = _MockFirebaseAuth();
  when(() => mockAuth.currentUser).thenReturn(null);
  final cashOutService = CashOutService(
    firestore: fakeFirestore,
    auth: mockAuth,
  );

  const emptyWallet = WalletModel(userId: 'user-1', coinBalance: 0);

  return ProviderScope(
    overrides: [
      paymentControllerProvider.overrideWith(
        () => PaymentController(gateway: gw),
      ),
      paymentRecipientRepositoryProvider.overrideWithValue(repo),
      currentPaymentUserIdProvider.overrideWithValue(null),
      cashOutServiceProvider.overrideWithValue(cashOutService),
      walletDetailsProvider.overrideWith(
        (_) => Stream<WalletModel>.value(emptyWallet),
      ),
      coinTransactionStreamProvider('').overrideWith(
        (_) => Stream<List<CoinTransaction>>.value(<CoinTransaction>[]),
      ),
      referralCodeProvider.overrideWith((_) => Stream<String?>.value(null)),
      referralEarningsProvider.overrideWith((_) => Stream<double>.value(0)),
    ],
    child: const MaterialApp(home: PaymentsScreen()),
  );
}

// Sets a tall test surface so ListView lays out all children, not just
// those within the default 800x600 test viewport.
Future<void> _setTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 5000));
  addTearDown(() async => tester.binding.setSurfaceSize(null));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await testSetup();
  });

  group('PaymentsScreen', () {
    testWidgets('renders Payments appbar title', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('Payments'), findsOneWidget);
    });

    testWidgets('shows recipient search field and amount field', (
      tester,
    ) async {
      await _setTallSurface(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      await tester.pump(); // let StreamProviders resolve

      expect(find.text('Search recipient'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
    });

    testWidgets('shows Send Coins and Request Coins buttons', (tester) async {
      await _setTallSurface(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      await tester.pump();

      expect(find.text('Send Coins'), findsOneWidget);
      expect(find.text('Request Coins'), findsOneWidget);
    });

    testWidgets('shows quick-amount chips', (tester) async {
      await _setTallSurface(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      await tester.pump();

      expect(find.widgetWithText(ActionChip, '10'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, '100'), findsOneWidget);
    });

    testWidgets(
      'tapping Send Coins with no recipient shows validation snackbar',
      (tester) async {
        await _setTallSurface(tester);
        await tester.pumpWidget(_buildApp());
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Send Coins'));
        await tester.pump();

        expect(
          find.text(
            'Select a recipient and enter a valid amount (max 100000).',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping Request Coins with no recipient shows validation snackbar',
      (tester) async {
        await _setTallSurface(tester);
        await tester.pumpWidget(_buildApp());
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Request Coins'));
        await tester.pump();

        expect(
          find.text(
            'Select a recipient and enter a valid amount (max 100000).',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows coin balance from wallet when wallet data loads', (
      tester,
    ) async {
      await _setTallSurface(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('Coin balance:'), findsOneWidget);
    });

    testWidgets('shows no transactions yet when list is empty', (tester) async {
      await _setTallSurface(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('No transactions yet'), findsOneWidget);
    });

    testWidgets('shows no open refund requests initially', (tester) async {
      await _setTallSurface(tester);
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('No open refund requests.'), findsOneWidget);
    });
  });
}

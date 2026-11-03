import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/after_dark/providers/creator_subscription_provider.dart';
import 'package:mixvy/features/after_dark/screens/creator_marketplace_screen.dart';
import 'package:mixvy/features/after_dark/screens/creator_subscription_screen.dart';
import 'package:mixvy/services/creator_subscription_service.dart';

class _FakeCreatorSubscriptionService implements CreatorSubscriptionService {
  _FakeCreatorSubscriptionService(
    this.overview, {
    this.creators = const <CreatorMarketplaceEntry>[],
  });

  final CreatorSubscriptionOverview overview;
  final List<CreatorMarketplaceEntry> creators;

  @override
  Future<CreatorSubscriptionOverview> cancelCreatorSubscription(
    String creatorId,
  ) async =>
      overview;

  @override
  Future<String> createCreatorSubscriptionCheckout(String creatorId) async =>
      'https://checkout.stripe.test/session';

  @override
  Future<String> createStripeConnectOnboardingLink() async =>
      'https://connect.stripe.test/onboarding';

  @override
  Future<CreatorSubscriptionOverview> getCreatorSubscriptionOverview(
    String creatorId,
  ) async =>
      overview;

  @override
  Future<CreatorSubscriptionOverview> saveCreatorSubscriptionOffer({
    required bool enabled,
    required int monthlyPriceCents,
    required List<String> benefits,
  }) async =>
      overview;

  @override
  Future<List<CreatorMarketplaceEntry>> listCreatorSubscriptionMarketplace({
    String query = '',
  }) async =>
      creators;

  @override
  Future<List<CreatorSubscriberUpdate>> listCreatorSubscriberUpdates(
    String creatorId,
  ) async =>
      const <CreatorSubscriberUpdate>[];

  @override
  Future<CreatorSubscriberUpdate> publishCreatorSubscriberUpdate(
    String text,
  ) async =>
      CreatorSubscriberUpdate(
        id: 'update-1',
        creatorId: 'creator-1',
        text: text,
        createdAt: DateTime(2026),
      );

  @override
  Future<void> reportCreatorSubscriberUpdate({
    required String updateId,
    required String reason,
    String details = '',
  }) async {}
}

CreatorSubscriptionOverview _overview({required bool isOwner}) {
  return CreatorSubscriptionOverview(
    isOwner: isOwner,
    offer: const CreatorSubscriptionOffer(
      creatorId: 'creator-1',
      enabled: true,
      monthlyPriceCents: 499,
      currency: 'usd',
      benefits: <String>['Private lounges', 'Subscriber-only updates'],
    ),
    connectOnboardingComplete: true,
    subscriberCount: 7,
  );
}

void main() {
  Widget buildSubject(CreatorSubscriptionOverview overview) {
    return ProviderScope(
      overrides: [
        creatorSubscriptionServiceProvider.overrideWithValue(
          _FakeCreatorSubscriptionService(overview),
        ),
      ],
      child: const MaterialApp(
        home: CreatorSubscriptionScreen(creatorId: 'creator-1'),
      ),
    );
  }

  testWidgets('shows creator controls and payout share', (tester) async {
    await tester.pumpWidget(buildSubject(_overview(isOwner: true)));
    await tester.pumpAndSettle();

    expect(find.text('Your membership offer'), findsOneWidget);
    expect(find.textContaining('You keep 85%'), findsOneWidget);
    expect(find.text('7 active subscribers'), findsOneWidget);
    expect(find.text('Update offer'), findsOneWidget);
  });

  testWidgets('shows subscriber benefits and gated test checkout', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(_overview(isOwner: false)));
    await tester.pumpAndSettle();

    expect(find.text('Support this creator'), findsOneWidget);
    expect(find.text('\$4.99 per month'), findsOneWidget);
    expect(find.text('Private lounges'), findsOneWidget);
    expect(
      find.text('Stripe test checkout is not configured in this build yet.'),
      findsOneWidget,
    );
    final subscribe = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Subscribe securely'),
    );
    expect(subscribe.onPressed, isNull);
  });

  testWidgets('marketplace displays enabled creator offers', (tester) async {
    const creator = CreatorMarketplaceEntry(
      creatorId: 'creator-1',
      displayName: 'CURVE',
      avatarUrl: '',
      offer: CreatorSubscriptionOffer(
        creatorId: 'creator-1',
        enabled: true,
        monthlyPriceCents: 499,
        currency: 'usd',
        benefits: <String>['Private lounges'],
      ),
      subscriberCount: 7,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatorSubscriptionServiceProvider.overrideWithValue(
            _FakeCreatorSubscriptionService(
              _overview(isOwner: false),
              creators: const <CreatorMarketplaceEntry>[creator],
            ),
          ),
        ],
        child: const MaterialApp(home: CreatorMarketplaceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CURVE'), findsOneWidget);
    expect(find.text('\$4.99/month - 7 subscribers'), findsOneWidget);
    expect(find.text('Private lounges'), findsOneWidget);
  });
}

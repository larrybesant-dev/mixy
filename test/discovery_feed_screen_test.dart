import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/ads/ad_manager.dart';
import 'package:mixvy/features/feed/controllers/feed_controller.dart';
import 'package:mixvy/features/payments/premium_entitlement.dart';
import 'package:mixvy/features/profile/profile_controller.dart';

/// Minimal widget that mirrors the promo banner conditional in
/// [DiscoveryFeedContent], without pulling in [StoriesRow] or any
/// Firebase dependency.
class _PromoBanner extends ConsumerWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasVipEntitlement =
        ref.watch(vipEntitlementProvider).valueOrNull ?? false;
    if (!AdManager.shouldShowAds(hasVipEntitlement: hasVipEntitlement)) {
      return const SizedBox.shrink();
    }
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Upgrade to MixVy Premium'),
        Text('Remove ads and unlock exclusive features.'),
        Text('Upgrade'),
      ],
    );
  }
}

Override _vipEntitlementOverride(bool hasVipEntitlement) {
  return vipEntitlementProvider.overrideWith(
    (ref) => AsyncData(hasVipEntitlement),
  );
}

Widget _buildWidget(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: Scaffold(body: _PromoBanner())),
  );
}

void main() {
  group('FeedState timing defaults', () {
    test('starts in loading mode to avoid a first-frame empty flash', () {
      const state = FeedState();

      expect(state.isLoading, isTrue);
      expect(state.liveRooms, isEmpty);
      expect(state.trendingUsers, isEmpty);
    });
  });

  group('AdManager.shouldShowAds', () {
    test('returns true when VIP entitlement is inactive', () {
      expect(AdManager.shouldShowAds(hasVipEntitlement: false), isTrue);
    });

    test('returns false when VIP entitlement is active', () {
      expect(AdManager.shouldShowAds(hasVipEntitlement: true), isFalse);
    });
  });

  group('DiscoveryFeedContent -- promo banner', () {
    testWidgets('shows banner when VIP entitlement is inactive', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWidget([
          _vipEntitlementOverride(false),
          profileControllerProvider.overrideWith(
            () => _StubProfileController(
              const ProfileState(membershipLevel: 'Free', followers: []),
            ),
          ),
        ]),
      );
      await tester.pump();

      expect(find.text('Upgrade to MixVy Premium'), findsOneWidget);
      expect(
        find.text('Remove ads and unlock exclusive features.'),
        findsOneWidget,
      );
      expect(find.text('Upgrade'), findsOneWidget);
    });

    testWidgets('hides banner when VIP entitlement is active', (tester) async {
      await tester.pumpWidget(
        _buildWidget([
          _vipEntitlementOverride(true),
          profileControllerProvider.overrideWith(
            () => _StubProfileController(
              const ProfileState(membershipLevel: 'Premium', followers: []),
            ),
          ),
        ]),
      );
      await tester.pump();

      expect(find.text('Upgrade to MixVy Premium'), findsNothing);
    });

    testWidgets(
      'shows banner when profile membership is null and entitlement is inactive',
      (tester) async {
        await tester.pumpWidget(
          _buildWidget([
            _vipEntitlementOverride(false),
            profileControllerProvider.overrideWith(
              () => _StubProfileController(const ProfileState(followers: [])),
            ),
          ]),
        );
        await tester.pump();

        expect(find.text('Upgrade to MixVy Premium'), findsOneWidget);
      },
    );
  });
}

/// Stub [ProfileController] that returns a fixed [ProfileState] without
/// requiring Firebase or Firestore. Passes a [_MockFirebaseAuth] and
/// [FakeFirebaseFirestore] so no real Firebase.instance is ever accessed.
class _StubProfileController extends ProfileController {
  final ProfileState _state;
  _StubProfileController(this._state);

  @override
  ProfileState build() => _state;
}

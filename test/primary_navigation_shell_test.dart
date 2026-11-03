import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/shared/widgets/primary_navigation_shell.dart';

void main() {
  testWidgets('uses a navigation rail on desktop widths', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1228, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var friendsSelected = false;
    var discoverSelected = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PrimaryNavigationShell(
            currentIndex: 4,
            onSelected: (_) {},
            onFriendsSelected: () => friendsSelected = true,
            onDiscoverSelected: () => discoverSelected = true,
            showBetaFeedback: true,
            onBetaFeedbackSelected: () {},
            child: const ColoredBox(color: Color(0xFF0D0A0C)),
          ),
        ),
      ),
    );

    expect(
      find.byKey(PrimaryNavigationShell.desktopNavigationKey),
      findsOneWidget,
    );
    expect(
      find.byKey(PrimaryNavigationShell.mobileNavigationKey),
      findsNothing,
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Messenger'), findsOneWidget);

    await tester.tap(find.text('Messenger'));
    expect(friendsSelected, isTrue);

    expect(find.text('Find People'), findsOneWidget);
    await tester.tap(find.text('Find People'));
    expect(discoverSelected, isTrue);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Beta Feedback'), findsOneWidget);
  });

  testWidgets('keeps bottom navigation on compact widths', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PrimaryNavigationShell(
            currentIndex: 0,
            onSelected: (_) {},
            onFriendsSelected: () {},
            onDiscoverSelected: () {},
            showBetaFeedback: true,
            onBetaFeedbackSelected: () {},
            child: const ColoredBox(color: Color(0xFF0D0A0C)),
          ),
        ),
      ),
    );

    expect(
      find.byKey(PrimaryNavigationShell.desktopNavigationKey),
      findsNothing,
    );
    expect(
      find.byKey(PrimaryNavigationShell.mobileNavigationKey),
      findsOneWidget,
    );
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Messenger'), findsNothing);
    expect(find.text('Find People'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Beta Feedback'), findsNothing);
  });

  testWidgets('offers a return path while room audio remains connected', (
    tester,
  ) async {
    var returnedToRoom = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PrimaryNavigationShell(
            currentIndex: 0,
            onSelected: (_) {},
            onFriendsSelected: () {},
            onDiscoverSelected: () {},
            showBetaFeedback: false,
            onBetaFeedbackSelected: () {},
            activeRoomId: 'room-a',
            onReturnToRoom: () => returnedToRoom = true,
            child: const ColoredBox(color: Color(0xFF0D0A0C)),
          ),
        ),
      ),
    );

    expect(find.text('You are still connected to a room'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('return-to-room-button')),
    );
    expect(returnedToRoom, isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/friends/providers/friends_providers.dart';
import 'package:mixvy/features/messaging/providers/messenger_window_provider.dart';
import 'package:mixvy/features/messaging/widgets/messenger_desktop_overlay.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'package:mixvy/services/messenger_status_service.dart';

void main() {
  testWidgets('shows and closes the desktop buddy panel', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        userProvider.overrideWithValue(null),
        friendRosterProvider.overrideWith((ref) => Stream.value(const [])),
        currentMessengerProfileStatusProvider.overrideWith(
          (ref) => Stream.value(const MessengerProfileStatus()),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(messengerDesktopProvider.notifier).toggleBuddyList();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MessengerDesktopOverlay(
            child: ColoredBox(color: Color(0xFF0B0B0B)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('mixvy-messenger-buddy-panel')),
      findsOneWidget,
    );
    expect(find.text('MixVy Messenger'), findsOneWidget);
    expect(find.text('Search buddies'), findsOneWidget);

    await tester.tap(find.byTooltip('Close messenger'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('mixvy-messenger-buddy-panel')),
      findsNothing,
    );
  });
}

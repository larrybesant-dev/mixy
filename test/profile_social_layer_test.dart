import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/profile/widgets/profile_card.dart';
import 'package:mixvy/features/profile/widgets/social_user_card.dart';

void main() {
  testWidgets('SocialUserCard shows handle, presence, and join action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialUserCard(
            displayName: 'Velvet Noir',
            username: '@velvetnoir',
            avatarUrl: null,
            statusText: 'Currently in room',
            presenceState: ProfilePresenceState.inRoom,
            primaryLabel: 'Following',
            onPrimaryPressed: () {},
            secondaryLabel: 'Join Room',
            onSecondaryPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('Velvet Noir'), findsOneWidget);
    expect(find.text('@velvetnoir'), findsOneWidget);
    expect(find.text('Currently in room'), findsOneWidget);
    expect(find.text('Join Room'), findsOneWidget);
  });

  testWidgets('ProfileActivitySection renders recent social activity', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileActivitySection(
            activities: [
              ProfileActivityItem(
                icon: Icons.mic,
                label: 'Joined room',
                value: 'Velvet Lounge',
              ),
              ProfileActivityItem(
                icon: Icons.videocam,
                label: 'Went live',
                value: 'Camera on',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Joined room'), findsOneWidget);
    expect(find.text('Velvet Lounge'), findsOneWidget);
    expect(find.text('Went live'), findsOneWidget);
    expect(find.text('Camera on'), findsOneWidget);
  });
}

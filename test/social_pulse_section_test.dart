import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/dashboard/widgets/social_pulse_section.dart';
import 'package:mixvy/features/feed/models/home_feed_snapshot.dart';

void main() {
  testWidgets('SocialPulseSection renders activity items and CTA labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialPulseSection(
            pulseItems: [
              PulseFeedItem(
                id: 'p1',
                type: 'room_momentum',
                title: 'Velvet Lounge is hot right now',
                detail: '12 inside • 3 on mic',
                timestamp: DateTime(2026, 4, 12, 21, 0),
              ),
              PulseFeedItem(
                id: 'p2',
                type: 'followed_user',
                title: 'Fresh activity from your circle',
                detail: '@midnightmuse',
                timestamp: DateTime(2026, 4, 12, 20, 45),
              ),
            ],
            onOpenPulseItem: _noopPulse,
            onOpenRooms: _noop,
            onOpenDiscover: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Social Pulse'), findsOneWidget);
    expect(find.text('Velvet Lounge is hot right now'), findsOneWidget);
    expect(find.text('12 inside • 3 on mic'), findsOneWidget);
    expect(find.text('@midnightmuse'), findsOneWidget);
    expect(find.text('Join a room'), findsOneWidget);
    expect(find.text('Find people'), findsOneWidget);
  });

  testWidgets(
    'SocialPulseSection shows quiet-state prompt when no activity exists',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SocialPulseSection(
              pulseItems: [],
              onOpenPulseItem: _noopPulse,
              onOpenRooms: _noop,
              onOpenDiscover: _noop,
            ),
          ),
        ),
      );

      expect(find.text('Your circle is quiet right now.'), findsWidgets);
      expect(find.text('Start the vibe'), findsOneWidget);
    },
  );
}

void _noop() {}

void _noopPulse(PulseFeedItem _) {}

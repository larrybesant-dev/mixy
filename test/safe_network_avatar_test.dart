import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/widgets/safe_network_avatar.dart';

void main() {
  testWidgets('shows fallback text when avatar URL is missing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body:
              SafeNetworkAvatar(radius: 34, avatarUrl: null, fallbackText: 'C'),
        ),
      ),
    );

    expect(find.text('C'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows fallback text when avatar URL is blank', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SafeNetworkAvatar(
              radius: 34, avatarUrl: '   ', fallbackText: 'C'),
        ),
      ),
    );

    expect(find.text('C'), findsOneWidget);
  });
}

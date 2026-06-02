import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/onboarding/onboarding_screen.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await testSetup();
  });

  testWidgets('Onboarding renders and advances pages', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())));
    await tester.pumpAndSettle();

    expect(find.byType(Directionality), findsWidgets);
    expect(find.text('Step into rooms with real chemistry.'), findsOneWidget);

    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(
      find.text('Meet people who match your energy fast.'),
      findsOneWidget);
  });
}











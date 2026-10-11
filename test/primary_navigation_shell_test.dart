import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/shared/widgets/primary_navigation_shell.dart';

void main() {
  testWidgets('uses a navigation rail on desktop widths', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1228, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PrimaryNavigationShell(
          currentIndex: 4,
          onSelected: (_) {},
          child: const ColoredBox(color: Color(0xFF0D0A0C)),
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
  });

  testWidgets('keeps bottom navigation on compact widths', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PrimaryNavigationShell(
          currentIndex: 0,
          onSelected: (_) {},
          child: const ColoredBox(color: Color(0xFF0D0A0C)),
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
  });
}

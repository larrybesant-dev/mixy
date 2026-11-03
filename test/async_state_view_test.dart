import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/shared/widgets/async_state_view.dart';

void main() {
  testWidgets('replaces a stalled loading state with retry UI', (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppBoundedLoadingView(
            fallbackContext: 'conversations',
            label: 'Loading conversations',
            timeout: const Duration(seconds: 1),
            onRetry: () => retryCount++,
          ),
        ),
      ),
    );

    expect(find.text('Loading conversations'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Taking longer than expected'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(retryCount, 1);
    expect(find.text('Loading conversations'), findsOneWidget);
  });
}

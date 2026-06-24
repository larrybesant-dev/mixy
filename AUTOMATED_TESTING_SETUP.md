# MIXVY Automated E2E Testing Setup Guide

## Overview

This guide walks you through setting up automated E2E tests using **Flutter's `integration_test`** (recommended for quick setup) and **`patrol`** (recommended for advanced UI interactions).

---

## Option 1: Flutter `integration_test` (Recommended for Getting Started)

### Why Choose `integration_test`?
- ✅ Native Flutter testing framework
- ✅ No external dependencies
- ✅ Works with Firebase directly
- ✅ Supports web, mobile, desktop
- ✅ CI/CD friendly (GitHub Actions, etc.)

### Setup Steps

#### 1. Create test directory (if it doesn't exist)
```bash
mkdir -p integration_test
```

#### 2. Add test file
- Copy `integration_test/e2e_critical_flows_test.dart` (already created in workspace)

#### 3. Update `pubspec.yaml`
```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_test:
    sdk: flutter
```

Run: `flutter pub get`

#### 4. Run tests locally (web)
```bash
# For web (fastest for iteration)
flutter test integration_test/e2e_critical_flows_test.dart -d web

# For Android emulator
flutter test integration_test/e2e_critical_flows_test.dart -d emulator-5554

# For all tests in folder
flutter test integration_test/ -d web
```

#### 5. Run with verbose output (for debugging)
```bash
flutter test integration_test/e2e_critical_flows_test.dart -d web -v
```

#### 6. Generate coverage report
```bash
flutter test integration_test/ -d web --coverage
# Coverage report in: coverage/lcov.info
```

### Example: Detailed Test Structure

```dart
testWidgets('Example: Verify real-time chat sync', (WidgetTester tester) async {
  // 1. SETUP: Navigate to app
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 3));

  // 2. ACTION: Tap chat input and send message
  await tester.tap(find.byType(TextField));
  await tester.enterText(find.byType(TextField), 'Test message');
  await tester.tap(find.text('Send'));

  // 3. WAIT: Let Firestore sync
  await tester.pumpAndSettle(const Duration(seconds: 2));

  // 4. ASSERT: Verify message appears
  expect(find.text('Test message'), findsOneWidget);
});
```

### CI/CD Integration (GitHub Actions)

Create `.github/workflows/e2e-tests.yml`:

```yaml
name: E2E Tests

on:
  pull_request:
  push:
    branches: [main, dev]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'

      - name: Get dependencies
        run: flutter pub get

      - name: Run integration tests (web)
        run: flutter test integration_test/ -d web
```

---

## Option 2: Patrol Framework (Advanced)

### Why Choose Patrol?
- ✅ More powerful UI interaction capabilities
- ✅ Better debugging tools (visual logs)
- ✅ Cross-platform (iOS, Android, web, desktop)
- ✅ Built-in retry logic for flaky tests
- ✅ Excellent for real-world app scenarios

### Setup Steps

#### 1. Add Patrol to `pubspec.yaml`
```yaml
dev_dependencies:
  patrol: ^3.0.0
```

Run: `flutter pub get`

#### 2. Create Patrol test file
Create `integration_test/patrol_e2e_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:mixvy/main.dart' as app;

void main() {
  patrolTest(
    'E2E: Onboarding + Room Join + Moderation',
    ($) async {
      // Launch app
      await $.pumpWidget(const app.MyApp());

      // Tap SIGN IN button with retry logic
      await $(#signInButton).tap();
      await $.pumpAndSettle();

      // Type email with input method
      await $.typeText(find.byType(TextField), 'testuser@mixvy.test');
      await $.pumpAndSettle();

      // Verify element exists with timeout
      await $.waitUntilVisible(find.text('Live Rooms'));

      // Test real-world scenario: scroll and tap
      await $.scrollUntilVisible(
        find.text('Room to Join'),
        scroll: Offset(0, -300),
      );

      // Screenshot for visual regression testing
      await $.screenshot(name: 'room_joined_state');
    },
  );
}
```

#### 3. Run Patrol tests
```bash
# Web
patrol test -d web

# Android
patrol test -d emulator-5554

# With screenshots
patrol test -d web --verbose
```

#### 4. View visual reports
```bash
# Generated in: test_artifacts/
# Screenshots saved to: test_artifacts/screenshots/
```

---

## Test Automation Best Practices

### 1. **Use Finders Strategically**

```dart
// ❌ DON'T: Too broad
find.byType(TextField)

// ✅ DO: Specific with keys
find.byKey(Key('email_input'))

// ✅ DO: Combine matchers
find.byWidgetPredicate(
  (widget) => widget is Text && widget.data == 'Sign In',
)
```

### 2. **Handle Async Operations Correctly**

```dart
// Wait for state changes
await tester.pumpAndSettle(const Duration(seconds: 3));

// Or use explicit waits
await tester.pumpWidget(app.main());
await tester.pumpFrames(app.main(), Duration(seconds: 5));

// For Firebase: wait for streams to initialize
await Future.delayed(const Duration(seconds: 2));
```

### 3. **Test Real-Time Features (Riverpod Sync)**

```dart
// Simulate two users updating state simultaneously
testWidgets('Real-time presence sync', (WidgetTester tester) async {
  // User 1: Open app
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 3));

  // Verify User 1 sees initial state
  expect(find.text('Friends: 0'), findsOneWidget);

  // Simulate User 2 coming online (via Firestore listener)
  // In real test, use mock Firestore or parallel browser
  await tester.pumpAndSettle(const Duration(seconds: 2));

  // Verify Riverpod rebuilds and UI updates
  expect(find.text('Friends: 1'), findsOneWidget);
});
```

### 4. **Mock Firebase for Unit Testing (Separate from E2E)**

For unit/widget tests, use mocks to isolate logic:

```dart
// test/providers/social_providers_test.dart
import 'package:mockito/mockito.dart';

void main() {
  group('Social Providers', () {
    test('friendsProvider emits updated list when friend comes online', () async {
      // Mock Firestore
      final mockFirestore = MockFirebaseFirestore();

      // Test provider logic
      expect(friendsProvider, emits(['friend1']));
    });
  });
}
```

---

## Monitoring & Debugging

### 1. **Check Logs in Integration Tests**

```dart
testWidgets('With logging', (WidgetTester tester) async {
  // Enable Dart logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });

  app.main();
  await tester.pumpAndSettle();
});
```

### 2. **Screenshot on Failure**

```dart
testWidgets('With screenshots', (WidgetTester tester) async {
  try {
    app.main();
    await tester.pumpAndSettle();
    expect(find.text('Expected Text'), findsOneWidget);
  } catch (e) {
    // Take screenshot on failure
    await tester.binding.window.physicalSizeTestValue = Size(1080, 1920);
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

    print('Test failed. Screenshot available.');
    rethrow;
  }
});
```

### 3. **Verify Firestore Calls**

```dart
// During test, open DevTools → Network tab
// Check for Firestore calls:
// - POST /google.firestore.v1.Firestore/Write
// - POST /google.firestore.v1.Firestore/Listen

// Verify no 401/403 errors in responses
```

---

## Recommended Test Structure

```
integration_test/
├── e2e_critical_flows_test.dart  (Main E2E tests - already created)
├── auth_flow_test.dart           (Focus: Onboarding)
├── room_engagement_test.dart     (Focus: Moderation panel)
├── social_connectivity_test.dart (Focus: Riverpod sync)
└── fixtures/
    ├── test_data.dart            (Mock rooms, users)
    └── firebase_helper.dart      (Firebase test utilities)

test/
├── unit/
│   ├── providers/
│   │   └── social_providers_test.dart
│   └── services/
│       └── room_service_test.dart
└── widget/
    ├── room_page_test.dart
    └── friends_list_test.dart
```

---

## Command Reference

```bash
# Run all integration tests
flutter test integration_test/

# Run specific test
flutter test integration_test/e2e_critical_flows_test.dart

# Run on specific device
flutter test integration_test/ -d web      # Web
flutter test integration_test/ -d android  # Android
flutter test integration_test/ -d windows  # Windows

# Run with verbose output
flutter test integration_test/ -v

# Generate coverage
flutter test integration_test/ --coverage

# Run with reporter (for CI)
flutter test integration_test/ --reporter=json > test-results.json
```

---

## Troubleshooting

### Issue: "Looking up a deactivated widget's ancestor is unsafe"
**Cause:** Async gap between widget lifecycle
**Fix:** Use `pumpAndSettle()` with sufficient timeout
```dart
await tester.pumpAndSettle(const Duration(seconds: 3));
```

### Issue: Firestore auth fails in tests
**Cause:** Test environment not authenticated
**Fix:** Set `FIREBASE_EMULATOR_HOST` in CI/CD
```bash
export FIREBASE_EMULATOR_HOST=localhost:8080
```

### Issue: Real-time listeners don't fire during test
**Cause:** Riverpod providers not initialized
**Fix:** Ensure `ProviderContainer` is properly set up
```dart
final container = ProviderContainer();
addTearDown(container.dispose);
```

---

## Next Steps

1. **Run manual UAT first** (use `TEST_PLAN_MANUAL_UAT.md`)
2. **Record any issues** found during manual testing
3. **Expand automated tests** to cover those edge cases
4. **Set up CI/CD** to run tests on every PR
5. **Monitor** test flakiness and add retries as needed

---

**Questions?** Check `TEST_PLAN_MANUAL_UAT.md` for manual flow details or refer to:
- Flutter Testing Docs: https://flutter.dev/docs/testing
- Patrol Docs: https://patrol.leancode.co/
- Firebase Testing: https://firebase.flutter.dev/docs/testing

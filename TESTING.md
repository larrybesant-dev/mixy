# MixVy Testing Guide

## Integration Tests

### Modal Bottom Sheet Dismissal Pattern

**Problem:** `pumpAndSettle()` can hang indefinitely when dismissing modal bottom sheets in integration tests, especially on Windows with complex Riverpod widget trees.

**Root Cause:** `pumpAndSettle()` attempts to wait for *all* animations and frames to complete. With modals that have internal state updates, Riverpod provider rebuilds, or Agora WebRTC operations, the framework may never detect a "settled" state, causing the test to hang.

**Solution:** Use `pump(Duration)` with a fixed time instead. This gives the modal animation time to complete without trying to detect settlement.

#### ✅ Correct Pattern

```dart
// 1. Tap outside the modal to trigger dismissal
await tester.tapAt(const Offset(100, 100)); // Tap outside the sheet

// 2. Pump for a fixed duration (usually 300-600ms for modals)
await tester.pump(const Duration(milliseconds: 500));

// 3. Verify unmounting
expect(find.byType(UserProfileBottomSheet), findsNothing);
```

#### ❌ Avoid This Pattern

```dart
// This can hang:
await tester.tapAt(const Offset(100, 100));
await tester.pumpAndSettle(); // ⚠️ May hang indefinitely
```

#### Alternative: Navigator.pop() (Less Reliable)

```dart
// This sometimes works, but barrier tap is more consistent:
Navigator.of(tester.element(find.byType(UserProfileBottomSheet))).pop();
await tester.pump(const Duration(milliseconds: 500));
```

### Key Principles

| Pattern | When to Use | Notes |
|---------|-----------|-------|
| `pump(Duration)` | Modal dismissals, animations with known duration | **Preferred for modals** – gives exact time without hanging |
| `pumpAndSettle()` | Simple state changes, button taps without animations | Can hang with complex provider trees or WebRTC streams |
| Barrier tap | Closing modals | More reliable than `Navigator.pop()` inside test |
| `tapAt(Offset)` | Tapping outside widgets | Recommended over generic `tap()` for precise locations |

### Example: Full Modal Test Lifecycle

```dart
testWidgets('UserProfileBottomSheet lifecycle', (WidgetTester tester) async {
  // ... build app ...
  
  // Open modal by tapping a room
  await tester.tap(find.byType(SocialRoomCard));
  await tester.pump(const Duration(milliseconds: 500)); // Wait for modal slide-up
  
  // Verify modal is visible
  expect(find.byType(UserProfileBottomSheet), findsOneWidget);
  
  // Interact with modal content
  await tester.tap(find.byType(MixvyGoldButton)); // Follow button
  await tester.pump(const Duration(milliseconds: 250)); // Wait for state update
  
  // Close modal by tapping barrier
  await tester.tapAt(const Offset(100, 100)); // Tap outside the sheet
  await tester.pump(const Duration(milliseconds: 500)); // Wait for dismissal
  
  // Verify modal is gone
  expect(find.byType(UserProfileBottomSheet), findsNothing);
});
```

### Tuning Animation Duration

If tests fail with sheet still visible after `pump()`:
- **Increase duration:** Try 600ms or 750ms
- **Check your theme:** Look at `MaterialTheme` or custom `ThemeData` for animation durations
- **MixVy baseline:** 500ms works for standard Material animations + Agora stream settling

If tests pass but feel slow:
- **Decrease duration:** Try 300ms or 400ms
- **Verify independence:** Run test multiple times to ensure it's not a race condition

### Running Tests

```bash
# Run all integration tests with standard timeout
flutter test integration_test/ -d windows

# Run specific test
flutter test integration_test/app_tour_test.dart -d windows

# Run with custom timeout (for complex tests)
flutter test integration_test/ --timeout=5m -d windows

# Run with verbose output
flutter test integration_test/ -v -d windows
```

### Known Constraints

- **Windows only:** This pattern is specific to Windows device testing. macOS/iOS may have different timing requirements.
- **Riverpod state:** Complex async providers can delay settlement – use `pump(Duration)` instead of `pumpAndSettle()`.
- **WebRTC operations:** Agora stream init/teardown can overlap with animation frames – give extra time if needed.
- **Debug builds:** Debug APK/exe may be slower – increase durations by 100-200ms if running in Debug mode.

### Debugging Failed Tests

**Test hangs after 5 minutes:**
- Replace `pumpAndSettle()` with `pump(Duration)` immediately
- Check for async Firestore queries in mocked providers
- Verify Riverpod mocks don't have infinite listeners

**Widget still visible after tap:**
- Increase `pump()` duration
- Verify `tapAt()` coordinates are outside the sheet (use lower x/y values like 50, 50)
- Check if `showModalBottomSheet()` has custom `isDismissible: false` constraint

**Flaky tests (sometimes pass, sometimes fail):**
- Likely a timing issue – add 100ms buffer to all `pump()` calls
- Verify no concurrent animations in the widget tree
- Check for Riverpod `FutureProvider` that may re-evaluate mid-test

---

**Last Updated:** July 3, 2026  
**Tested On:** Flutter 3.5.0+, Windows (Device), MixVy 0.1.0  
**Contributors:** Integration test hardening project

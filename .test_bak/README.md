# MixVy Test Suite

This directory contains unit and widget tests for core controllers, providers, screens, and business logic.

## Running Tests

Run all tests with:

```
flutter test
```

Run the emulator-gated integration payment flow with:

```
flutter test integration_test/payment_emulator_flow_test.dart \
	--dart-define=RUN_FIREBASE_EMULATOR_TESTS=true
```

## Test Coverage
- AuthController
- ProfileController
- PaymentsController
- HomeController
- RoomController
- Room providers
- Live room screen widget state
- Payment recipient search/provider flow
- Payment API behavior
- App settings controller and settings screen
- Friend providers, friends screen, and friend request workflow
- Notification providers, notifications screen, and mark-read behavior

Use fake or overridden providers for Firebase-backed widget tests when possible so UI state can be validated without live services.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/push_messaging_service.dart';
import 'firebase_providers.dart';

/// Coordinates push messaging auth updates with the canonical [authStateProvider].
///
/// Listens to auth state changes and triggers push token registration/cleanup
/// via the [PushMessagingService] singleton. This ensures push messaging and
/// auth state remain synchronized without creating duplicate auth listeners.
///
/// This provider is automatically watched by the app shell, ensuring the
/// coordination starts during initialization.
final pushMessagingAuthCoordinatorProvider = FutureProvider<void>((ref) async {
  await ref.watch(authStateProvider.future);

  // After Firebase auth is ready, coordinate future auth state changes with push.
  ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
    next.whenData((_) {
      // When auth state changes, trigger push token re-registration.
      // The service handles the logic of whether registration is needed.
      // When user logs in, re-register push token with new user context.
      Future.microtask(() => PushMessagingService.instance.initialize());
    });
  });
});

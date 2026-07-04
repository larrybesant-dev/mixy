import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../services/presence_service.dart';
import '../models/user_presence.dart';

// Presence service provider
final presenceServiceProvider = Provider<PresenceService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return PresenceService(firestore: firestore);
});

// Start presence tracking for current user
final presenceTrackingProvider =
    StateNotifierProvider<PresenceTrackingController, bool>((ref) {
  final service = ref.watch(presenceServiceProvider);
  return PresenceTrackingController(service);
});

class PresenceTrackingController extends StateNotifier<bool> {
  PresenceTrackingController(this._service) : super(false);

  final PresenceService _service;

  Future<void> startTracking(String userId) async {
    await _service.startPresenceTracking(userId);
    state = true;
  }

  Future<void> stopTracking(String userId) async {
    await _service.stopPresenceTracking(userId);
    state = false;
  }
}

// Get user's presence
final userPresenceProvider =
    StreamProvider.family<UserPresence?, String>((ref, userId) {
  final service = ref.watch(presenceServiceProvider);
  return service.getUserPresenceStream(userId);
});

// Get typing users in a conversation
final typingUsersProvider =
    StreamProvider.family<List<String>, String>((ref, conversationId) {
  final service = ref.watch(presenceServiceProvider);
  return service.getTypingUsersStream(conversationId);
});

// Typing indicator controller
final typingIndicatorProvider =
    StateNotifierProvider.family<TypingIndicatorController, bool, (String, String)>(
  (ref, params) {
    final (conversationId, userId) = params;
    final service = ref.watch(presenceServiceProvider);
    return TypingIndicatorController(
      service,
      conversationId: conversationId,
      userId: userId,
    );
  },
);

class TypingIndicatorController extends StateNotifier<bool> {
  TypingIndicatorController(
    this._service, {
    required this.conversationId,
    required this.userId,
  }) : super(false);

  final PresenceService _service;
  final String conversationId;
  final String userId;
  Timer? _typingTimer;

  Future<void> setTyping(bool isTyping) async {
    state = isTyping;

    // Cancel existing timer
    _typingTimer?.cancel();

    if (isTyping) {
      await _service.setTyping(conversationId, userId, true);

      // Auto-stop typing after 3 seconds of inactivity
      _typingTimer = Timer(const Duration(seconds: 3), () async {
        await _service.setTyping(conversationId, userId, false);
        state = false;
      });
    } else {
      await _service.setTyping(conversationId, userId, false);
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }
}

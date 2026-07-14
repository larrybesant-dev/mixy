import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../services/presence_repository.dart';
import '../services/presence_service.dart';
import '../models/user_presence.dart';

// Private: Presence service provider (not exported from index.dart per architecture)
final _presenceServiceProvider = Provider<PresenceService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return PresenceService(firestore: firestore);
});

// Get user's presence using central repository
final userPresenceProvider =
    StreamProvider.family<UserPresence?, String>((ref, userId) {
  final repository = ref.watch(presenceRepositoryProvider);
  // Map PresenceModel stream to UserPresence model
  return repository.watchUserPresence(userId).map((model) => UserPresence(
    userId: model.userId ?? userId,
    isOnline: model.isOnline ?? false,
    lastActiveAt: model.lastSeen ?? DateTime.now(),
    currentActivity: null,
  ));
});

// Get typing users in a conversation
final typingUsersProvider =
    StreamProvider.family<List<String>, String>((ref, conversationId) {
  final service = ref.watch(_presenceServiceProvider);
  return service.getTypingUsersStream(conversationId);
});

// Typing indicator controller
final typingIndicatorProvider =
    StateNotifierProvider.family<TypingIndicatorController, bool, (String, String)>(
  (ref, params) {
    final (conversationId, userId) = params;
    final service = ref.watch(_presenceServiceProvider);
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

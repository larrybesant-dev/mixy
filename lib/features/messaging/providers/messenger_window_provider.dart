import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../services/messenger_status_service.dart';
import '../../../presentation/providers/user_provider.dart';

const double messengerDesktopBreakpoint = 900;

class MessengerWindowEntry {
  const MessengerWindowEntry({
    required this.conversationId,
    required this.title,
    this.minimized = false,
  });

  final String conversationId;
  final String title;
  final bool minimized;

  MessengerWindowEntry copyWith({String? title, bool? minimized}) {
    return MessengerWindowEntry(
      conversationId: conversationId,
      title: title ?? this.title,
      minimized: minimized ?? this.minimized,
    );
  }
}

class MessengerDesktopState {
  const MessengerDesktopState({
    this.isBuddyListOpen = false,
    this.windows = const <MessengerWindowEntry>[],
  });

  final bool isBuddyListOpen;
  final List<MessengerWindowEntry> windows;

  MessengerDesktopState copyWith({
    bool? isBuddyListOpen,
    List<MessengerWindowEntry>? windows,
  }) {
    return MessengerDesktopState(
      isBuddyListOpen: isBuddyListOpen ?? this.isBuddyListOpen,
      windows: windows ?? this.windows,
    );
  }
}

final messengerDesktopProvider =
    NotifierProvider<MessengerDesktopController, MessengerDesktopState>(
      MessengerDesktopController.new,
    );

class MessengerDesktopController extends Notifier<MessengerDesktopState> {
  static const int maxOpenWindows = 4;

  @override
  MessengerDesktopState build() => const MessengerDesktopState();

  void toggleBuddyList() {
    state = state.copyWith(isBuddyListOpen: !state.isBuddyListOpen);
  }

  void closeBuddyList() {
    state = state.copyWith(isBuddyListOpen: false);
  }

  void openConversation({
    required String conversationId,
    required String title,
  }) {
    final normalizedId = conversationId.trim();
    if (normalizedId.isEmpty) return;

    final existing = state.windows
        .where((entry) => entry.conversationId != normalizedId)
        .toList(growable: true);
    existing.add(
      MessengerWindowEntry(
        conversationId: normalizedId,
        title: title.trim().isEmpty ? 'Chat' : title.trim(),
      ),
    );
    if (existing.length > maxOpenWindows) {
      existing.removeRange(0, existing.length - maxOpenWindows);
    }
    state = state.copyWith(windows: List.unmodifiable(existing));
  }

  void closeConversation(String conversationId) {
    state = state.copyWith(
      windows: state.windows
          .where((entry) => entry.conversationId != conversationId)
          .toList(growable: false),
    );
  }

  void setMinimized(String conversationId, bool minimized) {
    state = state.copyWith(
      windows: [
        for (final entry in state.windows)
          if (entry.conversationId == conversationId)
            entry.copyWith(minimized: minimized)
          else
            entry,
      ],
    );
  }
}

final messengerStatusServiceProvider = Provider<MessengerStatusService>((ref) {
  return FirestoreMessengerStatusService(ref.watch(firestoreProvider));
});

final currentMessengerProfileStatusProvider =
    StreamProvider<MessengerProfileStatus>((ref) {
  final userId = ref.watch(userProvider)?.id ?? '';
  return ref.watch(messengerStatusServiceProvider).watchProfileStatus(userId);
});

void presentMessengerConversation({
  required BuildContext context,
  required WidgetRef ref,
  required String conversationId,
  required String title,
}) {
  if (MediaQuery.sizeOf(context).width >= messengerDesktopBreakpoint) {
    ref
        .read(messengerDesktopProvider.notifier)
        .openConversation(conversationId: conversationId, title: title);
    return;
  }
  context.go('/chat/$conversationId');
}

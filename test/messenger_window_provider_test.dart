import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/messaging/providers/messenger_window_provider.dart';

void main() {
  test('opens, minimizes, restores, and closes messenger windows', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(messengerDesktopProvider.notifier);

    controller.toggleBuddyList();
    expect(container.read(messengerDesktopProvider).isBuddyListOpen, isTrue);

    controller.openConversation(conversationId: 'one', title: 'Alex');
    controller.openConversation(conversationId: 'two', title: 'Jordan');
    controller.setMinimized('one', true);

    var state = container.read(messengerDesktopProvider);
    expect(state.windows, hasLength(2));
    expect(
      state.windows
          .singleWhere((entry) => entry.conversationId == 'one')
          .minimized,
      isTrue,
    );

    controller.setMinimized('one', false);
    controller.closeConversation('two');
    state = container.read(messengerDesktopProvider);
    expect(state.windows.single.conversationId, 'one');
    expect(state.windows.single.minimized, isFalse);
  });

  test('keeps the four most recently opened conversations', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(messengerDesktopProvider.notifier);

    for (var index = 0; index < 5; index++) {
      controller.openConversation(
        conversationId: 'conversation-$index',
        title: 'Friend $index',
      );
    }
    controller.openConversation(
      conversationId: 'conversation-2',
      title: 'Updated Friend',
    );

    final windows = container.read(messengerDesktopProvider).windows;
    expect(windows, hasLength(4));
    expect(
      windows.map((entry) => entry.conversationId),
      ['conversation-1', 'conversation-3', 'conversation-4', 'conversation-2'],
    );
    expect(windows.last.title, 'Updated Friend');
  });
}

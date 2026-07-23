import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/schema_messenger/messages/providers/messages_render_mode_provider.dart';

void main() {
  test('message view defaults to legacy mode', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final mode = container.read(messagePaneRenderModeProvider);

    expect(mode, MessagePaneRenderMode.legacy);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MessagePaneRenderMode { legacy, schema, dual }

class MessagePaneRenderModeController extends Notifier<MessagePaneRenderMode> {
  @override
  MessagePaneRenderMode build() => MessagePaneRenderMode.legacy;

  void setMode(MessagePaneRenderMode mode) {
    state = mode;
  }
}

final messagePaneRenderModeProvider =
    NotifierProvider<MessagePaneRenderModeController, MessagePaneRenderMode>(
  MessagePaneRenderModeController.new,
);

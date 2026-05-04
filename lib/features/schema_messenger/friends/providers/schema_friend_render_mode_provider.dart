import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FriendPaneRenderMode { legacy, schema, dual }

class FriendPaneRenderModeController extends Notifier<FriendPaneRenderMode> {
  @override
  FriendPaneRenderMode build() => FriendPaneRenderMode.dual;

  void setMode(FriendPaneRenderMode mode) {
    state = mode;
  }
}

final friendPaneRenderModeProvider =
    NotifierProvider<FriendPaneRenderModeController, FriendPaneRenderMode>(
      FriendPaneRenderModeController.new,
    );

String friendPaneSnapshotKey({
  required FriendPaneRenderMode mode,
  required List<String> legacyIds,
  required List<String> schemaIds,
}) {
  return '${mode.name}|${legacyIds.join(',')}|${schemaIds.join(',')}';
}

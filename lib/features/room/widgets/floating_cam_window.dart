import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dockable_panel.dart';

/// Metadata for a single floating cam window.
class FloatingCamWindowData {
  FloatingCamWindowData({
    required this.id,
    required this.label,
    required this.isLocal,
    this.remoteUid,
    this.userId,
    this.avatarUrl,
    this.canViewRemote = true,
    this.offset = const Offset(100, 100),
    this.width = 280.0,
    this.height = 200.0,
  }) : assert(isLocal || remoteUid != null);

  final String id;
  final String label;
  final bool isLocal;
  final int? remoteUid;
  final String? userId;
  final String? avatarUrl;
  final bool canViewRemote;
  Offset offset;
  double width;
  double height;
}

/// Provider that holds the set of currently detached cam windows.
final floatingCamWindowsProvider =
    StateNotifierProvider<
      FloatingCamWindowsNotifier,
      List<FloatingCamWindowData>
    >((_) => FloatingCamWindowsNotifier());

class FloatingCamWindowsNotifier
    extends StateNotifier<List<FloatingCamWindowData>> {
  FloatingCamWindowsNotifier() : super(const []);

  void add(FloatingCamWindowData window) {
    if (state.any((w) => w.id == window.id)) return;
    state = [...state, window];
  }

  void remove(String id) {
    state = state.where((w) => w.id != id).toList();
  }

  void updateOffset(String id, Offset offset) {
    state = [
      for (final w in state)
        if (w.id == id)
          FloatingCamWindowData(
            id: w.id,
            label: w.label,
            isLocal: w.isLocal,
            remoteUid: w.remoteUid,
            userId: w.userId,
            avatarUrl: w.avatarUrl,
            canViewRemote: w.canViewRemote,
            offset: offset,
            width: w.width,
            height: w.height,
          )
        else
          w,
    ];
  }

  bool contains(String id) => state.any((w) => w.id == id);
}

/// Renders all detached cam windows as floating overlays inside a Stack.
/// Place this inside the same Stack as the main room UI.
class FloatingCamWindowLayer extends ConsumerWidget {
  const FloatingCamWindowLayer({
    super.key,
    required this.onReattach,
    required this.contentBuilder,
  });

  /// Called when the user clicks "Dock" on a floating cam window.
  final void Function(String windowId) onReattach;
  final Widget Function(FloatingCamWindowData window) contentBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = ref.watch(floatingCamWindowsProvider);
    if (windows.isEmpty) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        for (final window in windows)
          FloatingDockablePanel(
            key: ValueKey('floating_cam_${window.id}'),
            title: window.label,
            icon: Icons.videocam,
            initialOffset: window.offset,
            width: window.width,
            height: window.height,
            onClose: () =>
                ref.read(floatingCamWindowsProvider.notifier).remove(window.id),
            onReattach: () => onReattach(window.id),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: contentBuilder(window),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/floating_cam_provider.dart';
import 'dockable_panel.dart';

class FloatingCamWindowLayer extends ConsumerWidget {
  const FloatingCamWindowLayer({
    super.key,
    required this.roomId,
    required this.labels,
    required this.contentBuilder,
  });

  final String roomId;
  final Map<String, String> labels;
  final Widget Function(String streamId) contentBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final states = ref.watch(floatingCamStatesProvider(roomId));
    final windows = states.values
        .where((cam) => cam.isDetached && labels.containsKey(cam.streamId))
        .toList(growable: false)
      ..sort((left, right) => left.zIndex.compareTo(right.zIndex));
    if (windows.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 1280,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 720,
        );
        final notifier = ref.read(floatingCamStatesProvider(roomId).notifier);

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            for (final window in windows)
              FloatingDockablePanel(
                key: ValueKey('floating_cam_${window.streamId}'),
                panelId: window.streamId,
                title: labels[window.streamId] ?? 'Camera',
                icon: Icons.videocam,
                position: window.position,
                size: window.size,
                minimized: window.isMinimized,
                onMove: (delta) {
                  notifier.bringToFront(window.streamId);
                  notifier.moveBy(
                    window.streamId,
                    delta,
                    viewportSize: viewportSize,
                  );
                },
                onResize: (delta) => notifier.resizeBy(
                  window.streamId,
                  delta,
                  viewportSize: viewportSize,
                ),
                onMinimizedChanged: (minimized) =>
                    notifier.setMinimized(window.streamId, minimized),
                onClose: () => notifier.reattach(window.streamId),
                onReattach: () => notifier.reattach(window.streamId),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  child: contentBuilder(window.streamId),
                ),
              ),
          ],
        );
      },
    );
  }
}

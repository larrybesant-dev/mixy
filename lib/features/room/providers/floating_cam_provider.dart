import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/floating_cam_state.dart';

final floatingCamStatesProvider = StateNotifierProvider.autoDispose
    .family<FloatingCamStateNotifier, Map<String, FloatingCamState>, String>(
  (ref, roomId) => FloatingCamStateNotifier(),
);

class FloatingCamStateNotifier
    extends StateNotifier<Map<String, FloatingCamState>> {
  FloatingCamStateNotifier() : super(const <String, FloatingCamState>{});

  void syncActiveStreamIds(Iterable<String> streamIds) {
    final orderedIds = streamIds.toSet().toList(growable: false);
    final activeIds = orderedIds.toSet();
    final next = <String, FloatingCamState>{
      for (final entry in state.entries)
        if (activeIds.contains(entry.key)) entry.key: entry.value,
    };

    var changed = next.length != state.length;
    for (var index = 0; index < orderedIds.length; index++) {
      final streamId = orderedIds[index];
      if (next.containsKey(streamId)) continue;
      next[streamId] = FloatingCamState(
        streamId: streamId,
        position: Offset(72 + (index % 8) * 24, 96 + (index % 6) * 24),
        size: const Size(280, 200),
        zIndex: index,
      );
      changed = true;
    }

    if (changed) {
      state = Map.unmodifiable(next);
    }
  }

  void detach(String streamId) {
    _update(
      streamId,
      (cam) => cam.copyWith(
        isDetached: true,
        isMinimized: false,
        zIndex: _nextZIndex,
      ),
    );
  }

  void reattach(String streamId) {
    _update(
      streamId,
      (cam) => cam.copyWith(isDetached: false, isMinimized: false),
    );
  }

  void bringToFront(String streamId) {
    final cam = state[streamId];
    if (cam == null || cam.zIndex == _nextZIndex - 1) return;
    _update(streamId, (value) => value.copyWith(zIndex: _nextZIndex));
  }

  void moveBy(String streamId, Offset delta, {Size? viewportSize}) {
    if (!delta.dx.isFinite || !delta.dy.isFinite) return;
    _update(streamId, (cam) {
      final next = cam.position + delta;
      if (viewportSize == null ||
          !viewportSize.width.isFinite ||
          !viewportSize.height.isFinite) {
        return cam.copyWith(position: next);
      }
      final maxX = math.max(0.0, viewportSize.width - cam.size.width);
      final maxY = math.max(0.0, viewportSize.height - 32);
      return cam.copyWith(
        position: Offset(
          next.dx.clamp(0.0, maxX),
          next.dy.clamp(0.0, maxY),
        ),
      );
    });
  }

  void resizeBy(String streamId, Offset delta, {Size? viewportSize}) {
    if (!delta.dx.isFinite || !delta.dy.isFinite) return;
    _update(streamId, (cam) {
      final maxWidth = viewportSize?.width.isFinite == true
          ? math.max(200.0, viewportSize!.width - cam.position.dx)
          : 800.0;
      final maxHeight = viewportSize?.height.isFinite == true
          ? math.max(150.0, viewportSize!.height - cam.position.dy)
          : 600.0;
      return cam.copyWith(
        size: Size(
          (cam.size.width + delta.dx).clamp(200.0, maxWidth),
          (cam.size.height + delta.dy).clamp(150.0, maxHeight),
        ),
      );
    });
  }

  void setMinimized(String streamId, bool minimized) {
    _update(
      streamId,
      (cam) => cam.copyWith(
        isMinimized: minimized,
        zIndex: _nextZIndex,
      ),
    );
  }

  int get _nextZIndex {
    if (state.isEmpty) return 0;
    return state.values.map((cam) => cam.zIndex).reduce(math.max) + 1;
  }

  void _update(
    String streamId,
    FloatingCamState Function(FloatingCamState cam) update,
  ) {
    final current = state[streamId];
    if (current == null) return;
    state = Map.unmodifiable({...state, streamId: update(current)});
  }
}

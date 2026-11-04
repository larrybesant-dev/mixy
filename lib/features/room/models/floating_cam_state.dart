import 'dart:ui';

class FloatingCamState {
  const FloatingCamState({
    required this.streamId,
    required this.position,
    required this.size,
    required this.zIndex,
    this.isMinimized = false,
    this.isDetached = false,
  });

  final String streamId;
  final Offset position;
  final Size size;
  final int zIndex;
  final bool isMinimized;
  final bool isDetached;

  FloatingCamState copyWith({
    Offset? position,
    Size? size,
    int? zIndex,
    bool? isMinimized,
    bool? isDetached,
  }) {
    return FloatingCamState(
      streamId: streamId,
      position: position ?? this.position,
      size: size ?? this.size,
      zIndex: zIndex ?? this.zIndex,
      isMinimized: isMinimized ?? this.isMinimized,
      isDetached: isDetached ?? this.isDetached,
    );
  }
}

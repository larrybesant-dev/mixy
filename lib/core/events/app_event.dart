abstract class AppEvent {
  const AppEvent({
    required this.id,
    required this.timestamp,
    this.sessionId,
    this.correlationId,
    this.tags = const <String>[],
  });

  final String id;
  final DateTime timestamp;
  final String? sessionId;
  final String? correlationId;
  final List<String> tags;

  String get defaultSessionId => 'ungrouped';

  String get defaultCorrelationId => id;

  String get normalizedSessionId {
    final normalized = sessionId?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
    final derived = defaultSessionId.trim();
    return derived.isEmpty ? 'ungrouped' : derived;
  }

  String get normalizedCorrelationId {
    final normalized = correlationId?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
    final derived = defaultCorrelationId.trim();
    return derived.isEmpty ? id : derived;
  }
}

class AppEventIds {
  static String roomSession({required String roomId, required String userId}) {
    return 'room:${_normalize(roomId)}:${_normalize(userId)}';
  }

  static String roomCorrelation({
    required String roomId,
    required String userId,
  }) {
    return 'room-flow:${_normalize(roomId)}:${_normalize(userId)}';
  }

  static String socialSession({required String userId}) {
    return 'social:${_normalize(userId)}';
  }

  static String followCorrelation({
    required String fromUserId,
    required String toUserId,
  }) {
    return 'follow:${_normalize(fromUserId)}:${_normalize(toUserId)}';
  }

  static String profileSession({required String userId}) {
    return 'profile:${_normalize(userId)}';
  }

  static String profileCorrelation({required String userId}) {
    return 'profile-update:${_normalize(userId)}';
  }

  static String cameraCorrelation({
    required String roomId,
    required String userId,
  }) {
    return 'camera:${_normalize(roomId)}:${_normalize(userId)}';
  }

  static String camViewCorrelation({
    required String viewerId,
    required String targetUserId,
  }) {
    return 'cam-view:${_normalize(viewerId)}:${_normalize(targetUserId)}';
  }

  static String _normalize(String value) {
    return value.trim().replaceAll(' ', '_');
  }
}

class RoomJoinedEvent extends AppEvent {
  const RoomJoinedEvent({
    required super.id,
    required super.timestamp,
    super.sessionId,
    super.correlationId,
    super.tags = const <String>['room', 'session'],
    required this.userId,
    required this.roomId,
    this.roomName,
  });

  final String userId;
  final String roomId;
  final String? roomName;

  @override
  String get defaultSessionId =>
      AppEventIds.roomSession(roomId: roomId, userId: userId);

  @override
  String get defaultCorrelationId =>
      AppEventIds.roomCorrelation(roomId: roomId, userId: userId);
}

class RoomLeftEvent extends AppEvent {
  const RoomLeftEvent({
    required super.id,
    required super.timestamp,
    super.sessionId,
    super.correlationId,
    super.tags = const <String>['room', 'session'],
    required this.userId,
    required this.roomId,
    this.roomName,
  });

  final String userId;
  final String roomId;
  final String? roomName;

  @override
  String get defaultSessionId =>
      AppEventIds.roomSession(roomId: roomId, userId: userId);

  @override
  String get defaultCorrelationId =>
      AppEventIds.roomCorrelation(roomId: roomId, userId: userId);
}

class MicStateChangedEvent extends AppEvent {
  const MicStateChangedEvent({
    required super.id,
    required super.timestamp,
    super.sessionId,
    super.correlationId,
    super.tags = const <String>['room', 'audio'],
    required this.userId,
    required this.roomId,
    required this.isSpeaker,
    this.roomName,
  });

  final String userId;
  final String roomId;
  final bool isSpeaker;
  final String? roomName;

  @override
  String get defaultSessionId =>
      AppEventIds.roomSession(roomId: roomId, userId: userId);

  @override
  String get defaultCorrelationId =>
      AppEventIds.roomCorrelation(roomId: roomId, userId: userId);
}

class CameraStateChangedEvent extends AppEvent {
  const CameraStateChangedEvent({
    required super.id,
    required super.timestamp,
    super.sessionId,
    super.correlationId,
    super.tags = const <String>['room', 'video'],
    required this.userId,
    required this.roomId,
    required this.isCameraOn,
    this.roomName,
  });

  final String userId;
  final String roomId;
  final bool isCameraOn;
  final String? roomName;

  @override
  String get defaultSessionId =>
      AppEventIds.roomSession(roomId: roomId, userId: userId);

  @override
  String get defaultCorrelationId =>
      AppEventIds.cameraCorrelation(roomId: roomId, userId: userId);
}

class FollowEvent extends AppEvent {
  const FollowEvent({
    required super.id,
    required super.timestamp,
    super.sessionId,
    super.correlationId,
    super.tags = const <String>['social'],
    required this.fromUserId,
    required this.toUserId,
    this.fromUsername,
    this.toUsername,
  });

  final String fromUserId;
  final String toUserId;
  final String? fromUsername;
  final String? toUsername;

  @override
  String get defaultSessionId => AppEventIds.socialSession(userId: fromUserId);

  @override
  String get defaultCorrelationId =>
      AppEventIds.followCorrelation(fromUserId: fromUserId, toUserId: toUserId);
}

class ProfileUpdatedEvent extends AppEvent {
  const ProfileUpdatedEvent({
    required super.id,
    required super.timestamp,
    super.sessionId,
    super.correlationId,
    super.tags = const <String>['profile'],
    required this.userId,
  });

  final String userId;

  @override
  String get defaultSessionId => AppEventIds.profileSession(userId: userId);

  @override
  String get defaultCorrelationId =>
      AppEventIds.profileCorrelation(userId: userId);
}

class CamViewEvent extends AppEvent {
  const CamViewEvent({
    required super.id,
    required super.timestamp,
    super.sessionId,
    super.correlationId,
    super.tags = const <String>['room', 'video'],
    required this.viewerId,
    required this.targetUserId,
  });

  final String viewerId;
  final String targetUserId;

  @override
  String get defaultSessionId => AppEventIds.socialSession(userId: viewerId);

  @override
  String get defaultCorrelationId => AppEventIds.camViewCorrelation(
    viewerId: viewerId,
    targetUserId: targetUserId,
  );
}

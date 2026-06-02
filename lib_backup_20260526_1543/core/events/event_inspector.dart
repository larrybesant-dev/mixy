import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'app_event.dart';

class EventConsumerTrace {
  const EventConsumerTrace({
    required this.consumer,
    required this.status,
    required this.recordedAt,
    this.message,
  });

  final String consumer;
  final String status;
  final DateTime recordedAt;
  final String? message;

  Map<String, Object?> toJson() => <String, Object?>{
        'consumer': consumer,
        'status': status,
        'recordedAt': recordedAt.toIso8601String(),
        'message': message,
      };
}

class EventInspectorEntry {
  const EventInspectorEntry({
    required this.sequence,
    required this.event,
    required this.recordedAt,
    this.isReplay = false,
    this.dropped = false,
    this.note,
    this.consumerTraces = const <EventConsumerTrace>[],
  });

  final int sequence;
  final AppEvent event;
  final DateTime recordedAt;
  final bool isReplay;
  final bool dropped;
  final String? note;
  final List<EventConsumerTrace> consumerTraces;

  String get eventId => event.id;
  String get eventType => event.runtimeType.toString();
  String get sessionId => event.normalizedSessionId;
  String get correlationId => event.normalizedCorrelationId;
  List<String> get tags => List<String>.unmodifiable(event.tags);

  Map<String, Object?> get payload => _payloadForEvent(event);

  EventInspectorEntry copyWith({
    bool? isReplay,
    bool? dropped,
    String? note,
    List<EventConsumerTrace>? consumerTraces,
  }) {
    return EventInspectorEntry(
      sequence: sequence,
      event: event,
      recordedAt: recordedAt,
      isReplay: isReplay ?? this.isReplay,
      dropped: dropped ?? this.dropped,
      note: note ?? this.note,
      consumerTraces: consumerTraces ?? this.consumerTraces,
    );
  }

  AppEvent createReplayEvent() {
    final replayTimestamp = DateTime.now();
    final replayId =
        '${event.id}:replay:${replayTimestamp.microsecondsSinceEpoch}';

    if (event is RoomJoinedEvent) {
      final typed = event as RoomJoinedEvent;
      return RoomJoinedEvent(
        id: replayId,
        timestamp: replayTimestamp,
        sessionId: typed.sessionId,
        correlationId: typed.correlationId,
        tags: typed.tags,
        userId: typed.userId,
        roomId: typed.roomId,
        roomName: typed.roomName,
      );
    }
    if (event is RoomLeftEvent) {
      final typed = event as RoomLeftEvent;
      return RoomLeftEvent(
        id: replayId,
        timestamp: replayTimestamp,
        sessionId: typed.sessionId,
        correlationId: typed.correlationId,
        tags: typed.tags,
        userId: typed.userId,
        roomId: typed.roomId,
        roomName: typed.roomName,
      );
    }
    if (event is MicStateChangedEvent) {
      final typed = event as MicStateChangedEvent;
      return MicStateChangedEvent(
        id: replayId,
        timestamp: replayTimestamp,
        sessionId: typed.sessionId,
        correlationId: typed.correlationId,
        tags: typed.tags,
        userId: typed.userId,
        roomId: typed.roomId,
        isSpeaker: typed.isSpeaker,
      );
    }
    if (event is CameraStateChangedEvent) {
      final typed = event as CameraStateChangedEvent;
      return CameraStateChangedEvent(
        id: replayId,
        timestamp: replayTimestamp,
        sessionId: typed.sessionId,
        correlationId: typed.correlationId,
        tags: typed.tags,
        userId: typed.userId,
        roomId: typed.roomId,
        isCameraOn: typed.isCameraOn,
      );
    }
    if (event is FollowEvent) {
      final typed = event as FollowEvent;
      return FollowEvent(
        id: replayId,
        timestamp: replayTimestamp,
        sessionId: typed.sessionId,
        correlationId: typed.correlationId,
        tags: typed.tags,
        fromUserId: typed.fromUserId,
        toUserId: typed.toUserId,
        fromUsername: typed.fromUsername,
        toUsername: typed.toUsername,
      );
    }
    if (event is ProfileUpdatedEvent) {
      final typed = event as ProfileUpdatedEvent;
      return ProfileUpdatedEvent(
        id: replayId,
        timestamp: replayTimestamp,
        sessionId: typed.sessionId,
        correlationId: typed.correlationId,
        tags: typed.tags,
        userId: typed.userId,
      );
    }
    if (event is CamViewEvent) {
      final typed = event as CamViewEvent;
      return CamViewEvent(
        id: replayId,
        timestamp: replayTimestamp,
        sessionId: typed.sessionId,
        correlationId: typed.correlationId,
        tags: typed.tags,
        viewerId: typed.viewerId,
        targetUserId: typed.targetUserId,
      );
    }

    throw StateError('Unsupported event replay type: $eventType');
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'sequence': sequence,
        'eventId': eventId,
        'eventType': eventType,
        'recordedAt': recordedAt.toIso8601String(),
        'eventTimestamp': event.timestamp.toIso8601String(),
        'sessionId': sessionId,
        'correlationId': correlationId,
        'tags': tags,
        'isReplay': isReplay,
        'dropped': dropped,
        'note': note,
        'payload': payload,
        'consumerTraces': consumerTraces
            .map((trace) => trace.toJson())
            .toList(growable: false),
      };
}

class AppEventInspector extends ChangeNotifier {
  AppEventInspector._();

  static final AppEventInspector instance = AppEventInspector._();
  static const int _maxEntries = 120;

  final List<EventInspectorEntry> _entries = <EventInspectorEntry>[];
  int _sequence = 0;

  List<EventInspectorEntry> get entries =>
      List<EventInspectorEntry>.unmodifiable(_entries.reversed);

  EventInspectorEntry? get latest => _entries.isEmpty ? null : _entries.last;

  void recordEmission(AppEvent event, {bool isReplay = false}) {
    _entries.add(
      EventInspectorEntry(
        sequence: ++_sequence,
        event: event,
        recordedAt: DateTime.now(),
        isReplay: isReplay,
        note: isReplay ? 'manual_replay' : null,
      ),
    );
    _trim();
    notifyListeners();
  }

  void markDropped(AppEvent event, {String reason = 'duplicate_event_id'}) {
    _updateLatest(
      event.id,
      (entry) => entry.copyWith(
        dropped: true,
        note: reason,
        consumerTraces: <EventConsumerTrace>[
          ...entry.consumerTraces,
          EventConsumerTrace(
            consumer: 'pipeline',
            status: 'dropped',
            recordedAt: DateTime.now(),
            message: reason,
          ),
        ],
      ),
    );
  }

  void markConsumerStart(String eventId, {required String consumer}) {
    _appendTrace(
      eventId,
      EventConsumerTrace(
        consumer: consumer,
        status: 'start',
        recordedAt: DateTime.now(),
      ),
    );
  }

  void markConsumerSuccess(String eventId, {required String consumer}) {
    _appendTrace(
      eventId,
      EventConsumerTrace(
        consumer: consumer,
        status: 'success',
        recordedAt: DateTime.now(),
      ),
    );
  }

  void markConsumerFailure(
    String eventId, {
    required String consumer,
    String? message,
  }) {
    _appendTrace(
      eventId,
      EventConsumerTrace(
        consumer: consumer,
        status: 'failure',
        recordedAt: DateTime.now(),
        message: message,
      ),
    );
  }

  String exportJson() {
    return const JsonEncoder.withIndent(
      '  ',
    ).convert(entries.map((entry) => entry.toJson()).toList(growable: false));
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  void _appendTrace(String eventId, EventConsumerTrace trace) {
    _updateLatest(
      eventId,
      (entry) => entry.copyWith(
        consumerTraces: <EventConsumerTrace>[...entry.consumerTraces, trace],
      ),
    );
  }

  void _updateLatest(
    String eventId,
    EventInspectorEntry Function(EventInspectorEntry entry) updater,
  ) {
    for (var index = _entries.length - 1; index >= 0; index -= 1) {
      final entry = _entries[index];
      if (entry.eventId == eventId) {
        _entries[index] = updater(entry);
        notifyListeners();
        return;
      }
    }
  }

  void _trim() {
    if (_entries.length <= _maxEntries) {
      return;
    }
    _entries.removeRange(0, _entries.length - _maxEntries);
  }
}

Map<String, Object?> _payloadForEvent(AppEvent event) {
  if (event is RoomJoinedEvent) {
    return <String, Object?>{
      'userId': event.userId,
      'roomId': event.roomId,
      'roomName': event.roomName,
    };
  }
  if (event is RoomLeftEvent) {
    return <String, Object?>{
      'userId': event.userId,
      'roomId': event.roomId,
      'roomName': event.roomName,
    };
  }
  if (event is MicStateChangedEvent) {
    return <String, Object?>{
      'userId': event.userId,
      'roomId': event.roomId,
      'isSpeaker': event.isSpeaker,
    };
  }
  if (event is CameraStateChangedEvent) {
    return <String, Object?>{
      'userId': event.userId,
      'roomId': event.roomId,
      'isCameraOn': event.isCameraOn,
    };
  }
  if (event is FollowEvent) {
    return <String, Object?>{
      'fromUserId': event.fromUserId,
      'toUserId': event.toUserId,
      'fromUsername': event.fromUsername,
      'toUsername': event.toUsername,
    };
  }
  if (event is ProfileUpdatedEvent) {
    return <String, Object?>{'userId': event.userId};
  }
  if (event is CamViewEvent) {
    return <String, Object?>{
      'viewerId': event.viewerId,
      'targetUserId': event.targetUserId,
    };
  }
  return <String, Object?>{};
}

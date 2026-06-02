import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'schema_friend_selection_provider.dart';

enum SchemaBootTimelineLevel { info, warning, error }

class SchemaBootTimelineEvent {
  const SchemaBootTimelineEvent({
    required this.timestamp,
    required this.bootId,
    required this.source,
    required this.phase,
    required this.level,
    required this.message,
  });

  final DateTime timestamp;
  final String bootId;
  final SchemaConversationBootSource source;
  final SchemaConversationBootPhase phase;
  final SchemaBootTimelineLevel level;
  final String message;
}

class SchemaBootTimelineNotifier
    extends StateNotifier<List<SchemaBootTimelineEvent>> {
  SchemaBootTimelineNotifier() : super(const <SchemaBootTimelineEvent>[]);

  static const int _maxEvents = 80;

  void record(SchemaBootTimelineEvent event) {
    if (state.isNotEmpty) {
      final previous = state.last;
      final isDuplicate = previous.bootId == event.bootId &&
          previous.source == event.source &&
          previous.phase == event.phase &&
          previous.level == event.level &&
          previous.message == event.message;
      if (isDuplicate) {
        return;
      }
    }

    final next = <SchemaBootTimelineEvent>[...state, event];
    if (next.length <= _maxEvents) {
      state = next;
      return;
    }

    state = next.sublist(next.length - _maxEvents);
  }

  void clear() {
    state = const <SchemaBootTimelineEvent>[];
  }
}

final schemaBootTimelineProvider = StateNotifierProvider<
    SchemaBootTimelineNotifier,
    List<SchemaBootTimelineEvent>>((ref) => SchemaBootTimelineNotifier());

class SchemaBootMetrics {
  const SchemaBootMetrics({
    required this.bootId,
    required this.source,
    required this.eventCount,
    required this.phaseCount,
    required this.startedAt,
    required this.endedAt,
  });

  final String bootId;
  final SchemaConversationBootSource source;
  final int eventCount;
  final int phaseCount;
  final DateTime startedAt;
  final DateTime endedAt;

  Duration get duration => endedAt.difference(startedAt);
}

final schemaLatestBootMetricsProvider = Provider<SchemaBootMetrics?>((ref) {
  final events = ref.watch(schemaBootTimelineProvider);
  if (events.isEmpty) {
    return null;
  }

  final lastBootId = events.last.bootId;
  final bootEvents = events
      .where((event) => event.bootId == lastBootId && event.bootId != 'none')
      .toList(growable: false);
  if (bootEvents.isEmpty) {
    return null;
  }

  final phaseNames = bootEvents.map((event) => event.phase.name).toSet();

  return SchemaBootMetrics(
    bootId: lastBootId,
    source: bootEvents.first.source,
    eventCount: bootEvents.length,
    phaseCount: phaseNames.length,
    startedAt: bootEvents.first.timestamp,
    endedAt: bootEvents.last.timestamp,
  );
});

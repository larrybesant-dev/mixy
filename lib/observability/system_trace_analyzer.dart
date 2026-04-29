import 'system_event_bus.dart';

class SystemTraceSummary {
  const SystemTraceSummary({
    required this.coldStartMs,
    required this.timeline,
    required this.anomalies,
    required this.routeFinalStates,
  });

  final int coldStartMs;
  final List<Map<String, dynamic>> timeline;
  final List<String> anomalies;
  final List<Map<String, dynamic>> routeFinalStates;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'coldStartMs': coldStartMs,
      'timeline': timeline,
      'anomalies': anomalies,
      'routeFinalStates': routeFinalStates,
    };
  }
}

class SystemTraceAnalyzer {
  const SystemTraceAnalyzer();

  SystemTraceSummary analyze(List<SystemEvent> rawEvents) {
    if (rawEvents.isEmpty) {
      return const SystemTraceSummary(
        coldStartMs: 0,
        timeline: <Map<String, dynamic>>[],
        anomalies: <String>[],
        routeFinalStates: <Map<String, dynamic>>[],
      );
    }

    final events = List<SystemEvent>.from(rawEvents)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final baseTime = events.first.timestamp;
    final timeline = <Map<String, dynamic>>[];
    final anomalies = <String>[];
    final routeFinalStates = <Map<String, dynamic>>[];

    DateTime? startupMainStart;
    DateTime? authStableAt;
    DateTime? bootCompleteAt;

    final attachedConversations = <String, int>{};
    final hydrationComplete = <String>{};

    for (final event in events) {
      final meta = event.meta ?? const <String, dynamic>{};
      final deltaMs = event.timestamp.difference(baseTime).inMilliseconds;
      timeline.add(<String, dynamic>{
        't': deltaMs,
        'event': _timelineLabel(event),
      });

      if (event.type == 'STARTUP_CHECKPOINT' &&
          meta['checkpoint'] == 'mainStart') {
        startupMainStart ??= event.timestamp;
      }

      if (event.type == 'STARTUP_CHECKPOINT' &&
          meta['checkpoint'] == 'bootstrapResolved') {
        bootCompleteAt ??= event.timestamp;
      }

      if (event.type == 'AUTH_STABLE') {
        authStableAt ??= event.timestamp;
      }

      if (event.type == 'HYDRATION_START' && authStableAt == null) {
        anomalies.add('HYDRATION_START before AUTH_STABLE');
      }

      if (event.type == 'ROUTE_REDIRECT' && bootCompleteAt == null) {
        anomalies.add('ROUTE_REDIRECT before BOOT_COMPLETE');
      }

      if (event.type == 'MESSAGE_STREAM_ATTACHED') {
        final conversationId = (meta['conversationId'] ?? '').toString();
        if (conversationId.isNotEmpty) {
          final count = attachedConversations[conversationId] ?? 0;
          if (count > 0) {
            anomalies.add(
              'duplicate MESSAGE_STREAM_ATTACHED without DISPOSE for $conversationId',
            );
          }
          attachedConversations[conversationId] = count + 1;
        }
      }

      if (event.type == 'MESSAGE_STREAM_DISPOSE') {
        final conversationId = (meta['conversationId'] ?? '').toString();
        if (conversationId.isNotEmpty) {
          final count = attachedConversations[conversationId] ?? 0;
          if (count <= 1) {
            attachedConversations.remove(conversationId);
          } else {
            attachedConversations[conversationId] = count - 1;
          }
        }
      }

      if (event.type == 'HYDRATION_COMPLETE') {
        final conversationId = (meta['conversationId'] ?? '').toString();
        if (conversationId.isNotEmpty) {
          hydrationComplete.add(conversationId);
        }
      }

      if (event.type == 'HYDRATION_EMPTY_STATE') {
        final conversationId = (meta['conversationId'] ?? '').toString();
        if (conversationId.isNotEmpty && !hydrationComplete.contains(conversationId)) {
          anomalies.add('empty-state rendered before HYDRATION_COMPLETE for $conversationId');
        }
      }

      if (event.type == 'STRESS_ROUTE_FINAL') {
        routeFinalStates.add(<String, dynamic>{
          'requestedRoute': meta['requestedRoute'],
          'finalRoute': meta['finalRoute'],
          'durationMs': meta['durationMs'],
        });
      }
    }

    final coldStartMs = startupMainStart == null || authStableAt == null
        ? 0
        : authStableAt.difference(startupMainStart).inMilliseconds;

    return SystemTraceSummary(
      coldStartMs: coldStartMs,
      timeline: timeline,
      anomalies: anomalies.toSet().toList(growable: false),
      routeFinalStates: routeFinalStates,
    );
  }

  String _timelineLabel(SystemEvent event) {
    final meta = event.meta ?? const <String, dynamic>{};
    switch (event.type) {
      case 'ROUTE_REDIRECT':
        return 'ROUTE:${meta['to'] ?? 'unknown'}';
      case 'STRESS_ROUTE_START':
        return 'ROUTE:${meta['requestedRoute'] ?? 'unknown'}';
      case 'HYDRATION_START':
      case 'HYDRATION_COMPLETE':
      case 'HYDRATION_EMPTY_STATE':
      case 'AUTH_BOOT_START':
      case 'AUTH_STABLE':
        return event.type;
      case 'STARTUP_CHECKPOINT':
        return 'STARTUP:${meta['checkpoint'] ?? 'unknown'}';
      default:
        return event.type;
    }
  }
}

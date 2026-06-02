import 'package:flutter/foundation.dart';

import '../../observability/system_event_bus.dart';

class RedirectTrace {
  RedirectTrace._();

  static final String _sessionId =
      DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  static int _redirectIndex = 0;

  static final Map<String, int> _reasonCounts = <String, int>{};
  static String? _lastSignature;
  static int _lastSignatureRepeatCount = 0;

  static void record({
    required String from,
    required String to,
    required String reason,
  }) {
    _redirectIndex += 1;
    _reasonCounts[reason] = (_reasonCounts[reason] ?? 0) + 1;

    SystemEventBus.instance.emit(
      SystemEvent(
        type: 'ROUTE_REDIRECT',
        timestamp: DateTime.now(),
        meta: <String, dynamic>{
          'from': from,
          'to': to,
          'reason': reason,
          'index': _redirectIndex,
          'sessionId': _sessionId,
        },
      ),
    );

    final signature = '$from|$to|$reason';
    if (_lastSignature == signature) {
      _lastSignatureRepeatCount += 1;
      if (_lastSignatureRepeatCount % 25 != 0) {
        return;
      }
    } else {
      _lastSignature = signature;
      _lastSignatureRepeatCount = 1;
    }

    debugPrint(
      '[ROUTER][REDIRECT][session=$_sessionId #$_redirectIndex] '
      'from=$from to=$to reason=$reason',
    );

    if (_redirectIndex % 20 == 0) {
      final summary = topReasons(
        limit: 3,
      ).map((entry) => '${entry.key}:${entry.value}').join(', ');
      debugPrint('[ROUTER][REDIRECT][session=$_sessionId] topReasons=$summary');
    }
  }

  @visibleForTesting
  static void resetForTests() {
    _redirectIndex = 0;
    _reasonCounts.clear();
    _lastSignature = null;
    _lastSignatureRepeatCount = 0;
  }

  @visibleForTesting
  static List<MapEntry<String, int>> topReasons({int limit = 3}) {
    final sorted = _reasonCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.length <= limit) {
      return sorted;
    }
    return sorted.sublist(0, limit);
  }
}

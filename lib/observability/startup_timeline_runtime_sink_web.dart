import 'dart:convert';
import 'dart:collection';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const String _timelineKey = 'startupLogs';
const String _appReadyContractKey = 'startupAppReadyContract';
const String _contractVersion = 'mixvy.startup.app_ready.v1';

String? _checkpointFromMessage(String message) {
  final match = RegExp(r'startup\.([A-Za-z0-9_]+)').firstMatch(message);
  return match?.group(1);
}

void _updateAppReadyContract(String message) {
  final checkpoint = _checkpointFromMessage(message);
  if (checkpoint == null || checkpoint.isEmpty) {
    return;
  }

  final storage = web.window.sessionStorage;
  Map<String, dynamic> contract = <String, dynamic>{
    'contractVersion': _contractVersion,
    'ready': false,
    'checkpoints': <String, dynamic>{},
  };

  final existingRaw = storage.getItem(_appReadyContractKey);
  if (existingRaw != null && existingRaw.isNotEmpty) {
    try {
      final decoded = jsonDecode(existingRaw);
      if (decoded is Map<String, dynamic>) {
        contract = decoded;
      }
    } catch (_) {
      // Ignore malformed existing payloads and overwrite with canonical shape.
    }
  }

  final checkpoints = <String, dynamic>{
    ...?((contract['checkpoints'] as Map?)?.cast<String, dynamic>()),
  };
  checkpoints[checkpoint] = message;
  final sortedCheckpoints = SplayTreeMap<String, dynamic>.from(checkpoints);

  final ready = checkpoint == 'firstFrameRendered' || contract['ready'] == true;

  final next = <String, dynamic>{
    'contractVersion': _contractVersion,
    'ready': ready,
    'readyCheckpoint': ready ? 'firstFrameRendered' : 'pending',
    'checkpoints': sortedCheckpoints,
  };

  storage.setItem(_appReadyContractKey, jsonEncode(next));
}

void emitStartupMessageToRuntime(String message) {
  web.console.log(message.toJS);

  final storage = web.window.sessionStorage;
  final existing = storage.getItem(_timelineKey);
  final next = (existing == null || existing.isEmpty)
      ? message
      : '$existing\n$message';
  storage.setItem(_timelineKey, next);

  _updateAppReadyContract(message);
}




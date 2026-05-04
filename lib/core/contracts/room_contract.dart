// Central contract layer for the room feature.
//
// ALL room state shapes, validation rules, and schema guards live here.
// UI and providers import from this file — never from each other directly.
//
// When Firestore schema changes, update this file first.
// Compiler errors that cascade from here are intentional: they tell you
// exactly which consumers need to be updated.
//
// MAPPER PIPELINE (3 pure stages — keeps fromFirestore from becoming a monolith):
//
//   Stage 1 — RoomSchemaValidator.validate()
//     Raw Firestore doc → validated (throws on bad shape, logs failure surface)
//
//   Stage 2 — RoomDocNormalizer.normalize()
//     Validated raw doc → RoomNormalizedDoc (typed, null-safe intermediate)
//
//   Stage 3 — RoomLiveStateMapper.fromNormalized()
//     RoomNormalizedDoc + slice data → RoomLiveState
//
// Add complexity to Stage 2 (schema evolution). Keep Stage 3 pure assembly.

import 'package:flutter/foundation.dart';
import 'package:mixvy/features/messaging/models/message_model.dart';
import 'package:mixvy/models/room_participant_model.dart';
import 'package:mixvy/features/room/providers/presence_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCHEMA VERSION
// Bump when Firestore schema changes in a breaking way.
// Mapper uses this to select the correct normalization path.
// ─────────────────────────────────────────────────────────────────────────────

const int kRoomSchemaVersion = 1;

// ─────────────────────────────────────────────────────────────────────────────
// CONTRACT INTERFACE
// Every screen/widget that reads room data must depend on this, not on the
// concrete RoomLiveState directly.
// ─────────────────────────────────────────────────────────────────────────────

abstract class RoomStateContract {
  String get title;
  List<MessageModel> get message;
  Map<String, bool> get typingUsers;
  List<RoomParticipantModel> get participants;
  List<RoomPresenceModel> get presence;
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGE 2 INTERMEDIATE: RoomNormalizedDoc
// Output of normalization, input to final assembly.
// Null-safe typed fields extracted from the raw Firestore map.
// ─────────────────────────────────────────────────────────────────────────────

class RoomNormalizedDoc {
  final String title;
  final int schemaVersion;
  final Map<String, dynamic> rawDoc;

  const RoomNormalizedDoc({
    required this.title,
    required this.schemaVersion,
    required this.rawDoc,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CONCRETE STATE
// Implements the contract. The only place nullable/raw fields exist.
// ─────────────────────────────────────────────────────────────────────────────

class RoomLiveState implements RoomStateContract {
  @override
  final String title;
  @override
  final List<MessageModel> message;
  @override
  final Map<String, bool> typingUsers;
  @override
  final List<RoomParticipantModel> participants;
  @override
  final List<RoomPresenceModel> presence;

  /// Raw Firestore document — available for diagnostics only.
  /// UI must NOT read directly from this. Use the typed fields above.
  final Map<String, dynamic> roomDoc;

  const RoomLiveState({
    required this.title,
    required this.message,
    required this.typingUsers,
    required this.participants,
    required this.presence,
    required this.roomDoc,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGE 1: SCHEMA VALIDATOR
// Rejects malformed Firestore documents before they reach the mapper.
// Throws RoomSchemaException with full failure surface:
//   roomId, doc key count, and which keys are missing.
// ─────────────────────────────────────────────────────────────────────────────

class RoomSchemaException implements Exception {
  final String roomId;
  final String message;
  final List<String> missingKeys;
  final int docKeyCount;

  const RoomSchemaException({
    required this.roomId,
    required this.message,
    required this.missingKeys,
    required this.docKeyCount,
  });

  @override
  String toString() =>
      '[RoomSchemaException] $message '
      '| roomId=$roomId '
      '| docKeys=$docKeyCount '
      '| missing=$missingKeys';
}

class RoomSchemaValidator {
  static const _requiredRootKeys = ['meta'];
  static const _requiredMetaKeys = ['title'];

  static void validate(Map<String, dynamic>? roomDoc, {String roomId = ''}) {
    if (roomDoc == null || roomDoc.isEmpty) {
      throw RoomSchemaException(
        roomId: roomId,
        message: 'Room document is null or empty',
        missingKeys: _requiredRootKeys,
        docKeyCount: 0,
      );
    }

    final missingRoot = _requiredRootKeys
        .where((k) => !roomDoc.containsKey(k))
        .toList();

    if (missingRoot.isNotEmpty) {
      throw RoomSchemaException(
        roomId: roomId,
        message: 'Room document missing required root keys',
        missingKeys: missingRoot,
        docKeyCount: roomDoc.length,
      );
    }

    final meta = roomDoc['meta'];
    if (meta is! Map<String, dynamic>) {
      throw RoomSchemaException(
        roomId: roomId,
        message: "Room 'meta' is not a valid map",
        missingKeys: _requiredMetaKeys,
        docKeyCount: roomDoc.length,
      );
    }

    final missingMeta = _requiredMetaKeys
        .where((k) => !meta.containsKey(k))
        .toList();

    if (missingMeta.isNotEmpty) {
      throw RoomSchemaException(
        roomId: roomId,
        message: 'Room meta missing required keys',
        missingKeys: missingMeta,
        docKeyCount: meta.length,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGE 2: NORMALIZER
// Extracts typed, null-safe fields from a validated raw doc.
// Add schema versioning / migration logic here as Firestore evolves.
// ─────────────────────────────────────────────────────────────────────────────

class RoomDocNormalizer {
  static RoomNormalizedDoc normalize(Map<String, dynamic> validatedDoc) {
    final meta = validatedDoc['meta'] as Map<String, dynamic>;
    final schemaVersion =
        (validatedDoc['schemaVersion'] as int?) ?? kRoomSchemaVersion;

    if (schemaVersion != kRoomSchemaVersion) {
      debugPrint(
        '[RoomDocNormalizer] schema version mismatch: '
        'expected=$kRoomSchemaVersion actual=$schemaVersion — using current mapper',
      );
    }

    return RoomNormalizedDoc(
      title: (meta['title'] as String?) ?? '',
      schemaVersion: schemaVersion,
      rawDoc: validatedDoc,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE DIFF SNAPSHOT
// Produced on every verify() call. Captures exactly what changed between
// the previous emission and the current one.
//
// Makes UI flicker, phantom rebuilds, and presence glitches immediately
// traceable — each anomaly maps to a concrete diff field, not just a log line.
//
// Access the last computed diff at any time via RoomContractGuard.lastDiff.
// ─────────────────────────────────────────────────────────────────────────────

class RoomStateDiff {
  final bool titleChanged;
  final int messageCountDelta;
  final int participantCountDelta;
  final int typingCountDelta;
  final bool hasChanges;

  const RoomStateDiff({
    required this.titleChanged,
    required this.messageCountDelta,
    required this.participantCountDelta,
    required this.typingCountDelta,
    required this.hasChanges,
  });

  /// Sentinel for the first emission — no previous state to compare against.
  const RoomStateDiff.initial()
    : titleChanged = false,
      messageCountDelta = 0,
      participantCountDelta = 0,
      typingCountDelta = 0,
      hasChanges = false;

  /// Compute diff between two consecutive state emissions.
  factory RoomStateDiff.between(
    RoomStateContract prev,
    RoomStateContract curr,
  ) {
    final titleChanged = prev.title != curr.title;
    final msgDelta = curr.message.length - prev.message.length;
    final partDelta = curr.participants.length - prev.participants.length;
    final typDelta = curr.typingUsers.length - prev.typingUsers.length;

    return RoomStateDiff(
      titleChanged: titleChanged,
      messageCountDelta: msgDelta,
      participantCountDelta: partDelta,
      typingCountDelta: typDelta,
      hasChanges:
          titleChanged || msgDelta != 0 || partDelta != 0 || typDelta != 0,
    );
  }

  /// Human-readable summary for log lines and debug overlays.
  /// Returns 'no_change' when nothing changed (safe to log unconditionally).
  String get summary {
    if (!hasChanges) return 'no_change';
    final parts = <String>[];
    if (titleChanged) parts.add('title_changed');
    if (messageCountDelta != 0) {
      parts.add(
        'message${messageCountDelta > 0 ? "+$messageCountDelta" : "$messageCountDelta"}',
      );
    }
    if (participantCountDelta != 0) {
      parts.add(
        'participants${participantCountDelta > 0 ? "+$participantCountDelta" : "$participantCountDelta"}',
      );
    }
    if (typingCountDelta != 0) {
      parts.add(
        'typing${typingCountDelta > 0 ? "+$typingCountDelta" : "$typingCountDelta"}',
      );
    }
    return parts.join(' | ');
  }

  @override
  String toString() => '[RoomStateDiff] $summary';
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTRACT GUARD
// Anomaly detector, not a spam logger.
//
// - verify() computes a RoomStateDiff against the previous state.
// - Logs only when hasChanges is true.
// - lastDiff is always the most recent diff — accessible to debug overlays
//   or tests without re-computing.
// - Zero-cost asserts in release builds (stripped by Dart compiler).
// ─────────────────────────────────────────────────────────────────────────────

class RoomContractGuard {
  static RoomStateContract? _prevState;
  static RoomStateDiff _lastDiff = const RoomStateDiff.initial();

  /// The diff produced by the most recent verify() call.
  /// `initial()` sentinel until the second emission arrives.
  static RoomStateDiff get lastDiff => _lastDiff;

  static void verify(RoomStateContract state) {
    assert(
      // ignore: unnecessary_type_check
      state.message is List,
      'RoomContractGuard: message was replaced with a non-List',
    );
    assert(
      // ignore: unnecessary_type_check
      state.typingUsers is Map,
      'RoomContractGuard: typingUsers was replaced with a non-Map',
    );

    final prev = _prevState;
    _prevState = state;

    if (prev == null) {
      // First emission — baseline only, nothing to diff against.
      debugPrint(
        '[RoomContractGuard] initial '
        '| title="${state.title}" '
        '| message=${state.message.length} '
        '| participants=${state.participants.length} '
        '| typing=${state.typingUsers.length}',
      );
      _lastDiff = const RoomStateDiff.initial();
      return;
    }

    final diff = RoomStateDiff.between(prev, state);
    _lastDiff = diff;

    if (diff.hasChanges) {
      debugPrint('[RoomContractGuard] ${diff.summary}');
    }
  }

  /// Call when navigating away from a room to reset the change detector.
  static void reset() {
    _prevState = null;
    _lastDiff = const RoomStateDiff.initial();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGE 3: MAPPER (final assembly)
// Assembles RoomLiveState from normalized doc + slice provider data.
// Should stay thin — no conditional logic, no Firestore knowledge.
// ─────────────────────────────────────────────────────────────────────────────

class RoomLiveStateMapper {
  /// Entry point called by roomLiveStateProvider.
  static RoomLiveState fromFirestore({
    required Map<String, dynamic>? roomDoc,
    required List<RoomParticipantModel> participants,
    required List<RoomPresenceModel> presence,
    required List<MessageModel> messagePreview,
    required Map<String, bool> typing,
    String roomId = '',
  }) {
    // Stage 1 — validate raw doc structure
    RoomSchemaValidator.validate(roomDoc, roomId: roomId);

    // Stage 2 — normalize to typed intermediate
    final normalized = RoomDocNormalizer.normalize(roomDoc!);

    // Stage 3 — assemble final state
    return fromNormalized(
      normalized: normalized,
      participants: participants,
      presence: presence,
      message: messagePreview,
      typingUsers: typing,
    );
  }

  /// Pure assembly: normalized doc + slice data → RoomLiveState.
  /// Can be called independently for testing.
  static RoomLiveState fromNormalized({
    required RoomNormalizedDoc normalized,
    required List<RoomParticipantModel> participants,
    required List<RoomPresenceModel> presence,
    required List<MessageModel> message,
    required Map<String, bool> typingUsers,
  }) {
    final state = RoomLiveState(
      title: normalized.title,
      message: message,
      typingUsers: typingUsers,
      participants: participants,
      presence: presence,
      roomDoc: normalized.rawDoc,
    );

    RoomContractGuard.verify(state);

    return state;
  }
}

// Room Join Verification Utility
//
// Helps diagnose room joining permission issues during development/testing
// by validating room accessibility and user permissions before join attempts.

import 'package:cloud_firestore/cloud_firestore.dart';

class RoomJoinVerification {
  static Future<RoomJoinCheckResult> verifyRoomJoinability({
    required FirebaseFirestore firestore,
    required String roomId,
    required String userId,
  }) async {
    final result = RoomJoinCheckResult(roomId: roomId, userId: userId);

    // Step 1: Verify room exists
    final roomDoc = await firestore.collection('rooms').doc(roomId).get();
    result.roomExists = roomDoc.exists;
    if (!roomDoc.exists) {
      result.errors.add('Room does not exist');
      return result;
    }
    result.roomData = roomDoc.data();

    // Step 2: Check if room is adult-only
    final isAdult = (roomDoc.data() ?? {})['isAdult'] as bool?;
    result.isAdultRoom = isAdult ?? false;
    if (result.isAdultRoom) {
      result.warnings.add('Room is marked as adult-only');
    }

    // Step 3: Verify user is not already banned at room level
    final isBannedAtRoom =
        (roomDoc.data()?['bannedUsers'] as List?)?.contains(userId) ?? false;
    result.isBannedAtRoom = isBannedAtRoom;
    if (isBannedAtRoom) {
      result.errors.add('User is banned from this room');
    }

    // Step 4: Check if participant doc already exists
    final participantDoc = await firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(userId)
        .get();
    result.participantDocExists = participantDoc.exists;
    if (participantDoc.exists) {
      final isBanned = (participantDoc.data()?['isBanned'] as bool?) ?? false;
      result.participantIsBanned = isBanned;
      if (isBanned) {
        result.errors.add('User is banned from this room (participant record)');
      }
      result.participantData = participantDoc.data();
    }

    // Step 5: Check for blocking relationships
    // (This would require reading user documents and checking block lists)
    result.blockingCheckSkipped = 'Manual verification required in Dart code';

    return result;
  }
}

class RoomJoinCheckResult {
  RoomJoinCheckResult({
    required this.roomId,
    required this.userId,
  });

  final String roomId;
  final String userId;

  bool roomExists = false;
  bool isAdultRoom = false;
  bool isBannedAtRoom = false;
  bool participantDocExists = false;
  bool participantIsBanned = false;
  String? blockingCheckSkipped;

  Map<String, dynamic>? roomData;
  Map<String, dynamic>? participantData;

  final List<String> errors = <String>[];
  final List<String> warnings = <String>[];

  bool get canJoin =>
      errors.isEmpty && roomExists && !isBannedAtRoom && !participantIsBanned;

  String get diagnosticSummary {
    final buffer = StringBuffer();
    buffer.writeln('=== Room Join Diagnostic ===');
    buffer.writeln('Room ID: $roomId');
    buffer.writeln('User ID: $userId');
    buffer.writeln('Can Join: ${canJoin ? "✓ YES" : "✗ NO"}');
    buffer.writeln('');
    buffer.writeln('Status Checks:');
    buffer.writeln('  - Room exists: ${roomExists ? "✓" : "✗"}');
    buffer.writeln('  - Room is adult: ${isAdultRoom ? "⚠" : "✓"}');
    buffer.writeln('  - User banned at room: ${isBannedAtRoom ? "✗" : "✓"}');
    buffer.writeln('  - Participant doc exists: ${participantDocExists ? "✓" : "○"}');
    buffer.writeln('  - User banned in participant doc: ${participantIsBanned ? "✗" : "✓"}');
    if (errors.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Errors:');
      for (final error in errors) {
        buffer.writeln('  ✗ $error');
      }
    }
    if (warnings.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Warnings:');
      for (final warning in warnings) {
        buffer.writeln('  ⚠ $warning');
      }
    }
    return buffer.toString();
  }
}

import 'package:flutter/material.dart';
class FriendParitySnapshot {
  const FriendParitySnapshot({
    required this.legacyIdsOrdered,
    required this.schemaIdsOrdered,
    required this.legacyOnlineIds,
    required this.schemaOnlineIds,
    required this.legacyReady,
    required this.schemaReady,
    required this.schemaPresenceReady,
  });

  final List<String> legacyIdsOrdered;
  final List<String> schemaIdsOrdered;
  final Set<String> legacyOnlineIds;
  final Set<String> schemaOnlineIds;
  final bool legacyReady;
  final bool schemaReady;
  final bool schemaPresenceReady;
}

class FriendParityResult {
  const FriendParityResult({
    required this.isComparable,
    required this.isMatch,
    required this.reason,
    required this.missingInSchema,
    required this.missingInLegacy,
    required this.statusMismatches,
    required this.legacyOrderHash,
    required this.schemaOrderHash,
    required this.paritySignature,
  });

  final bool isComparable;
  final bool isMatch;
  final String reason;
  final List<String> missingInSchema;
  final List<String> missingInLegacy;
  final List<String> statusMismatches;
  final int legacyOrderHash;
  final int schemaOrderHash;
  final String paritySignature;
}

FriendParityResult evaluateFriendParity(FriendParitySnapshot snapshot) {
  if (!snapshot.legacyReady ||
      !snapshot.schemaReady ||
      !snapshot.schemaPresenceReady) {
    return const FriendParityResult(
      isComparable: false,
      isMatch: true,
      reason: 'loading',
      missingInSchema: <String>[],
      missingInLegacy: <String>[],
      statusMismatches: <String>[],
      legacyOrderHash: 0,
      schemaOrderHash: 0,
      paritySignature: 'loading',
    );
  }

  final legacyIds = snapshot.legacyIdsOrdered.toSet();
  final schemaIds = snapshot.schemaIdsOrdered.toSet();

  final missingInSchema = snapshot.legacyIdsOrdered
      .where((id) => !schemaIds.contains(id))
      .toList(growable: false);
  final missingInLegacy = snapshot.schemaIdsOrdered
      .where((id) => !legacyIds.contains(id))
      .toList(growable: false);

  final comparableIds = snapshot.legacyIdsOrdered
      .where((id) => schemaIds.contains(id))
      .toList(growable: false);

  final statusMismatches = comparableIds
      .where(
        (id) =>
            snapshot.legacyOnlineIds.contains(id) !=
            snapshot.schemaOnlineIds.contains(id),
      )
      .toList(growable: false);

  final legacyOrderHash = snapshot.legacyIdsOrdered.join('|').hashCode;
  final schemaOrderHash = snapshot.schemaIdsOrdered.join('|').hashCode;

  final isMatch =
      missingInSchema.isEmpty &&
      missingInLegacy.isEmpty &&
      statusMismatches.isEmpty &&
      legacyOrderHash == schemaOrderHash;

  final signature = [
    'legacy:${snapshot.legacyIdsOrdered.join(',')}',
    'schema:${snapshot.schemaIdsOrdered.join(',')}',
    'misS:${missingInSchema.join(',')}',
    'misL:${missingInLegacy.join(',')}',
    'status:${statusMismatches.join(',')}',
    'hL:$legacyOrderHash',
    'hS:$schemaOrderHash',
  ].join('|');

  return FriendParityResult(
    isComparable: true,
    isMatch: isMatch,
    reason: isMatch ? 'match' : 'mismatch',
    missingInSchema: missingInSchema,
    missingInLegacy: missingInLegacy,
    statusMismatches: statusMismatches,
    legacyOrderHash: legacyOrderHash,
    schemaOrderHash: schemaOrderHash,
    paritySignature: signature,
  );
}





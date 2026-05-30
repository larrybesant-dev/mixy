import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../friends/parity/friend_parity_validator.dart';
import '../../friends/providers/schema_friend_links_providers.dart';
import '../../messages/messages_consistency_contract.dart';
import '../../../friends/providers/friends_providers.dart';
import '../../../messaging/providers/messaging_provider.dart';
import '../../../../presentation/providers/user_provider.dart';

class SchemaParityMonitorReport {
  const SchemaParityMonitorReport({
    required this.moduleId,
    required this.isComparable,
    required this.isMatch,
    required this.signature,
    required this.missingInSchema,
    required this.missingInLegacy,
    required this.mismatchDetails,
  });

  final String moduleId;
  final bool isComparable;
  final bool isMatch;
  final String signature;
  final List<String> missingInSchema;
  final List<String> missingInLegacy;
  final List<String> mismatchDetails;

  int get mismatchCount =>
      missingInSchema.length + missingInLegacy.length + mismatchDetails.length;
}

final schemaParityMonitorProvider = Provider.autoDispose
    .family<SchemaParityMonitorReport, String>((ref, moduleId) {
      if (!kDebugMode) {
        return SchemaParityMonitorReport(
          moduleId: moduleId,
          isComparable: false,
          isMatch: true,
          signature: 'disabled_outside_debug',
          missingInSchema: const <String>[],
          missingInLegacy: const <String>[],
          mismatchDetails: const <String>[],
        );
      }

      switch (moduleId) {
        case 'message':
          final contract = ref.watch(messageConsistencyContractProvider);

          final userId = ref.watch(userProvider)?.id;
          if (userId == null || userId.isEmpty) {
            return const SchemaParityMonitorReport(
              moduleId: 'message',
              isComparable: false,
              isMatch: true,
              signature: 'unauthenticated',
              missingInSchema: <String>[],
              missingInLegacy: <String>[],
              mismatchDetails: <String>[],
            );
          }

          final legacyAsync = ref.watch(conversationsStreamProvider(userId));
          final schemaAsync = ref.watch(conversationsStreamProvider(userId));
          final legacy = legacyAsync.valueOrNull ?? const [];
          final schema = schemaAsync.valueOrNull ?? const [];

          final snapshot = MessageSnapshot(
            legacyConversationIds: legacy
                .map((c) => c.id)
                .toList(growable: false),
            schemaConversationIds: schema
                .map((c) => c.id)
                .toList(growable: false),
            legacyUnreadByConversation: {
              for (final c in legacy) c.id: c.hasUnreadMessages(userId) ? 1 : 0,
            },
            schemaUnreadByConversation: {
              for (final c in schema) c.id: c.hasUnreadMessages(userId) ? 1 : 0,
            },
            legacyReady: legacyAsync.hasValue,
            schemaReady: schemaAsync.hasValue,
          );

          final result = contract.evaluate(snapshot);
          return SchemaParityMonitorReport(
            moduleId: moduleId,
            isComparable: result.isComparable,
            isMatch: result.isMatch,
            signature: result.signature,
            missingInSchema: result.missingInSchema,
            missingInLegacy: result.missingInLegacy,
            mismatchDetails: result.unreadMismatches,
          );
        case 'friends':
          final authUserId = ref.watch(schemaAuthUserIdProvider);
          if (authUserId == null || authUserId.isEmpty) {
            return const SchemaParityMonitorReport(
              moduleId: 'friends',
              isComparable: false,
              isMatch: true,
              signature: 'unauthenticated',
              missingInSchema: <String>[],
              missingInLegacy: <String>[],
              mismatchDetails: <String>[],
            );
          }

          final legacyRosterAsync = ref.watch(friendRosterProvider);
          final schemaLinksAsync = ref.watch(schemaFriendLinksProvider);
          final schemaPresenceMapAsync = ref.watch(
            schemaFriendPresenceMapProvider,
          );

          final legacyRoster = legacyRosterAsync.valueOrNull;
          final schemaAcceptedLinks = ref.watch(
            schemaAcceptedFriendLinksProvider,
          );
          final schemaPresenceMap = schemaPresenceMapAsync.valueOrNull;

          final snapshot = FriendParitySnapshot(
            legacyIdsOrdered:
                legacyRoster
                    ?.map((entry) => entry.friendId)
                    .toList(growable: false) ??
                const <String>[],
            schemaIdsOrdered: schemaAcceptedLinks
                .map((link) => link.otherUserId(authUserId))
                .where((id) => id.isNotEmpty)
                .toList(growable: false),
            legacyOnlineIds:
                legacyRoster
                    ?.where((entry) => entry.isOnline)
                    .map((entry) => entry.friendId)
                    .toSet() ??
                const <String>{},
            schemaOnlineIds:
                schemaPresenceMap?.entries
                    .where((entry) => entry.value.isOnline)
                    .map((entry) => entry.key)
                    .toSet() ??
                const <String>{},
            legacyReady: legacyRosterAsync.hasValue,
            schemaReady: schemaLinksAsync.hasValue,
            schemaPresenceReady: schemaPresenceMapAsync.hasValue,
          );

          final result = evaluateFriendParity(snapshot);
          return SchemaParityMonitorReport(
            moduleId: moduleId,
            isComparable: result.isComparable,
            isMatch: result.isMatch,
            signature: result.paritySignature,
            missingInSchema: result.missingInSchema,
            missingInLegacy: result.missingInLegacy,
            mismatchDetails: result.statusMismatches,
          );
        default:
          return SchemaParityMonitorReport(
            moduleId: moduleId,
            isComparable: false,
            isMatch: false,
            signature: 'unsupported:$moduleId',
            missingInSchema: const <String>[],
            missingInLegacy: const <String>[],
            mismatchDetails: <String>['unsupported_module:$moduleId'],
          );
      }
    });





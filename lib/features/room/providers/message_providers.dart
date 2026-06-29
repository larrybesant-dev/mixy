import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/query_policy.dart';
import '../../../core/firestore/firestore_debug_tracing.dart';
import '../../../core/logger.dart';
import '../../../core/services/feature_gate_service.dart';
import '../../../presentation/providers/user_provider.dart';
import 'package:mixvy/features/messaging/models/message_model.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';
import 'package:mixvy/services/room_service.dart';
import '../../../services/moderation_service.dart';
import 'package:mixvy/features/feed/providers/typing_providers.dart';
import 'room_firestore_provider.dart';

bool _asBool(dynamic value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return fallback;
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return fallback;
}

final pendingDirectCallRoomProvider =
    StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
      final uid = ref.watch(authControllerProvider).uid;
      if (uid == null || uid.trim().isEmpty) {
        return Stream.value(null);
      }

      return ref
          .watch(roomServiceProvider)
          .watchPendingDirectCallForCallee(calleeId: uid)
          .map((roomWithVisibility) {
            if (roomWithVisibility == null) {
              return null;
            }

            final room = roomWithVisibility.room;
            return <String, dynamic>{
              'id': room.id,
              'hostId': room.hostId,
              'ownerName': room.hostUsername ?? room.name,
              'visibilityTier': roomWithVisibility.tier.name,
              'visibilityReason': roomWithVisibility.visibility.reasonCode.name,
            };
          });
    });

final roomMessageStreamProvider = StreamProvider.autoDispose
    .family<List<MessageModel>, String>((ref, roomId) {
      final firestore = ref.watch(roomFirestoreProvider);
      // Only watch the UID instead of the whole userProvider to prevent stream recreation
      // when user profile data changes. This keeps chat messages persistent.
      final currentUserId = ref.watch(
        authControllerProvider.select((auth) => auth.uid),
      );
      return traceFirestoreStream<List<MessageModel>>(
        key: 'messages/$roomId',
        query: 'rooms/$roomId/messages orderBy sentAt',
        roomId: roomId,
        itemCount: (value) => value.length,
        stream: firestore
            .collection('rooms')
            .doc(roomId)
            .collection('messages')
            .orderBy('sentAt')
            .limit(QueryPolicy.messagesLimit)
            .snapshots(includeMetadataChanges: true)
            .map((snapshot) {
              final visibleDocs = snapshot.docs.where((doc) {
                final data = doc.data();
                final recipientUserId = _asString(data['recipientUserId']);
                if (recipientUserId.isEmpty) return true;
                if (currentUserId == null || currentUserId.trim().isEmpty) {
                  return false;
                }
                final senderId = _asString(data['senderId']);
                return senderId == currentUserId ||
                    recipientUserId == currentUserId;
              });

              final messages = visibleDocs.map((doc) {
                final data = doc.data();
                var msg = MessageModel.fromJson(data, doc.id);

                final recipientUserId = _asString(data['recipientUserId']);
                if (recipientUserId.isNotEmpty) {
                  final recipientDisplayName = _asString(
                    data['recipientDisplayName'],
                  );
                  if (currentUserId != null && msg.senderId == currentUserId) {
                    final label = recipientDisplayName.isEmpty
                        ? recipientUserId
                        : recipientDisplayName;
                    msg = msg.copyWith(
                      content: '[Private to $label] ${msg.content}',
                    );
                  } else if (currentUserId != null &&
                      recipientUserId == currentUserId) {
                    msg = msg.copyWith(
                      content: '[Private to you] ${msg.content}',
                    );
                  }
                }
                return msg;
              }).toList();

              messages.sort((a, b) {
                final cmp = a.createdAt.compareTo(b.createdAt);
                if (cmp != 0) return cmp;
                return a.id.compareTo(b.id);
              });

              return messages;
            }),
      );
    });

final roomTypingUserIdsProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, roomId) {
      return Stream.multi((controller) {
        final subscription = ref.listen(typingUserIdsProvider(roomId), (
          _,
          next,
        ) {
          if (controller.isClosed) return;
          next.whenData((ids) {
            controller.add(ids);
          });
        });
        controller.onCancel = subscription.close;
      });
    });

final sendMessageProvider = Provider.autoDispose
    .family<Future<void> Function(String), String>((ref, roomId) {
      return (String message) async {
        final user = ref.read(userProvider);
        if (user == null) {
          throw StateError('User must be logged in to send message');
        }

        var messagingEnabled = true;
        try {
          messagingEnabled = ref
              .read(featureGateControllerProvider)
              .enableMessaging;
        } on AssertionError {
          messagingEnabled = true;
        }
        if (!messagingEnabled) {
          Logger.warning(
            'CONTROL_GATE feature_blocked feature=messaging operation=room_chat_send roomId=$roomId userId=${user.id} result=blocked',
          );
          return;
        }

        final normalizedMessage = message.trim();
        if (normalizedMessage.isEmpty) {
          return;
        }

        final firestore = ref.read(roomFirestoreProvider);
        final moderationService = ModerationService(firestore: firestore);
        final blockedIds = await moderationService.getExcludedUserIds(user.id);

        final policySnapshot = await firestore
            .collection('rooms')
            .doc(roomId)
            .collection('policies')
            .doc('settings')
            .get();
        final allowChat = _asBool(
          policySnapshot.data()?['allowChat'],
          fallback: true,
        );
        if (!allowChat) {
          throw StateError('Chat is currently disabled in this room.');
        }

        if (blockedIds.isNotEmpty) {
          final participantsSnapshot = await firestore
              .collection('rooms')
              .doc(roomId)
              .collection('participants')
              .get();
          final hasBlockedParticipant = participantsSnapshot.docs.any((doc) {
            final participantData = doc.data();
            final participantId = _asString(
              participantData['userId'],
              fallback: doc.id,
            );
            if (participantId.isEmpty || participantId == user.id) {
              return false;
            }
            return blockedIds.contains(participantId);
          });
          if (hasBlockedParticipant) {
            throw StateError(
              'You cannot message while a blocked user is in this room.',
            );
          }
        }

        final roomSnapshot = await firestore
            .collection('rooms')
            .doc(roomId)
            .get();
        final hostId = _asString(roomSnapshot.data()?['hostId']);
        if (hostId.isNotEmpty) {
          final hasBlockingRelationship = await moderationService
              .hasBlockingRelationship(user.id, hostId);
          if (hasBlockingRelationship) {
            throw StateError('You cannot message in this room.');
          }
        }

        final messageRef = firestore
            .collection('rooms')
            .doc(roomId)
            .collection('messages')
            .doc();
        await messageRef.set({
          'id': messageRef.id,
          'senderId': user.id,
          'senderName': user.username.trim().isNotEmpty 
              ? user.username 
              : user.email.split('@').first,
          'roomId': roomId,
          'content': normalizedMessage,
          'createdAt': FieldValue.serverTimestamp(),
          'sentAt': FieldValue.serverTimestamp(),
          'clientSentAt': Timestamp.now(),
        });
      };
    });

final sendPrivateMessageProvider = Provider.autoDispose
    .family<
      Future<void> Function({
        required String content,
        required String recipientUserId,
        required String recipientDisplayName,
      }),
      String
    >((ref, roomId) {
      return ({
        required String content,
        required String recipientUserId,
        required String recipientDisplayName,
      }) async {
        final user = ref.read(userProvider);
        if (user == null) {
          throw StateError('User must be logged in to send message');
        }

        var messagingEnabled = true;
        try {
          messagingEnabled = ref
              .read(featureGateControllerProvider)
              .enableMessaging;
        } on AssertionError {
          messagingEnabled = true;
        }
        if (!messagingEnabled) {
          Logger.warning(
            'CONTROL_GATE feature_blocked feature=messaging operation=room_private_chat_send roomId=$roomId userId=${user.id} result=blocked',
          );
          return;
        }

        final normalizedMessage = content.trim();
        final normalizedRecipientId = recipientUserId.trim();
        if (normalizedMessage.isEmpty || normalizedRecipientId.isEmpty) {
          return;
        }
        if (normalizedRecipientId == user.id) {
          throw StateError('Cannot send a private room message to yourself.');
        }

        final firestore = ref.read(roomFirestoreProvider);
        final messageRef = firestore
            .collection('rooms')
            .doc(roomId)
            .collection('messages')
            .doc();

        await messageRef.set({
          'id': messageRef.id,
          'senderId': user.id,
          'senderName': user.username.trim().isNotEmpty 
              ? user.username 
              : user.email.split('@').first,
          'roomId': roomId,
          'content': normalizedMessage,
          'type': 'private',
          'recipientUserId': normalizedRecipientId,
          'recipientDisplayName': recipientDisplayName.trim(),
          'sentAt': FieldValue.serverTimestamp(),
          'clientSentAt': Timestamp.now(),
        });
      };
    });





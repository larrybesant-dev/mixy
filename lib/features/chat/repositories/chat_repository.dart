// lib/features/chat/repositories/chat_repository.dart
//
// Firestore implementation of IChatRepository.
// UID validation is enforced before every write here — never in the UI.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/models/chat_message.dart';
import 'package:mixvy/shared/models/chat_room.dart';
import 'i_chat_repository.dart';

class ChatRepository implements IChatRepository {
  final FirebaseFirestore _db;

  ChatRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  @override
  Stream<List<ChatMessage>> watchMessages(String channelId, {int limit = 50}) {
    return _db
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map((s) => s.docs.map(ChatMessage.fromDocument).toList());
  }

  @override
  Future<void> sendMessage({
    required String channelId,
    required String senderUid,
    required String text,
  }) async {
    _assertUid(senderUid);
    if (text.trim().isEmpty) {
      throw ArgumentError('Message text must not be empty');
    }
    await _db.collection('channels').doc(channelId).collection('messages').add({
      'senderUid': senderUid,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'deleted': false,
    });
    // Update last-message preview on the channel doc
    await _db.collection('channels').doc(channelId).update({
      'lastMessage': text.trim(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSender': senderUid,
    });
  }

  @override
  Future<void> deleteMessage({
    required String channelId,
    required String messageId,
    required String requestingUid,
  }) async {
    _assertUid(requestingUid);
    final ref = _db
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId);
    final doc = await ref.get();
    if (!doc.exists) return;
    final senderUid = doc.data()?['senderUid'] as String?;
    // Allow sender or moderator (moderator check is Firestore-rules side)
    if (senderUid != requestingUid) {
      throw Exception(
          'Permission denied: cannot delete another user\'s message');
    }
    await ref.update({'deleted': true, 'text': ''});
  }

  @override
  Future<ChatRoom> getOrCreateDmChannel({
    required String uidA,
    required String uidB,
  }) async {
    _assertUid(uidA);
    _assertUid(uidB);
    // Canonical channel ID is alphabetically sorted UIDs
    final ids = [uidA, uidB]..sort();
    final channelId = '${ids[0]}_${ids[1]}';
    final ref = _db.collection('channels').doc(channelId);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'type': 'dm',
        'members': ids,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
      });
      final newDoc = await ref.get();
      return ChatRoom.fromDocument(newDoc);
    }
    return ChatRoom.fromDocument(doc);
  }

  @override
  Stream<List<ChatRoom>> watchDmChannels(String uid) {
    _assertUid(uid);
    return _db
        .collection('channels')
        .where('members', arrayContains: uid)
        .where('type', isEqualTo: 'dm')
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ChatRoom.fromDocument).toList());
  }

  @override
  Future<void> markRead({
    required String channelId,
    required String uid,
  }) async {
    _assertUid(uid);
    await _db.collection('channels').doc(channelId).update({
      'readBy.$uid': FieldValue.serverTimestamp(),
    });
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------
  void _assertUid(String uid) {
    if (uid.trim().isEmpty) throw ArgumentError('UID must not be empty');
  }
}

final chatRepositoryProvider = Provider<IChatRepository>(
  (ref) => ChatRepository(),
);


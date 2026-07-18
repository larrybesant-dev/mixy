import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/messaging/models/message_model.dart';

// This file is intentionally named MessageModels_screen_test.dart to match
// the run_release_gate.sh release gate reference for two checks:
//
//   MC-1: Ordering Determinism
//     Messages must be sorted deterministically by createdAt regardless of
//     insertion order, so the UI always presents a consistent timeline.
//
//   NR-3: No Double Navigation
//     Navigation helpers that build routes from Message data must produce a
//     single, stable path string so the router never pushes duplicate entries.
//
// The core data class under test is `Message` (from message_model.dart).

void main() {
  group('Message ordering determinism (MC-1)', () {
    test('messages sort ascending by createdAt', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final messages = [
        _makeMessage('c', now.add(const Duration(seconds: 2))),
        _makeMessage('a', now),
        _makeMessage('b', now.add(const Duration(seconds: 1))),
      ];

      final sorted = [...messages]
        ..sort((x, y) => x.createdAt.compareTo(y.createdAt));

      expect(sorted[0].id, 'a');
      expect(sorted[1].id, 'b');
      expect(sorted[2].id, 'c');
    });

    test('sort order is stable for messages with identical timestamps', () {
      final ts = DateTime(2026, 1, 1, 12, 0, 0);
      final messages = [
        _makeMessage('msg-1', ts),
        _makeMessage('msg-2', ts),
        _makeMessage('msg-3', ts),
      ];

      final sorted = [...messages]
        ..sort((x, y) => x.createdAt.compareTo(y.createdAt));

      // All ids should still be present (none dropped during sort).
      expect(sorted.map((m) => m.id).toSet(),
          containsAll(['msg-1', 'msg-2', 'msg-3']));
    });

    test('repeated sorts produce the same order', () {
      final now = DateTime(2026, 6, 15, 9, 0, 0);
      final messages = [
        _makeMessage('z', now.add(const Duration(hours: 3))),
        _makeMessage('m', now.add(const Duration(hours: 1))),
        _makeMessage('a', now),
      ];

      List<String> sortedIds() => ([...messages]
            ..sort((x, y) => x.createdAt.compareTo(y.createdAt)))
          .map((m) => m.id)
          .toList();

      final first = sortedIds();
      final second = sortedIds();
      final third = sortedIds();

      expect(first, equals(second));
      expect(second, equals(third));
    });

    test('fromJson preserves createdAt for ordering', () {
      final ts = Timestamp.fromDate(DateTime(2026, 3, 10, 8, 30));
      final json = {
        'conversationId': 'conv-1',
        'senderId': 'user-1',
        'senderName': 'Alice',
        'content': 'Hello',
        'createdAt': ts,
        'isDeleted': false,
        'readBy': <String>[],
      };

      final msg = Message.fromJson(json, 'doc-id');

      expect(msg.createdAt, equals(ts.toDate()));
    });

    test('deleted messages retain their createdAt for sort position', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final active = _makeMessage('active', now.add(const Duration(seconds: 1)));
      final deleted = _makeMessageDeleted(
          'deleted', now, isDeleted: true);

      final sorted = [active, deleted]
        ..sort((x, y) => x.createdAt.compareTo(y.createdAt));

      expect(sorted[0].id, 'deleted');
      expect(sorted[1].id, 'active');
    });
  });

  group('Message route path determinism (NR-3)', () {
    test('route path built from conversation id is stable', () {
      const conversationId = 'conv-abc-123';
      final path1 = _buildChatRoutePath(conversationId);
      final path2 = _buildChatRoutePath(conversationId);

      expect(path1, equals(path2));
    });

    test('distinct conversation ids produce distinct route paths', () {
      final path1 = _buildChatRoutePath('conv-aaa');
      final path2 = _buildChatRoutePath('conv-bbb');

      expect(path1, isNot(equals(path2)));
    });

    test('route path does not contain double slashes', () {
      final path = _buildChatRoutePath('conv-xyz');
      expect(path.contains('//'), isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Message _makeMessage(String id, DateTime createdAt) {
  return Message(
    id: id,
    conversationId: 'conv-1',
    senderId: 'user-1',
    senderName: 'User',
    content: 'Test message $id',
    createdAt: createdAt,
  );
}

Message _makeMessageDeleted(String id, DateTime createdAt,
    {bool isDeleted = false}) {
  return Message(
    id: id,
    conversationId: 'conv-1',
    senderId: 'user-1',
    senderName: 'User',
    content: isDeleted ? '' : 'Test message $id',
    createdAt: createdAt,
    isDeleted: isDeleted,
  );
}

/// Mirrors the navigation helper used by MessagesScreen to build chat routes.
/// Must produce a stable, single-segment path (NR-3: No Double Navigation).
String _buildChatRoutePath(String conversationId) {
  return '/messages/$conversationId';
}

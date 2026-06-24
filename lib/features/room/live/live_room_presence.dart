// lib/features/room/live/live_room_presence.dart
//
// Firebase-only presence layer.
//
// Responsibility: Keep /rooms/{roomId}/participants/{uid} and /presence/{uid}
// accurate and alive. Zero video engine code here — pure Firestore.
//
// Guarantees:
//   • Writes happen even while the app is backgrounded.
//   • Heartbeat every 25 s proves the user is still alive.
//   • On leave: participant doc deleted, count decremented.
//   • participantsStream exposes the real-time list to the controller/UI.
// ───────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'live_room_schema.dart';

class LiveRoomPresence {
  LiveRoomPresence({
    required this.roomId,
    required this.roomType,
    required this.initialDisplayName,
    this.initialAvatarUrl,
  });

  final String roomId;
  final String roomType;
  final String initialDisplayName;
  final String? initialAvatarUrl;

  // ── Internals ─────────────────────────────────────────────────────────────
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Timer? _heartbeatTimer;
  StreamSubscription<QuerySnapshot>? _participantSub;

  final _participantsController =
      StreamController<List<RoomParticipant>>.broadcast();

  bool _disposed = false;
  bool _joined = false;
  String? _cachedUid;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Real-time stream of participants in this room.
  Stream<List<RoomParticipant>> get participantsStream =>
      _participantsController.stream;

  String get _uid {
    _cachedUid ??= _auth.currentUser?.uid ?? '';
    return _cachedUid!;
  }

  DocumentReference get _myDoc =>
      _fs.collection('rooms').doc(roomId).collection('participants').doc(_uid);

  // ── Join ──────────────────────────────────────────────────────────────────

  Future<void> join({required String role, required int gridPosition}) async {
    if (_joined || _disposed) return;
    _joined = true;

    final batch = _fs.batch();

    // 1. Write participant document
    batch.set(_myDoc, {
      ParticipantFields.userId: _uid,
      ParticipantFields.displayName: initialDisplayName,
      ParticipantFields.avatarUrl: initialAvatarUrl,
      ParticipantFields.role: role,
      ParticipantFields.isOnCam: false,
      ParticipantFields.isMicActive: false,
      ParticipantFields.isStreaming: false,
      ParticipantFields.isForegrounded: true,
      ParticipantFields.gridPosition: gridPosition,
      ParticipantFields.agoraUid: null,
      ParticipantFields.joinedAt: FieldValue.serverTimestamp(),
      ParticipantFields.lastHeartbeat: FieldValue.serverTimestamp(),
    });

    // 2. Increment participant count in room doc
    batch.update(_fs.collection('rooms').doc(roomId), {
      RoomFields.participantCount: FieldValue.increment(1),
      RoomFields.updatedAt: FieldValue.serverTimestamp(),
    });

    // 3. Update global presence
    batch.set(
      _fs.collection('presence').doc(_uid),
      {
        PresenceFields.userId: _uid,
        PresenceFields.status: 'online',
        PresenceFields.currentRoomId: roomId,
        PresenceFields.isForegrounded: true,
        PresenceFields.lastSeen: FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    // 4. Subscribe to participant changes
    _startListener();

    // 5. Heartbeat every 25 s
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _heartbeat(),
    );
  }

  // ── Leave ─────────────────────────────────────────────────────────────────

  Future<void> leave() async {
    if (!_joined) return;
    _joined = false;
    _teardown();

    try {
      final batch = _fs.batch();
      batch.delete(_myDoc);
      batch.update(_fs.collection('rooms').doc(roomId), {
        RoomFields.participantCount: FieldValue.increment(-1),
        RoomFields.updatedAt: FieldValue.serverTimestamp(),
      });
      batch.set(
        _fs.collection('presence').doc(_uid),
        {
          PresenceFields.currentRoomId: null,
          PresenceFields.lastSeen: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (e) {
      debugPrint('[PRESENCE] leave() error: $e');
    }
  }

  // ── Field setters ─────────────────────────────────────────────────────────

  Future<void> setCamOn(bool value) => _set(ParticipantFields.isOnCam, value);
  Future<void> setMicActive(bool value) =>
      _set(ParticipantFields.isMicActive, value);
  Future<void> setStreaming(bool value) =>
      _set(ParticipantFields.isStreaming, value);
  Future<void> setVideoEngineUid(int uid) =>
      _set(ParticipantFields.agoraUid, uid);
  Future<void> setCamRequestPending(bool v) =>
      _set(ParticipantFields.camRequestPending, v);

  /// Promote another user to a broadcaster grid slot.
  /// Only the room host should call this.
  /// NOTE: isOnCam is NOT set here — the promoted user must turn their own
  /// camera on after promotion (prevents phantom CAM badge in the tile grid).
  Future<void> promoteParticipant(
    String userId, {
    required int gridPosition,
    required String role,
  }) async {
    if (_disposed) return;
    try {
      await _fs
          .collection('rooms')
          .doc(roomId)
          .collection('participants')
          .doc(userId)
          .update({
        ParticipantFields.gridPosition: gridPosition,
        ParticipantFields.role: role,
        ParticipantFields.camRequestPending: false,
        ParticipantFields.lastHeartbeat: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[PRESENCE] promoteParticipant error: $e');
    }
  }

  /// Deny a cam request — clears the pending flag for another user.
  Future<void> denyParticipantRequest(String userId) async {
    if (_disposed) return;
    try {
      await _fs
          .collection('rooms')
          .doc(roomId)
          .collection('participants')
          .doc(userId)
          .update({
        ParticipantFields.camRequestPending: false,
        ParticipantFields.lastHeartbeat: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[PRESENCE] denyParticipantRequest error: $e');
    }
  }

  /// Demote a broadcaster back to audience.
  /// Only the room host should call this.
  /// Clears cam, streaming, and grid position in a single write.
  Future<void> demoteParticipant(String userId) async {
    if (_disposed) return;
    try {
      await _fs
          .collection('rooms')
          .doc(roomId)
          .collection('participants')
          .doc(userId)
          .update({
        ParticipantFields.role: ParticipantRole.audience,
        ParticipantFields.gridPosition: -1,
        ParticipantFields.isOnCam: false,
        ParticipantFields.isStreaming: false,
        ParticipantFields.isMicActive: false,
        ParticipantFields.camRequestPending: false,
        ParticipantFields.lastHeartbeat: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[PRESENCE] demoteParticipant error: $e');
    }
  }

  Future<void> setForegrounded(bool value) async {
    await _set(ParticipantFields.isForegrounded, value);
    try {
      await _fs.collection('presence').doc(_uid).set(
        {
          PresenceFields.isForegrounded: value,
          PresenceFields.lastSeen: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[PRESENCE] setForegrounded error: $e');
    }
  }

  /// Set videoChannelLive on the room document.
  Future<void> setVideoChannelLive(bool value) async {
    try {
      await _fs.collection('rooms').doc(roomId).update({
        RoomFields.videoChannelLive: value,
        RoomFields.updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[PRESENCE] setVideoChannelLive error: $e');
    }
  }

  /// Transaction: flip videoChannelLive=false only when this is the last participant.
  Future<void> deactivateVideoChannelIfLast() async {
    try {
      await _fs.runTransaction((tx) async {
        final ref = _fs.collection('rooms').doc(roomId);
        final snap = await tx.get(ref);
        final count = (snap.data()?[RoomFields.participantCount] as int?) ?? 0;
        if (count <= 1) {
          tx.update(ref, {
            RoomFields.videoChannelLive: false,
            RoomFields.updatedAt: FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint('[PRESENCE] deactivateVideoChannelIfLast error: $e');
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<void> _set(String field, dynamic value) async {
    if (_disposed) return;
    try {
      await _myDoc.update({
        field: value,
        ParticipantFields.lastHeartbeat: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[PRESENCE] _set($field) error: $e');
    }
  }

  Future<void> _heartbeat() async {
    if (_disposed) return;
    try {
      await _myDoc.update(
          {ParticipantFields.lastHeartbeat: FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('[PRESENCE] heartbeat error: $e');
    }
  }

  void _startListener() {
    _participantSub = _fs
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .snapshots()
        .listen(
      (snap) {
        if (_disposed) return;
        final list = snap.docs
            .map((d) => RoomParticipant.fromFirestore(d))
            .toList()
          ..sort((a, b) => a.gridPosition.compareTo(b.gridPosition));
        _participantsController.add(list);
      },
      onError: (e) => debugPrint('[PRESENCE] participant listener error: $e'),
    );
  }

  void _teardown() {
    _disposed = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _participantSub?.cancel();
    _participantSub = null;
  }

  void dispose() {
    _teardown();
    _participantsController.close();
  }
}

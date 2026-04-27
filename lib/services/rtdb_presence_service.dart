import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Manages per-session presence in Firebase Realtime Database.
///
/// RTDB is the ONLY Firebase product with a reliable server-side
/// `onDisconnect()` hook. We track one node per app session so a second
/// device does not clobber status for another active device.
///
/// Structure:
/// ```
///   /status/{userId}/sessions/{sessionId}
///     online:    bool
///     last_seen: timestamp (ms since epoch, set with ServerValue.timestamp)
///     in_room:   string|null
///     cam_on:    bool
///     mic_on:    bool
/// ```
class RtdbPresenceService {
  RtdbPresenceService(this._rtdb);

  final FirebaseDatabase? _rtdb;
  String? _sessionId;
  String? _inRoom;
  bool _camOn = false;
  bool _micOn = false;

  DatabaseReference? _userRef(String userId) =>
      _rtdb?.ref('status/$userId');

  DatabaseReference? _sessionsRef(String userId) =>
      _userRef(userId)?.child('sessions');

  String _ensureSessionId() {
    final existing = _sessionId;
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }
    final created = _buildSessionId();
    _sessionId = created;
    return created;
  }

  DatabaseReference? _sessionRef(String userId) {
    final sessionId = _ensureSessionId();
    return _sessionsRef(userId)?.child(sessionId);
  }

  Map<String, Object?> _onlinePayload({bool includeSessionId = false}) {
    return {
      'online': true,
      'last_seen': ServerValue.timestamp,
      'in_room': _inRoom,
      'cam_on': _camOn,
      'mic_on': _micOn,
      if (includeSessionId) 'session_id': _sessionId,
    };
  }

  String _buildSessionId() {
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return 's_${DateTime.now().microsecondsSinceEpoch}_$random';
  }

  Future<void> connect(String userId) async {
    if (userId.trim().isEmpty || _rtdb == null) return;
    try {
      _ensureSessionId();
      final ref = _sessionRef(userId);
      if (ref == null) return;
      final offlinePayload = {
        'online': false,
        'last_seen': ServerValue.timestamp,
        'in_room': null,
        'cam_on': false,
        'mic_on': false,
      };
      await ref.onDisconnect().set(offlinePayload);
      await ref.update(_onlinePayload(includeSessionId: true));
    } catch (e, st) {
      debugPrint('[RTDB] connect error (non-fatal): $e\n$st');
    }
  }

  Future<void> heartbeat(String userId) async {
    if (userId.trim().isEmpty || _rtdb == null) return;
    try {
      await _sessionRef(userId)?.update({'last_seen': ServerValue.timestamp});
    } catch (_) {
      // Best-effort. Silently ignore if RTDB is unavailable.
    }
  }

  Future<void> setInRoom(String userId, String roomId) async {
    if (userId.trim().isEmpty || _rtdb == null) return;
    _inRoom = roomId.trim().isEmpty ? null : roomId.trim();
    try {
      final ref = _sessionRef(userId);
      if (ref == null) return;
      await ref.onDisconnect().update({
        'online': false,
        'last_seen': ServerValue.timestamp,
        'in_room': null,
        'cam_on': false,
        'mic_on': false,
      });
      await ref.update(_onlinePayload());
    } catch (e) {
      debugPrint('[RTDB] setInRoom error (non-fatal): $e');
    }
  }

  Future<void> clearInRoom(String userId) async {
    if (userId.trim().isEmpty || _rtdb == null) return;
    _inRoom = null;
    _camOn = false;
    _micOn = false;
    try {
      await _sessionRef(userId)?.update(_onlinePayload());
    } catch (e) {
      debugPrint('[RTDB] clearInRoom error (non-fatal): $e');
    }
  }

  Future<void> setCamOn(String userId, {required bool camOn}) async {
    if (userId.trim().isEmpty || _rtdb == null) return;
    _camOn = camOn;
    try {
      await _sessionRef(userId)?.update(_onlinePayload());
    } catch (e) {
      debugPrint('[RTDB] setCamOn update failed (non-fatal): $e');
    }
  }

  Future<void> setMicOn(String userId, {required bool micOn}) async {
    if (userId.trim().isEmpty || _rtdb == null) return;
    _micOn = micOn;
    try {
      await _sessionRef(userId)?.update(_onlinePayload());
    } catch (e) {
      debugPrint('[RTDB] setMicOn update failed (non-fatal): $e');
    }
  }

  Future<void> disconnect(String userId) async {
    if (userId.trim().isEmpty || _rtdb == null) return;
    try {
      final ref = _sessionRef(userId);
      if (ref == null) return;
      await ref.onDisconnect().cancel();
      await ref.remove();
    } catch (e) {
      debugPrint('[RTDB] disconnect error (non-fatal): $e');
    } finally {
      _sessionId = null;
      _inRoom = null;
      _camOn = false;
      _micOn = false;
    }
  }

  Stream<bool> watchOnline(String userId) {
    if (userId.trim().isEmpty || _rtdb == null) return Stream.value(false);
    try {
      final ref = _sessionsRef(userId);
      if (ref == null) return Stream.value(false);
      return ref.onValue
          .map((event) {
            final raw = event.snapshot.value;
            if (raw is! Map) return false;
            for (final value in raw.values) {
              if (value is Map && value['online'] == true) {
                return true;
              }
            }
            return false;
          })
          .handleError((_) => false);
    } catch (_) {
      return Stream.value(false);
    }
  }

  Future<String?> getInRoom(String userId) async {
    if (userId.trim().isEmpty || _rtdb == null) return null;
    try {
      final ref = _sessionsRef(userId);
      if (ref == null) return null;
      final snap = await ref.get();
      final raw = snap.value;
      if (raw is! Map) return null;
      for (final value in raw.values) {
        if (value is Map) {
          final inRoom = value['in_room'];
          if (inRoom is String && inRoom.trim().isNotEmpty) {
            return inRoom;
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

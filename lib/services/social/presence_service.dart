import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/user_presence.dart';

/// Service for managing user online/offline presence
/// Phase 2 Enhanced: Error handling, retry guards, stream stability
class PresenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _presenceTimer;
  String? _currentUserId;

  // Retry guards to prevent infinite loops
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  final Map<String, int> _retryCounters = {};
  final Map<String, StreamController<UserPresence?>> _streamControllers = {};

  /// Initialize presence tracking for current user
  Future<void> initializePresence() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _currentUserId = user.uid;

    // Set user as online
    await _setPresence(PresenceStatus.online);

    // Update presence every 30 seconds
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateHeartbeat(),
    );

    // Listen for app lifecycle changes
    _setupLifecycleListener();
  }

  /// Set user presence status
  Future<void> _setPresence(PresenceStatus status,
      {String? roomId, String? message}) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('presence').doc(_currentUserId).set({
        'userId': _currentUserId,
        'status': status.toString().split('.').last,
        'lastSeen': FieldValue.serverTimestamp(),
        'currentRoomId': roomId,
        'statusMessage': message,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error setting presence: $e');
    }
  }

  /// Update heartbeat to keep user online
  Future<void> _updateHeartbeat() async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('presence').doc(_currentUserId).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating heartbeat: $e');
    }
  }

  /// Set user as online
  Future<void> goOnline({String? roomId}) async {
    await _setPresence(PresenceStatus.online, roomId: roomId);
  }

  /// Set user as away
  Future<void> goAway() async {
    await _setPresence(PresenceStatus.away);
  }

  /// Set user as busy
  Future<void> goBusy({String? message}) async {
    await _setPresence(PresenceStatus.busy, message: message);
  }

  /// Set user as offline
  Future<void> goOffline() async {
    await _setPresence(PresenceStatus.offline);
    _presenceTimer?.cancel();
  }

  /// Update current room
  Future<void> updateCurrentRoom(String? roomId) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('presence').doc(_currentUserId).update({
        'currentRoomId': roomId,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating current room: $e');
    }
  }

  /// Get user presence with error handling and retry guards
  Stream<UserPresence?> getUserPresence(String userId) {
    // Prevent infinite retry loops
    final retryKey = 'getUserPresence_$userId';
    if (_retryCounters[retryKey] != null &&
        _retryCounters[retryKey]! >= _maxRetries) {
      debugPrint('âš ï¸ Max retries reached for getUserPresence($userId)');
      return Stream.value(null);
    }

    // Reuse existing stream controller if available
    if (_streamControllers.containsKey(userId)) {
      return _streamControllers[userId]!.stream;
    }

    // Create new stream controller with error handling
    final controller = StreamController<UserPresence?>.broadcast(
      onCancel: () {
        debugPrint('ðŸ”Œ Presence stream cancelled for user: $userId');
        _cleanupStream(userId);
      },
    );

    _streamControllers[userId] = controller;

    // Start listening with error recovery
    _startPresenceListener(userId, controller, retryKey);

    return controller.stream;
  }

  /// Internal listener with retry logic
  void _startPresenceListener(
    String userId,
    StreamController<UserPresence?> controller,
    String retryKey,
  ) {
    StreamSubscription<DocumentSnapshot>? subscription;

    subscription =
        _firestore.collection('presence').doc(userId).snapshots().listen(
      (doc) {
        try {
          // Reset retry counter on success
          _retryCounters[retryKey] = 0;

          if (!doc.exists || doc.data() == null) {
            if (!controller.isClosed) {
              controller.add(null);
            }
            return;
          }

          final presence = UserPresence.fromMap(userId, doc.data()!);
          if (!controller.isClosed) {
            controller.add(presence);
          }
        } catch (e, stackTrace) {
          debugPrint('âŒ Error parsing presence data: $e');
          debugPrint('Stack trace: $stackTrace');
          if (!controller.isClosed) {
            controller.add(null); // Emit null instead of error
          }
        }
      },
      onError: (error, stackTrace) {
        debugPrint('âŒ Presence stream error for $userId: $error');
        debugPrint('Stack trace: $stackTrace');

        // Increment retry counter
        _retryCounters[retryKey] = (_retryCounters[retryKey] ?? 0) + 1;

        // Emit null and optionally retry
        if (!controller.isClosed) {
          controller.add(null);
        }

        // Retry with exponential backoff if under max retries
        if (_retryCounters[retryKey]! < _maxRetries) {
          final delay = _retryDelay * _retryCounters[retryKey]!;
          debugPrint(
              'ðŸ”„ Retrying presence listener in ${delay.inSeconds}s...');

          Future.delayed(delay, () {
            if (!controller.isClosed) {
              subscription?.cancel();
              _startPresenceListener(userId, controller, retryKey);
            }
          });
        } else {
          debugPrint('â›” Max retries reached for presence listener: $userId');
          _cleanupStream(userId);
        }
      },
      cancelOnError: false, // Don't auto-cancel on error
    );

    // Store subscription for cleanup
    controller.onCancel = () {
      subscription?.cancel();
      _cleanupStream(userId);
    };
  }

  /// Cleanup stream resources
  void _cleanupStream(String userId) {
    _streamControllers[userId]?.close();
    _streamControllers.remove(userId);
    _retryCounters.remove('getUserPresence_$userId');
  }

  /// Update user presence status
  Future<void> updatePresence(String userId, {bool? isOnline}) async {
    if (isOnline == null) return;

    try {
      await _firestore.collection('presence').doc(userId).update({
        'status': isOnline ? 'online' : 'offline',
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating presence: $e');
    }
  }

  /// Get multiple users' presence with error handling
  Stream<List<UserPresence>> getUsersPresence(List<String> userIds) {
    if (userIds.isEmpty) return Stream.value([]);

    return _firestore
        .collection('presence')
        .where('userId', whereIn: userIds.take(10).toList()) // Firestore limit
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) {
              try {
                return UserPresence.fromMap(doc.id, doc.data());
              } catch (e) {
                debugPrint(
                    'âš ï¸ Failed to parse presence for doc ${doc.id}: $e');
                return null;
              }
            })
            .whereType<UserPresence>() // Filter out nulls
            .toList();
      } catch (e) {
        debugPrint('âŒ Error mapping users presence: $e');
        return <UserPresence>[];
      }
    }).handleError((error, stackTrace) {
      debugPrint('âŒ getUsersPresence stream error: $error');
      debugPrint('Stack trace: $stackTrace');
      return <UserPresence>[]; // Return empty list on error
    });
  }

  /// Get online users count
  Future<int> getOnlineUsersCount() async {
    try {
      final fiveMinutesAgo =
          DateTime.now().subtract(const Duration(minutes: 5));

      final snapshot = await _firestore
          .collection('presence')
          .where('status', isEqualTo: 'online')
          .where('lastSeen', isGreaterThan: Timestamp.fromDate(fiveMinutesAgo))
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting online users count: $e');
      return 0;
    }
  }

  /// Setup app lifecycle listener
  void _setupLifecycleListener() {
    // This would be called from the app's main widget
    // For now, we'll handle it in the service initialization
  }

  /// Cleanup with proper resource disposal
  void dispose() {
    debugPrint('ðŸ§¹ Disposing PresenceService...');
    _presenceTimer?.cancel();

    // Close all stream controllers
    for (var controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
    _retryCounters.clear();

    goOffline();
  }
}

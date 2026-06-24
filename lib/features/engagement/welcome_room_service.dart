/// Welcome Room Service
///
/// Manages the welcome room for new users, providing a friendly
/// introduction to the Mix & Mingle community.
library;

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/analytics/analytics_service.dart';

/// Service for managing welcome room functionality
class WelcomeRoomService {
  static WelcomeRoomService? _instance;
  static WelcomeRoomService get instance =>
      _instance ??= WelcomeRoomService._();

  WelcomeRoomService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;

  // Welcome room configuration collection
  static const String _configCollection = 'app_config';
  static const String _welcomeRoomConfigDoc = 'welcome_room';

  /// Cached welcome room configuration
  WelcomeRoomConfig? _cachedConfig;
  DateTime? _configCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 15);

  /// Fetch welcome room configuration
  /// Returns cached config if still valid
  Future<WelcomeRoomConfig> fetchWelcomeRoomConfig() async {
    try {
      // Check cache
      if (_cachedConfig != null &&
          _configCacheTime != null &&
          DateTime.now().difference(_configCacheTime!) < _cacheDuration) {
        return _cachedConfig!;
      }

      // Fetch from Firestore
      final doc = await _firestore
          .collection(_configCollection)
          .doc(_welcomeRoomConfigDoc)
          .get();

      if (doc.exists && doc.data() != null) {
        _cachedConfig = WelcomeRoomConfig.fromFirestore(doc.data()!);
        _configCacheTime = DateTime.now();
        return _cachedConfig!;
      }

      // Return default config if not found
      _cachedConfig = const WelcomeRoomConfig();
      _configCacheTime = DateTime.now();
      return _cachedConfig!;
    } catch (e) {
      debugPrint('âŒ [WelcomeRoom] Failed to fetch config: $e');
      return const WelcomeRoomConfig();
    }
  }

  /// Join the welcome room
  /// Returns the room ID if successful
  Future<String?> joinWelcomeRoom(String userId, String userName) async {
    try {
      final config = await fetchWelcomeRoomConfig();

      if (!config.isEnabled) {
        debugPrint('â„¹ï¸ [WelcomeRoom] Welcome room is disabled');
        return null;
      }

      // Find an active welcome room or create one
      String? roomId = await _findActiveWelcomeRoom(config);

      if (roomId == null && config.autoCreateIfNone) {
        roomId = await _createWelcomeRoom(config, userId, userName);
      }

      if (roomId == null) {
        debugPrint('â„¹ï¸ [WelcomeRoom] No welcome room available');
        return null;
      }

      // Add user to the room
      await _addUserToRoom(roomId, userId, userName);

      // Track analytics
      await _analytics.logEvent(
        name: 'welcome_room_joined',
        parameters: {
          'user_id': userId,
          'room_id': roomId,
        },
      );

      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'welcomeRoomJoined': true,
        'welcomeRoomJoinedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('âœ… [WelcomeRoom] User $userId joined room $roomId');
      return roomId;
    } catch (e) {
      debugPrint('âŒ [WelcomeRoom] Failed to join: $e');
      return null;
    }
  }

  /// Find an active welcome room
  Future<String?> _findActiveWelcomeRoom(WelcomeRoomConfig config) async {
    try {
      final query = await _firestore
          .collection('rooms')
          .where('isWelcomeRoom', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .where('status', isEqualTo: 'live')
          .orderBy('viewerCount', descending: false)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final room = query.docs.first;
        final viewerCount = room.data()['viewerCount'] ?? 0;

        // Check if room has capacity
        if (viewerCount < config.maxRoomCapacity) {
          return room.id;
        }
      }

      return null;
    } catch (e) {
      debugPrint('âŒ [WelcomeRoom] Error finding room: $e');
      return null;
    }
  }

  /// Create a new welcome room
  Future<String?> _createWelcomeRoom(
    WelcomeRoomConfig config,
    String hostId,
    String hostName,
  ) async {
    try {
      final roomId = _firestore.collection('rooms').doc().id;

      final roomData = {
        'id': roomId,
        'name': config.roomTitle,
        'title': config.roomTitle,
        'description': config.roomDescription,
        'hostId': 'system', // System-hosted room
        'hostName': 'Mix & Mingle',
        'creatorId': 'system',
        'isWelcomeRoom': true,
        'isActive': true,
        'status': 'live',
        'category': 'welcome',
        'tags': ['welcome', 'newbies', 'introduction'],
        'privacy': 'public',
        'participantIds': [],
        'speakers': [],
        'listeners': [],
        'moderators': ['system'],
        'bannedUsers': [],
        'viewerCount': 0,
        'isLive': true,
        'roomType': 'voice',
        'agoraChannelName': 'welcome_$roomId',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('rooms').doc(roomId).set(roomData);

      debugPrint('âœ… [WelcomeRoom] Created new welcome room: $roomId');
      return roomId;
    } catch (e) {
      debugPrint('âŒ [WelcomeRoom] Failed to create room: $e');
      return null;
    }
  }

  /// Add user to room as listener
  Future<void> _addUserToRoom(
    String roomId,
    String userId,
    String userName,
  ) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'participantIds': FieldValue.arrayUnion([userId]),
        'listeners': FieldValue.arrayUnion([userId]),
        'viewerCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('âŒ [WelcomeRoom] Failed to add user to room: $e');
      rethrow;
    }
  }

  /// Get welcome room status
  Future<WelcomeRoomStatus> getWelcomeRoomStatus() async {
    try {
      final config = await fetchWelcomeRoomConfig();

      if (!config.isEnabled) {
        return WelcomeRoomStatus.disabled;
      }

      final roomId = await _findActiveWelcomeRoom(config);

      if (roomId != null) {
        return WelcomeRoomStatus.available;
      }

      return config.autoCreateIfNone
          ? WelcomeRoomStatus.willCreate
          : WelcomeRoomStatus.unavailable;
    } catch (e) {
      debugPrint('âŒ [WelcomeRoom] Error getting status: $e');
      return WelcomeRoomStatus.error;
    }
  }

  /// Check if user has joined welcome room
  Future<bool> hasUserJoinedWelcomeRoom(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['welcomeRoomJoined'] ?? false;
    } catch (e) {
      debugPrint('âŒ [WelcomeRoom] Error checking join status: $e');
      return false;
    }
  }

  /// Clear configuration cache
  void clearConfigCache() {
    _cachedConfig = null;
    _configCacheTime = null;
  }
}

/// Welcome room configuration
class WelcomeRoomConfig {
  final bool isEnabled;
  final String roomTitle;
  final String roomDescription;
  final int maxRoomCapacity;
  final bool autoCreateIfNone;
  final List<String> welcomeMessages;

  const WelcomeRoomConfig({
    this.isEnabled = true,
    this.roomTitle = 'Welcome to Mix & Mingle! ðŸŽ‰',
    this.roomDescription =
        'A friendly place for new members to meet the community and learn the ropes.',
    this.maxRoomCapacity = 50,
    this.autoCreateIfNone = true,
    this.welcomeMessages = const [
      'Welcome to Mix & Mingle! ðŸ‘‹',
      'Feel free to say hi and introduce yourself!',
      'Need help? Just ask - our community is super friendly!',
    ],
  });

  factory WelcomeRoomConfig.fromFirestore(Map<String, dynamic> data) {
    return WelcomeRoomConfig(
      isEnabled: data['isEnabled'] ?? true,
      roomTitle: data['roomTitle'] ?? 'Welcome to Mix & Mingle! ðŸŽ‰',
      roomDescription: data['roomDescription'] ??
          'A friendly place for new members to meet the community.',
      maxRoomCapacity: data['maxRoomCapacity'] ?? 50,
      autoCreateIfNone: data['autoCreateIfNone'] ?? true,
      welcomeMessages: List<String>.from(data['welcomeMessages'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'isEnabled': isEnabled,
      'roomTitle': roomTitle,
      'roomDescription': roomDescription,
      'maxRoomCapacity': maxRoomCapacity,
      'autoCreateIfNone': autoCreateIfNone,
      'welcomeMessages': welcomeMessages,
    };
  }
}

/// Welcome room status
enum WelcomeRoomStatus {
  available,
  unavailable,
  willCreate,
  disabled,
  error,
}

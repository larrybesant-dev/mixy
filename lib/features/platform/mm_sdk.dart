/// Mix & Mingle SDK
///
/// Client SDK for integrating Mix & Mingle functionality
/// into external applications.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// SDK Configuration
class MMSDKConfig {
  final String clientId;
  final String clientSecret;
  final String baseUrl;
  final Duration timeout;
  final bool enableLogging;

  const MMSDKConfig({
    required this.clientId,
    required this.clientSecret,
    this.baseUrl = 'https://api.mixmingle.com',
    this.timeout = const Duration(seconds: 30),
    this.enableLogging = false,
  });
}

/// Room information
class MMRoom {
  final String id;
  final String title;
  final String? description;
  final String hostId;
  final String hostName;
  final int participantCount;
  final int maxParticipants;
  final RoomType type;
  final RoomStatus status;
  final List<String> tags;
  final DateTime createdAt;

  const MMRoom({
    required this.id,
    required this.title,
    this.description,
    required this.hostId,
    required this.hostName,
    required this.participantCount,
    required this.maxParticipants,
    required this.type,
    required this.status,
    this.tags = const [],
    required this.createdAt,
  });

  factory MMRoom.fromJson(Map<String, dynamic> json) => MMRoom(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        hostId: json['hostId'] as String,
        hostName: json['hostName'] as String,
        participantCount: json['participantCount'] as int,
        maxParticipants: json['maxParticipants'] as int,
        type: RoomType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => RoomType.standard,
        ),
        status: RoomStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => RoomStatus.active,
        ),
        tags: List<String>.from(json['tags'] ?? []),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'hostId': hostId,
        'hostName': hostName,
        'participantCount': participantCount,
        'maxParticipants': maxParticipants,
        'type': type.name,
        'status': status.name,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
      };
}

enum RoomType { standard, premium, vip, event }

enum RoomStatus { active, scheduled, ended, paused }

/// Message data
class MMMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final DateTime sentAt;

  const MMMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.sentAt,
  });

  factory MMMessage.fromJson(Map<String, dynamic> json) => MMMessage(
        id: json['id'] as String,
        roomId: json['roomId'] as String,
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String,
        content: json['content'] as String,
        type: MessageType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => MessageType.text,
        ),
        sentAt: DateTime.parse(json['sentAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'type': type.name,
        'sentAt': sentAt.toIso8601String(),
      };
}

enum MessageType { text, emoji, gift, system }

/// Creator statistics
class CreatorStats {
  final String creatorId;
  final int totalFollowers;
  final int totalSubscribers;
  final int totalRooms;
  final int totalViews;
  final double averageRating;
  final double totalEarnings;
  final int totalHoursStreamed;
  final Map<String, int> engagementByDay;
  final DateTime updatedAt;

  const CreatorStats({
    required this.creatorId,
    required this.totalFollowers,
    required this.totalSubscribers,
    required this.totalRooms,
    required this.totalViews,
    required this.averageRating,
    required this.totalEarnings,
    required this.totalHoursStreamed,
    this.engagementByDay = const {},
    required this.updatedAt,
  });

  factory CreatorStats.fromJson(Map<String, dynamic> json) => CreatorStats(
        creatorId: json['creatorId'] as String,
        totalFollowers: json['totalFollowers'] as int,
        totalSubscribers: json['totalSubscribers'] as int,
        totalRooms: json['totalRooms'] as int,
        totalViews: json['totalViews'] as int,
        averageRating: (json['averageRating'] as num).toDouble(),
        totalEarnings: (json['totalEarnings'] as num).toDouble(),
        totalHoursStreamed: json['totalHoursStreamed'] as int,
        engagementByDay: Map<String, int>.from(json['engagementByDay'] ?? {}),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

/// Spotlight result
class SpotlightResult {
  final bool success;
  final String? spotlightId;
  final String userId;
  final String roomId;
  final Duration duration;
  final DateTime startedAt;

  const SpotlightResult({
    required this.success,
    this.spotlightId,
    required this.userId,
    required this.roomId,
    required this.duration,
    required this.startedAt,
  });

  factory SpotlightResult.fromJson(Map<String, dynamic> json) =>
      SpotlightResult(
        success: json['success'] as bool,
        spotlightId: json['spotlightId'] as String?,
        userId: json['userId'] as String,
        roomId: json['roomId'] as String,
        duration: Duration(seconds: json['durationSeconds'] as int),
        startedAt: DateTime.parse(json['startedAt'] as String),
      );
}

/// Multi-cam view configuration
class MultiCamConfig {
  final String roomId;
  final List<String> cameraUserIds;
  final MultiCamLayout layout;
  final bool showLabels;
  final bool allowUserSwitch;

  const MultiCamConfig({
    required this.roomId,
    required this.cameraUserIds,
    this.layout = MultiCamLayout.grid,
    this.showLabels = true,
    this.allowUserSwitch = true,
  });

  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'cameraUserIds': cameraUserIds,
        'layout': layout.name,
        'showLabels': showLabels,
        'allowUserSwitch': allowUserSwitch,
      };
}

enum MultiCamLayout { grid, spotlight, pip, sideBySide }

/// Multi-cam embed result
class MultiCamEmbed {
  final String embedId;
  final String embedUrl;
  final String iframeCode;
  final MultiCamConfig config;
  final DateTime createdAt;
  final DateTime expiresAt;

  const MultiCamEmbed({
    required this.embedId,
    required this.embedUrl,
    required this.iframeCode,
    required this.config,
    required this.createdAt,
    required this.expiresAt,
  });

  factory MultiCamEmbed.fromJson(Map<String, dynamic> json) => MultiCamEmbed(
        embedId: json['embedId'] as String,
        embedUrl: json['embedUrl'] as String,
        iframeCode: json['iframeCode'] as String,
        config: MultiCamConfig(
          roomId: json['config']['roomId'] as String,
          cameraUserIds: List<String>.from(json['config']['cameraUserIds']),
          layout: MultiCamLayout.values.firstWhere(
            (l) => l.name == json['config']['layout'],
            orElse: () => MultiCamLayout.grid,
          ),
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

/// SDK Response wrapper
class SDKResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? statusCode;

  const SDKResponse({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });

  factory SDKResponse.success(T data) => SDKResponse(
        success: true,
        data: data,
      );

  factory SDKResponse.failure(String error, {int? statusCode}) => SDKResponse(
        success: false,
        error: error,
        statusCode: statusCode,
      );
}

/// Mix & Mingle SDK
class MMSDK {
  final MMSDKConfig config;
  String? _accessToken;
  DateTime? _tokenExpiry;
  final http.Client _httpClient;

  MMSDK({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  bool get isAuthenticated =>
      _accessToken != null &&
      _tokenExpiry != null &&
      DateTime.now().isBefore(_tokenExpiry!);

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  /// Initialize the SDK and authenticate
  Future<bool> initialize() async {
    _log('Initializing Mix & Mingle SDK...');

    try {
      final response = await _httpClient
          .post(
            Uri.parse('${config.baseUrl}/oauth/token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'grant_type': 'client_credentials',
              'client_id': config.clientId,
              'client_secret': config.clientSecret,
            }),
          )
          .timeout(config.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _accessToken = data['access_token'] as String;
        _tokenExpiry = DateTime.now().add(
          Duration(seconds: data['expires_in'] as int),
        );
        _log('SDK initialized successfully');
        return true;
      }

      _log('SDK initialization failed: ${response.statusCode}');
      return false;
    } catch (e) {
      _log('SDK initialization error: $e');
      return false;
    }
  }

  Future<void> _ensureAuthenticated() async {
    if (!isAuthenticated) {
      final success = await initialize();
      if (!success) {
        throw Exception('SDK not authenticated');
      }
    }
  }

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

  // ============================================================
  // ROOM OPERATIONS
  // ============================================================

  /// Join a room
  Future<SDKResponse<MMRoom>> joinRoom(String roomId, {String? userId}) async {
    _log('Joining room: $roomId');

    try {
      await _ensureAuthenticated();

      final response = await _httpClient
          .post(
            Uri.parse('${config.baseUrl}/api/v1/rooms/$roomId/join'),
            headers: _authHeaders,
            body: jsonEncode({
              'userId': userId,
            }),
          )
          .timeout(config.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final room = MMRoom.fromJson(data['room'] as Map<String, dynamic>);
        _log('Joined room successfully: ${room.title}');
        return SDKResponse.success(room);
      }

      return SDKResponse.failure(
        'Failed to join room',
        statusCode: response.statusCode,
      );
    } catch (e) {
      _log('Error joining room: $e');
      return SDKResponse.failure(e.toString());
    }
  }

  /// Leave a room
  Future<SDKResponse<bool>> leaveRoom(String roomId) async {
    _log('Leaving room: $roomId');

    try {
      await _ensureAuthenticated();

      final response = await _httpClient
          .post(
            Uri.parse('${config.baseUrl}/api/v1/rooms/$roomId/leave'),
            headers: _authHeaders,
          )
          .timeout(config.timeout);

      if (response.statusCode == 200) {
        _log('Left room successfully');
        return SDKResponse.success(true);
      }

      return SDKResponse.failure(
        'Failed to leave room',
        statusCode: response.statusCode,
      );
    } catch (e) {
      _log('Error leaving room: $e');
      return SDKResponse.failure(e.toString());
    }
  }

  /// Get room details
  Future<SDKResponse<MMRoom>> getRoom(String roomId) async {
    try {
      await _ensureAuthenticated();

      final response = await _httpClient
          .get(
            Uri.parse('${config.baseUrl}/api/v1/rooms/$roomId'),
            headers: _authHeaders,
          )
          .timeout(config.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return SDKResponse.success(MMRoom.fromJson(data));
      }

      return SDKResponse.failure(
        'Failed to get room',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return SDKResponse.failure(e.toString());
    }
  }

  /// List available rooms
  Future<SDKResponse<List<MMRoom>>> listRooms({
    int limit = 20,
    String? cursor,
  }) async {
    try {
      await _ensureAuthenticated();

      final queryParams = {
        'limit': limit.toString(),
        if (cursor != null) 'cursor': cursor,
      };

      final response = await _httpClient
          .get(
            Uri.parse('${config.baseUrl}/api/v1/rooms')
                .replace(queryParameters: queryParams),
            headers: _authHeaders,
          )
          .timeout(config.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rooms = (data['rooms'] as List)
            .map((r) => MMRoom.fromJson(r as Map<String, dynamic>))
            .toList();
        return SDKResponse.success(rooms);
      }

      return SDKResponse.failure(
        'Failed to list rooms',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return SDKResponse.failure(e.toString());
    }
  }

  // ============================================================
  // MESSAGING
  // ============================================================

  /// Send a message to a room
  Future<SDKResponse<MMMessage>> sendMessage(
    String roomId,
    String content, {
    MessageType type = MessageType.text,
  }) async {
    _log('Sending message to room: $roomId');

    try {
      await _ensureAuthenticated();

      final response = await _httpClient
          .post(
            Uri.parse('${config.baseUrl}/api/v1/rooms/$roomId/messages'),
            headers: _authHeaders,
            body: jsonEncode({
              'content': content,
              'type': type.name,
            }),
          )
          .timeout(config.timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final message = MMMessage.fromJson(data);
        _log('Message sent successfully');
        return SDKResponse.success(message);
      }

      return SDKResponse.failure(
        'Failed to send message',
        statusCode: response.statusCode,
      );
    } catch (e) {
      _log('Error sending message: $e');
      return SDKResponse.failure(e.toString());
    }
  }

  /// Get room messages
  Future<SDKResponse<List<MMMessage>>> getMessages(
    String roomId, {
    int limit = 50,
    String? beforeId,
  }) async {
    try {
      await _ensureAuthenticated();

      final queryParams = {
        'limit': limit.toString(),
        if (beforeId != null) 'before': beforeId,
      };

      final response = await _httpClient
          .get(
            Uri.parse('${config.baseUrl}/api/v1/rooms/$roomId/messages')
                .replace(queryParameters: queryParams),
            headers: _authHeaders,
          )
          .timeout(config.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final messages = (data['messages'] as List)
            .map((m) => MMMessage.fromJson(m as Map<String, dynamic>))
            .toList();
        return SDKResponse.success(messages);
      }

      return SDKResponse.failure(
        'Failed to get messages',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return SDKResponse.failure(e.toString());
    }
  }

  // ============================================================
  // SPOTLIGHT
  // ============================================================

  /// Trigger spotlight on a user in a room
  Future<SDKResponse<SpotlightResult>> triggerSpotlight(
    String roomId,
    String userId, {
    Duration duration = const Duration(seconds: 30),
  }) async {
    _log('Triggering spotlight: user=$userId, room=$roomId');

    try {
      await _ensureAuthenticated();

      final response = await _httpClient
          .post(
            Uri.parse('${config.baseUrl}/api/v1/rooms/$roomId/spotlight'),
            headers: _authHeaders,
            body: jsonEncode({
              'userId': userId,
              'durationSeconds': duration.inSeconds,
            }),
          )
          .timeout(config.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = SpotlightResult.fromJson(data);
        _log('Spotlight triggered successfully');
        return SDKResponse.success(result);
      }

      return SDKResponse.failure(
        'Failed to trigger spotlight',
        statusCode: response.statusCode,
      );
    } catch (e) {
      _log('Error triggering spotlight: $e');
      return SDKResponse.failure(e.toString());
    }
  }

  // ============================================================
  // CREATOR STATS
  // ============================================================

  /// Fetch creator statistics
  Future<SDKResponse<CreatorStats>> fetchCreatorStats(String creatorId) async {
    _log('Fetching creator stats: $creatorId');

    try {
      await _ensureAuthenticated();

      final response = await _httpClient
          .get(
            Uri.parse('${config.baseUrl}/api/v1/creators/$creatorId/stats'),
            headers: _authHeaders,
          )
          .timeout(config.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final stats = CreatorStats.fromJson(data);
        _log('Creator stats fetched successfully');
        return SDKResponse.success(stats);
      }

      return SDKResponse.failure(
        'Failed to fetch creator stats',
        statusCode: response.statusCode,
      );
    } catch (e) {
      _log('Error fetching creator stats: $e');
      return SDKResponse.failure(e.toString());
    }
  }

  // ============================================================
  // MULTI-CAM VIEW
  // ============================================================

  /// Create an embeddable multi-cam view
  Future<SDKResponse<MultiCamEmbed>> embedMultiCamView(
    MultiCamConfig config,
  ) async {
    _log('Creating multi-cam embed for room: ${config.roomId}');

    try {
      await _ensureAuthenticated();

      final response = await _httpClient
          .post(
            Uri.parse('${this.config.baseUrl}/api/v1/embed/multicam'),
            headers: _authHeaders,
            body: jsonEncode(config.toJson()),
          )
          .timeout(this.config.timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final embed = MultiCamEmbed.fromJson(data);
        _log('Multi-cam embed created: ${embed.embedId}');
        return SDKResponse.success(embed);
      }

      return SDKResponse.failure(
        'Failed to create multi-cam embed',
        statusCode: response.statusCode,
      );
    } catch (e) {
      _log('Error creating multi-cam embed: $e');
      return SDKResponse.failure(e.toString());
    }
  }

  // ============================================================
  // UTILITY
  // ============================================================

  void _log(String message) {
    if (config.enableLogging) {
      debugPrint('[MMSDK] $message');
    }
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}

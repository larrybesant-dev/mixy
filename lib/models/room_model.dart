import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/core/utils/network_image_url.dart';
import 'package:mixvy/features/room/models/room_theme_model.dart';

class RoomModel {
  final String id;
  final String name;
  final String? description;
  final String? rules;
  final String hostId;
  final String ownerId;
  final List<String> adminUserIds;
  final bool isLive;
  final String? thumbnailUrl;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? endedAt;
  // Members
  final List<String> stageUserIds;
  final List<String> audienceUserIds;
  // Metadata
  final int memberCount;
  final String? category;
  final List<String> tags;
  final List<String> coHosts;
  final bool isLocked;
  final bool allowGuestAccess;
  final int? slowModeSeconds;
  final int maxBroadcasters;

  /// When the room is scheduled to start (null = not scheduled / already live).
  final Timestamp? scheduledAt;

  /// Whether this is an 18+ After Dark room.
  final bool isAdult;

  /// Denormalized host info to avoid N+1 lookups in discovery feed.
  final String? hostUsername;
  final String? hostAvatarUrl;

  /// Optional visual theme applied to the live room.
  final RoomTheme theme;

  RoomModel({
    required this.id,
    required this.name,
    required this.hostId,
    this.ownerId = '',
    this.adminUserIds = const [],
    this.description,
    this.rules,
    this.isLive = false,
    this.thumbnailUrl,
    this.createdAt,
    this.updatedAt,
    this.endedAt,
    this.stageUserIds = const [],
    this.audienceUserIds = const [],
    this.memberCount = 0,
    this.category,
    this.tags = const [],
    this.coHosts = const [],
    this.isLocked = false,
    this.allowGuestAccess = true,
    this.slowModeSeconds,
    this.maxBroadcasters = 4,
    this.scheduledAt,
    this.isAdult = false,
    this.hostUsername,
    this.hostAvatarUrl,
    this.theme = RoomTheme.defaultTheme,
  });

  /// Combined members list (used by UI)
  List<String> get members => [...stageUserIds, ...audienceUserIds];

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      return value;
    }
    return fallback;
  }

  static bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    return fallback;
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  static Timestamp? _asTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value;
    }
    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return Timestamp.fromDate(parsed);
      }
    }
    return null;
  }

  factory RoomModel.fromJson(Map<String, dynamic> json, String documentId) {
    return RoomModel(
      id: documentId,
      name: _asString(json['name'], fallback: 'Untitled Room'),
      description: json['description'] is String
          ? json['description'] as String
          : null,
      rules: json['rules'] is String ? json['rules'] as String : null,
      hostId: _asString(json['hostId']),
      ownerId: _asString(json['ownerId']),
      adminUserIds: _asStringList(json['adminUserIds']),
      isLive: _asBool(json['isLive']),
      thumbnailUrl: sanitizeNetworkImageUrl(
        json['thumbnailUrl'] is String ? json['thumbnailUrl'] as String : null,
      ),
      createdAt: _asTimestamp(json['createdAt']),
      updatedAt: _asTimestamp(json['updatedAt']),
      endedAt: _asTimestamp(json['endedAt']),
      stageUserIds: _asStringList(json['stageUserIds']),
      audienceUserIds: _asStringList(json['audienceUserIds']),
      memberCount: _asInt(json['memberCount']),
      category: json['category'] is String ? json['category'] as String : null,
      tags: _asStringList(json['tags']),
      coHosts: _asStringList(json['coHosts']),
      isLocked: _asBool(json['isLocked']),
      allowGuestAccess: _asBool(json['allowGuestAccess'], fallback: true),
      slowModeSeconds: json['slowModeSeconds'] is num
          ? (json['slowModeSeconds'] as num).toInt()
          : null,
      maxBroadcasters: json['maxBroadcasters'] is num
          ? (json['maxBroadcasters'] as num).toInt()
          : 4,
      scheduledAt: _asTimestamp(json['scheduledAt']),
      isAdult: _asBool(json['isAdult']),
      hostUsername: json['hostUsername'] as String?,
      hostAvatarUrl: json['hostAvatarUrl'] as String?,
      theme: RoomTheme.fromJson(
        json['theme'] is Map<String, dynamic>
            ? json['theme'] as Map<String, dynamic>
            : null,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'rules': rules,
      'hostId': hostId,
      'ownerId': ownerId,
      'adminUserIds': adminUserIds,
      'isLive': isLive,
      'thumbnailUrl': thumbnailUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'endedAt': endedAt,
      'stageUserIds': stageUserIds,
      'audienceUserIds': audienceUserIds,
      'memberCount': memberCount,
      'category': category,
      'tags': tags,
      'coHosts': coHosts,
      'isLocked': isLocked,
      'allowGuestAccess': allowGuestAccess,
      'slowModeSeconds': slowModeSeconds,
      'maxBroadcasters': maxBroadcasters,
      'scheduledAt': scheduledAt,
      'isAdult': isAdult,
      'hostUsername': hostUsername,
      'hostAvatarUrl': hostAvatarUrl,
      'theme': theme.toJson(),
    };
  }

  RoomModel copyWith({
    String? id,
    String? name,
    String? description,
    String? rules,
    String? hostId,
    String? ownerId,
    List<String>? adminUserIds,
    bool? isLive,
    String? thumbnailUrl,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    Timestamp? endedAt,
    List<String>? stageUserIds,
    List<String>? audienceUserIds,
    int? memberCount,
    String? category,
    List<String>? tags,
    List<String>? coHosts,
    bool? isLocked,
    bool? allowGuestAccess,
    int? slowModeSeconds,
    int? maxBroadcasters,
    Timestamp? scheduledAt,
    bool? isAdult,
    String? hostUsername,
    String? hostAvatarUrl,
    RoomTheme? theme,
  }) {
    return RoomModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      rules: rules ?? this.rules,
      hostId: hostId ?? this.hostId,
      ownerId: ownerId ?? this.ownerId,
      adminUserIds: adminUserIds ?? this.adminUserIds,
      isLive: isLive ?? this.isLive,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      endedAt: endedAt ?? this.endedAt,
      stageUserIds: stageUserIds ?? this.stageUserIds,
      audienceUserIds: audienceUserIds ?? this.audienceUserIds,
      memberCount: memberCount ?? this.memberCount,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      coHosts: coHosts ?? this.coHosts,
      isLocked: isLocked ?? this.isLocked,
      allowGuestAccess: allowGuestAccess ?? this.allowGuestAccess,
      slowModeSeconds: slowModeSeconds ?? this.slowModeSeconds,
      maxBroadcasters: maxBroadcasters ?? this.maxBroadcasters,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      isAdult: isAdult ?? this.isAdult,
      hostUsername: hostUsername ?? this.hostUsername,
      hostAvatarUrl: hostAvatarUrl ?? this.hostAvatarUrl,
      theme: theme ?? this.theme,
    );
  }
}




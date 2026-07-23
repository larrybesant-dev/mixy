import 'package:cloud_firestore/cloud_firestore.dart';

enum MixVyRoomVisibility { public, private, password }

DateTime? _parseFirestoreDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
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

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return fallback;
}

enum MixVyRoomRole { owner, admin, moderator, vip, member, banned }

enum CamViewPolicy { everyone, friendsOnly, approvedOnly, nobody }

class RoomPolicyModel {
  const RoomPolicyModel({
    required this.roomId,
    this.visibility = MixVyRoomVisibility.public,
    this.minimumAge = 18,
    this.camLimit = 6,
    this.micLimit = 4,
    this.micTimerSeconds,
    this.allowChat = true,
    this.allowGifts = true,
    this.allowMicRequests = true,
    this.allowCamRequests = true,
    this.defaultCamViewPolicy = CamViewPolicy.approvedOnly,
    this.updatedAt,
  });

  final String roomId;
  final MixVyRoomVisibility visibility;
  final int minimumAge;
  final int camLimit;
  final int micLimit;

  /// Seconds a stage user may hold the mic before being auto-demoted.
  /// null = unlimited.
  final int? micTimerSeconds;
  final bool allowChat;
  final bool allowGifts;
  final bool allowMicRequests;
  final bool allowCamRequests;
  final CamViewPolicy defaultCamViewPolicy;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'visibility': visibility.name,
      'minimumAge': minimumAge,
      'camLimit': camLimit,
      'micLimit': micLimit,
      'micTimerSeconds': micTimerSeconds,
      'allowChat': allowChat,
      'allowGifts': allowGifts,
      'allowMicRequests': allowMicRequests,
      'allowCamRequests': allowCamRequests,
      'defaultCamViewPolicy': defaultCamViewPolicy.name,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory RoomPolicyModel.fromJson(Map<String, dynamic> json) {
    final visibilityName = _asString(json['visibility']);
    final camViewPolicyName = _asString(json['defaultCamViewPolicy']);
    return RoomPolicyModel(
      roomId: _asString(json['roomId']),
      visibility: MixVyRoomVisibility.values.firstWhere(
        (value) => value.name == visibilityName,
        orElse: () => MixVyRoomVisibility.public,
      ),
      minimumAge: (json['minimumAge'] as num?)?.toInt() ?? 18,
      camLimit: (json['camLimit'] as num?)?.toInt() ?? 6,
      micLimit: (json['micLimit'] as num?)?.toInt() ?? 4,
      micTimerSeconds: (json['micTimerSeconds'] as num?)?.toInt(),
      allowChat: _asBool(json['allowChat'], fallback: true),
      allowGifts: _asBool(json['allowGifts'], fallback: true),
      allowMicRequests: _asBool(json['allowMicRequests'], fallback: true),
      allowCamRequests: _asBool(json['allowCamRequests'], fallback: true),
      defaultCamViewPolicy: CamViewPolicy.values.firstWhere(
        (value) => value.name == camViewPolicyName,
        orElse: () => CamViewPolicy.approvedOnly,
      ),
      updatedAt: _parseFirestoreDateTime(json['updatedAt']),
    );
  }
}

class CamAccessRequestModel {
  const CamAccessRequestModel({
    required this.id,
    required this.roomId,
    required this.requesterId,
    required this.broadcasterId,
    this.status = 'pending',
    this.decisionScope = 'single_session',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String roomId;
  final String requesterId;
  final String broadcasterId;
  final String status;
  final String decisionScope;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'requesterId': requesterId,
      'broadcasterId': broadcasterId,
      'status': status,
      'decisionScope': decisionScope,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'participantIds': [requesterId, broadcasterId],
    };
  }

  factory CamAccessRequestModel.fromJson(Map<String, dynamic> json) {
    return CamAccessRequestModel(
      id: _asString(json['id']),
      roomId: _asString(json['roomId']),
      requesterId: _asString(json['requesterId']),
      broadcasterId: _asString(json['broadcasterId']),
      status: _asString(json['status'], fallback: 'pending'),
      decisionScope: _asString(
        json['decisionScope'],
        fallback: 'single_session',
      ),
      createdAt: _parseFirestoreDateTime(json['createdAt']),
      updatedAt: _parseFirestoreDateTime(json['updatedAt']),
    );
  }
}




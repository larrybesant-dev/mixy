enum ReportTargetType { user, room, message, cam }

enum ModerationStatus { open, reviewing, actioned, dismissed }

String _asString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return fallback;
}

String? _asNullableString(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

DateTime? _parseNullableDate(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

class BlockRecordModel {
  const BlockRecordModel({
    required this.id,
    required this.blockerUserId,
    required this.blockedUserId,
    this.createdAt,
  });

  final String id;
  final String blockerUserId;
  final String blockedUserId;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'blockerUserId': blockerUserId,
      'blockedUserId': blockedUserId,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory BlockRecordModel.fromJson(Map<String, dynamic> json) {
    return BlockRecordModel(
      id: _asString(json['id']),
      blockerUserId: _asString(json['blockerUserId']),
      blockedUserId: _asString(json['blockedUserId']),
      createdAt: _parseNullableDate(json['createdAt']),
    );
  }
}

class ReportRecordModel {
  const ReportRecordModel({
    required this.id,
    required this.reporterUserId,
    required this.targetId,
    required this.targetType,
    required this.reason,
    this.details,
    this.status = ModerationStatus.open,
    this.createdAt,
  });

  final String id;
  final String reporterUserId;
  final String targetId;
  final ReportTargetType targetType;
  final String reason;
  final String? details;
  final ModerationStatus status;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporterUserId': reporterUserId,
      'targetId': targetId,
      'targetType': targetType.name,
      'reason': reason,
      'details': details,
      'status': status.name,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory ReportRecordModel.fromJson(Map<String, dynamic> json) {
    final targetTypeName = _asString(json['targetType']);
    final statusName = _asString(json['status']);
    return ReportRecordModel(
      id: _asString(json['id']),
      reporterUserId: _asString(json['reporterUserId']),
      targetId: _asString(json['targetId']),
      targetType: ReportTargetType.values.firstWhere(
        (value) => value.name == targetTypeName,
        orElse: () => ReportTargetType.user,
      ),
      reason: _asString(json['reason']),
      details: _asNullableString(json['details']),
      status: ModerationStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => ModerationStatus.open,
      ),
      createdAt: _parseNullableDate(json['createdAt']),
    );
  }
}




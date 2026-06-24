// Removed unused imports
import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType {
  spam,
  harassment,
  inappropriateContent,
  hateSpeech,
  violence,
  scam,
  other
}

enum ReportStatus { pending, reviewed, resolved }

class Report {
  final String id;
  final String reporterId;
  final String reportedUserId;
  final String? reportedMessageId;
  final String? reportedRoomId;
  final ReportType type;
  final String description;
  final ReportStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  const Report({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    this.reportedMessageId,
    this.reportedRoomId,
    required this.type,
    required this.description,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
  });

  // Validation
  bool isValid() {
    return id.isNotEmpty &&
        reporterId.isNotEmpty &&
        reportedUserId.isNotEmpty &&
        reporterId != reportedUserId &&
        description.isNotEmpty &&
        description.length <= 1000;
  }

  // Check if report is pending
  bool get isPending => status == ReportStatus.pending;

  // Check if report has been reviewed
  bool get isReviewed => status != ReportStatus.pending;

  // Check if report is resolved
  bool get isResolved => status == ReportStatus.resolved;

  // fromJson
  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String? ?? '',
      reporterId: json['reporterId'] as String? ?? '',
      reportedUserId: json['reportedUserId'] as String? ?? '',
      reportedMessageId: json['reportedMessageId'] as String?,
      reportedRoomId: json['reportedRoomId'] as String?,
      type: _parseType(json['type'] as String?),
      description: json['description'] as String? ?? '',
      status: _parseStatus(json['status'] as String?),
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAt: json['reviewedAt'] != null
          ? _parseTimestamp(json['reviewedAt'])
          : null,
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  // toJson
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      if (reportedMessageId != null) 'reportedMessageId': reportedMessageId,
      if (reportedRoomId != null) 'reportedRoomId': reportedRoomId,
      'type': type.name,
      'description': description,
      'status': status.name,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // copyWith
  Report copyWith({
    String? id,
    String? reporterId,
    String? reportedUserId,
    String? reportedMessageId,
    String? reportedRoomId,
    ReportType? type,
    String? description,
    ReportStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? createdAt,
  }) {
    return Report(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      reportedUserId: reportedUserId ?? this.reportedUserId,
      reportedMessageId: reportedMessageId ?? this.reportedMessageId,
      reportedRoomId: reportedRoomId ?? this.reportedRoomId,
      type: type ?? this.type,
      description: description ?? this.description,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Report &&
        other.id == id &&
        other.reporterId == reporterId &&
        other.reportedUserId == reportedUserId &&
        other.reportedMessageId == reportedMessageId &&
        other.reportedRoomId == reportedRoomId &&
        other.type == type &&
        other.description == description &&
        other.status == status &&
        other.reviewedBy == reviewedBy &&
        other.reviewedAt == reviewedAt &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      reporterId,
      reportedUserId,
      reportedMessageId,
      reportedRoomId,
      type,
      description,
      status,
      reviewedBy,
      reviewedAt,
      createdAt,
    );
  }

  @override
  String toString() {
    return 'Report(id: $id, type: $type, reporterId: $reporterId, '
        'reportedUserId: $reportedUserId, status: $status, createdAt: $createdAt)';
  }

  // Helper methods
  static ReportType _parseType(String? type) {
    if (type == null) return ReportType.other;
    try {
      return ReportType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => ReportType.other,
      );
    } catch (_) {
      return ReportType.other;
    }
  }

  static ReportStatus _parseStatus(String? status) {
    if (status == null) return ReportStatus.pending;
    try {
      return ReportStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => ReportStatus.pending,
      );
    } catch (_) {
      return ReportStatus.pending;
    }
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) return DateTime.parse(timestamp);
    if (timestamp is DateTime) return timestamp;
    return DateTime.now();
  }
}

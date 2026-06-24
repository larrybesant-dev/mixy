/// Participant model for room presence tracking
///
/// Stores participant data and state (speaking, present, join time)
/// Used by: AgoraController, FirestoreService, ParticipantCard
library;

class Participant {
  /// Unique identifier from Agora or Firestore
  final String uid;

  /// Alias for uid for compatibility
  String get id => uid;

  /// Display name in room
  final String name;

  /// Whether participant is actively speaking
  bool isSpeaking;

  /// Whether participant is currently in room
  bool isPresent;

  /// Whether participant's audio is muted
  bool isMuted;

  /// Whether participant's video is enabled
  bool isVideoEnabled;

  /// When participant joined (for sorting, animations)
  final DateTime joinedAt;

  /// Avatar image URL (optional)
  final String? avatarUrl;

  Participant({
    required this.uid,
    required this.name,
    this.isSpeaking = false,
    this.isPresent = false,
    this.isMuted = false,
    this.isVideoEnabled = true,
    DateTime? joinedAt,
    this.avatarUrl,
  }) : joinedAt = joinedAt ?? DateTime.now();

  /// Create copy with optional field overrides
  Participant copyWith({
    String? uid,
    String? name,
    bool? isSpeaking,
    bool? isPresent,
    bool? isMuted,
    bool? isVideoEnabled,
    DateTime? joinedAt,
    String? avatarUrl,
  }) {
    return Participant(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isPresent: isPresent ?? this.isPresent,
      isMuted: isMuted ?? this.isMuted,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      joinedAt: joinedAt ?? this.joinedAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'isSpeaking': isSpeaking,
      'isPresent': isPresent,
      'isMuted': isMuted,
      'isVideoEnabled': isVideoEnabled,
      'joinedAt': joinedAt.toIso8601String(),
      'avatarUrl': avatarUrl,
    };
  }

  /// Create from Firestore document
  factory Participant.fromFirestore(String uid, Map<String, dynamic> data) {
    return Participant(
      uid: uid,
      name: data['name'] ?? 'Unknown',
      isSpeaking: data['isSpeaking'] ?? false,
      isPresent: data['isPresent'] ?? false,
      isMuted: data['isMuted'] ?? false,
      isVideoEnabled: data['isVideoEnabled'] ?? true,
      joinedAt: data['joinedAt'] != null
          ? DateTime.parse(data['joinedAt'])
          : DateTime.now(),
      avatarUrl: data['avatarUrl'],
    );
  }

  /// Create from JSON
  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      uid: json['uid'] ?? json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      isSpeaking: json['isSpeaking'] ?? false,
      isPresent: json['isPresent'] ?? false,
      isMuted: json['isMuted'] ?? false,
      isVideoEnabled: json['isVideoEnabled'] ?? true,
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : DateTime.now(),
      avatarUrl: json['avatarUrl'],
    );
  }
}

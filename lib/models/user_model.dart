import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String bio;
  final List<String> interests;
  final List<String> prompts;
  final List<String> gallery;
  final String vibe;
  final bool isOnline;
  final DateTime? lastActive;
  final String onboardingState;
  final List<String> blockedUserIds;
  final List<String> blockedByUserIds;

  // ── 18+ AGE GATE ────────────────────────────────────────────
  final DateTime? birthdate;
  final bool ageVerified;
  final int? ageAtSignup;

  // ── LOCATION-BASED FEATURES ─────────────────────────────────
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAt;

  UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.interests,
    required this.prompts,
    required this.gallery,
    required this.vibe,
    required this.isOnline,
    required this.lastActive,
    required this.onboardingState,
    this.blockedUserIds = const [],
    this.blockedByUserIds = const [],
    this.birthdate,
    this.ageVerified = false,
    this.ageAtSignup,
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
  });

  factory UserModel.empty(String id) {
    return UserModel(
      id: id,
      username: '',
      displayName: '',
      avatarUrl: '',
      bio: '',
      interests: const [],
      prompts: const [],
      gallery: const [],
      vibe: '',
      isOnline: false,
      lastActive: null,
      onboardingState: 'not_started',
      blockedUserIds: const [],
      blockedByUserIds: const [],
      ageVerified: false,
      latitude: null,
      longitude: null,
      locationUpdatedAt: null,
    );
  }

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      id: doc.id,
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      bio: data['bio'] ?? '',
      interests: List<String>.from(data['interests'] ?? []),
      prompts: List<String>.from(data['prompts'] ?? []),
      gallery: List<String>.from(data['gallery'] ?? []),
      vibe: data['vibe'] ?? '',
      isOnline: data['isOnline'] ?? false,
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
      onboardingState: data['onboardingState'] ?? 'not_started',
      blockedUserIds: List<String>.from(data['blockedUserIds'] ?? []),
      blockedByUserIds: List<String>.from(data['blockedByUserIds'] ?? []),
      birthdate: (data['birthdate'] as Timestamp?)?.toDate(),
      ageVerified: data['ageVerified'] as bool? ?? false,
      ageAtSignup: data['ageAtSignup'] as int?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      locationUpdatedAt: (data['locationUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'interests': interests,
      'prompts': prompts,
      'gallery': gallery,
      'vibe': vibe,
      'isOnline': isOnline,
      'lastActive': lastActive,
      'onboardingState': onboardingState,
      'blockedUserIds': blockedUserIds,
      'blockedByUserIds': blockedByUserIds,
      if (birthdate != null) 'birthdate': Timestamp.fromDate(birthdate!),
      'ageVerified': ageVerified,
      if (ageAtSignup != null) 'ageAtSignup': ageAtSignup,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationUpdatedAt != null) 'locationUpdatedAt': Timestamp.fromDate(locationUpdatedAt!),
    };
  }

  UserModel copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    List<String>? interests,
    List<String>? prompts,
    List<String>? gallery,
    String? vibe,
    bool? isOnline,
    DateTime? lastActive,
    String? onboardingState,
    List<String>? blockedUserIds,
    List<String>? blockedByUserIds,
    double? latitude,
    double? longitude,
    DateTime? locationUpdatedAt,
  }) {
    return UserModel(
      id: id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      prompts: prompts ?? this.prompts,
      gallery: gallery ?? this.gallery,
      vibe: vibe ?? this.vibe,
      isOnline: isOnline ?? this.isOnline,
      lastActive: lastActive ?? this.lastActive,
      onboardingState: onboardingState ?? this.onboardingState,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
      blockedByUserIds: blockedByUserIds ?? this.blockedByUserIds,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final String username;
  final String bio;
  final String location;
  final List<String> interests;
  final String avatarUrl;
  final int coinBalance;
  final String statusMessage;
  final int followersCount;
  final int followingCount;
  final int totalTipsReceived;
  final int liveSessionsHosted;
  final Map<String, String> socialLinks;
  final String? featuredRoomId;
  final String? featuredContentUrl;
  final List<Map<String, dynamic>> topGifts;
  final List<String> recentMediaUrls;
  final List<Map<String, dynamic>> recentActivity;
  final String? lookingFor;
  final int? minAgePreference;
  final int? maxAgePreference;
  final int? maxDistancePreference;

  // NEW SOCIAL FEATURES FIELDS
  final String? nickname;
  final bool isOnline;
  final DateTime? lastSeen;
  final String membershipTier;
  final List<String> badges;

  // AGE GATE & PROFILE COMPLETION
  final bool ageVerified;
  final bool profileComplete;

  // ONBOARDING
  final bool onboardingComplete;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.createdAt,
    required this.username,
    required this.bio,
    required this.location,
    required this.interests,
    required this.avatarUrl,
    required this.coinBalance,
    required this.statusMessage,
    required this.followersCount,
    required this.followingCount,
    required this.totalTipsReceived,
    required this.liveSessionsHosted,
    required this.socialLinks,
    this.featuredRoomId,
    this.featuredContentUrl,
    required this.topGifts,
    required this.recentMediaUrls,
    required this.recentActivity,
    this.lookingFor,
    this.minAgePreference,
    this.maxAgePreference,
    this.maxDistancePreference,
    this.nickname,
    required this.isOnline,
    this.lastSeen,
    required this.membershipTier,
    required this.badges,
    this.ageVerified = false,
    this.profileComplete = false,
    this.onboardingComplete = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'],
      photoUrl: json['photoUrl'],
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.parse(json['createdAt'] as String))
          : DateTime.now(),
      username: json['username'] ?? '',
      bio: json['bio'] ?? '',
      location: json['location'] ?? '',
      interests: List<String>.from(json['interests'] ?? []),
      avatarUrl: json['avatarUrl'] ?? '',
      coinBalance: json['coinBalance'] ?? 0,
      statusMessage: json['statusMessage'] ?? 'Available',
      followersCount: json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
      totalTipsReceived: json['totalTipsReceived'] ?? 0,
      liveSessionsHosted: json['liveSessionsHosted'] ?? 0,
      socialLinks: Map<String, String>.from(json['socialLinks'] ?? {}),
      featuredRoomId: json['featuredRoomId'],
      featuredContentUrl: json['featuredContentUrl'],
      topGifts: List<Map<String, dynamic>>.from(json['topGifts'] ?? []),
      recentMediaUrls: List<String>.from(json['recentMediaUrls'] ?? []),
      recentActivity:
          List<Map<String, dynamic>>.from(json['recentActivity'] ?? []),
      lookingFor: json['lookingFor'],
      minAgePreference: json['minAgePreference'],
      maxAgePreference: json['maxAgePreference'],
      maxDistancePreference: json['maxDistancePreference'],
      nickname: json['nickname'],
      isOnline: json['isOnline'] ?? false,
      lastSeen: json['lastSeen'] != null
          ? (json['lastSeen'] is Timestamp
              ? (json['lastSeen'] as Timestamp).toDate()
              : DateTime.parse(json['lastSeen']))
          : null,
      membershipTier: json['membershipTier'] ?? 'free',
      badges: List<String>.from(json['badges'] ?? []),
      ageVerified: json['ageVerified'] as bool? ?? false,
      profileComplete: json['profileComplete'] as bool? ?? false,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'username': username,
      'bio': bio,
      'location': location,
      'interests': interests,
      'avatarUrl': avatarUrl,
      'coinBalance': coinBalance,
      'statusMessage': statusMessage,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'totalTipsReceived': totalTipsReceived,
      'liveSessionsHosted': liveSessionsHosted,
      'socialLinks': socialLinks,
      'featuredRoomId': featuredRoomId,
      'featuredContentUrl': featuredContentUrl,
      'topGifts': topGifts,
      'recentMediaUrls': recentMediaUrls,
      'recentActivity': recentActivity,
      'lookingFor': lookingFor,
      'minAgePreference': minAgePreference,
      'maxAgePreference': maxAgePreference,
      'maxDistancePreference': maxDistancePreference,
      'nickname': nickname,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'membershipTier': membershipTier,
      'badges': badges,
      'ageVerified': ageVerified,
      'profileComplete': profileComplete,
      'onboardingComplete': onboardingComplete,
    };
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User.fromJson(map);
  }

  factory User.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return User.fromMap(data);
  }
}

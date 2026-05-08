import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/core/utils/network_image_url.dart';

class UserModel {
  final String id;
  final String email;
  final String username;
  final String? avatarUrl;
  final String? coverPhotoUrl;
  final List<String> galleryUrls;
  final String? introVideoUrl;
  final String? bio;
  final String? aboutMe;
  final int? age;
  final String? gender;
  final String? location;
  final String? relationshipStatus;
  final String? vibePrompt;
  final String? firstDatePrompt;
  final String? musicTastePrompt;
  final List<String> interests;
  final DateTime createdAt;
  final int coinBalance;
  final String membershipLevel;
  final List<String> followers;
  final String camViewPolicy;
  final bool adultModeEnabled;
  final bool adultConsentAccepted;
  final String themeId;
  final int vipLevel;
  final List<String> badges;
  // Profile personalisation
  final String? profileAccentColor;
  final String? profileBgGradientStart;
  final String? profileBgGradientEnd;
  final String? profileMusicUrl;
  final String? profileMusicTitle;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    this.avatarUrl,
    this.coverPhotoUrl,
    this.galleryUrls = const [],
    this.introVideoUrl,
    this.bio,
    this.aboutMe,
    this.age,
    this.gender,
    this.location,
    this.relationshipStatus,
    this.vibePrompt,
    this.firstDatePrompt,
    this.musicTastePrompt,
    this.interests = const [],
    required this.createdAt,
    this.coinBalance = 0,
    this.membershipLevel = 'basic',
    this.followers = const [],
    this.camViewPolicy = 'approvedOnly',
    this.adultModeEnabled = false,
    this.adultConsentAccepted = false,
    this.themeId = 'midnight',
    this.vipLevel = 0,
    this.badges = const [],
    this.profileAccentColor,
    this.profileBgGradientStart,
    this.profileBgGradientEnd,
    this.profileMusicUrl,
    this.profileMusicTitle,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: _stringOrEmpty(json['id'] ?? json['uid']),
    email: _stringOrEmpty(json['email']),
    username: _resolvedUsername(json),
    avatarUrl: sanitizeNetworkImageUrl(
      _stringOrNull(json['avatarUrl'] ?? json['photoUrl']),
    ),
    coverPhotoUrl: sanitizeNetworkImageUrl(
      _stringOrNull(json['coverPhotoUrl']),
    ),
    galleryUrls: _stringList(json['galleryUrls']),
    introVideoUrl: _stringOrNull(json['introVideoUrl']),
    bio: _stringOrNull(json['bio']),
    aboutMe: _stringOrNull(json['aboutMe']),
    age: (json['age'] as num?)?.toInt(),
    gender: _stringOrNull(json['gender']),
    location: _stringOrNull(json['location']),
    relationshipStatus: _stringOrNull(json['relationshipStatus']),
    vibePrompt: _stringOrNull(json['vibePrompt']),
    firstDatePrompt: _stringOrNull(json['firstDatePrompt']),
    musicTastePrompt: _stringOrNull(json['musicTastePrompt']),
    interests: _stringList(json['interests']),
    createdAt: (json['createdAt'] is Timestamp)
        ? (json['createdAt'] as Timestamp).toDate()
        : DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
              DateTime.now(),
    coinBalance:
        ((json['balance'] ?? json['coinBalance']) as num?)?.toInt() ?? 0,
    membershipLevel: _stringOrEmpty(json['membershipLevel'], fallback: 'basic'),
    followers: _stringList(json['followers']),
    camViewPolicy: _stringOrEmpty(
      json['camViewPolicy'],
      fallback: 'approvedOnly',
    ),
    adultModeEnabled: _boolOr(json['adultModeEnabled'], fallback: false),
    adultConsentAccepted: _boolOr(
      json['adultConsentAccepted'],
      fallback: false,
    ),
    themeId: _stringOrEmpty(json['themeId'], fallback: 'midnight'),
    vipLevel: (json['vipLevel'] as num?)?.toInt() ?? 0,
    badges: _stringList(json['badges']),
    profileAccentColor: _stringOrNull(json['profileAccentColor']),
    profileBgGradientStart: _stringOrNull(json['profileBgGradientStart']),
    profileBgGradientEnd: _stringOrNull(json['profileBgGradientEnd']),
    profileMusicUrl: _stringOrNull(json['profileMusicUrl']),
    profileMusicTitle: _stringOrNull(json['profileMusicTitle']),
  );

  static bool _boolOr(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return fallback;
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value.toString().trim().isEmpty ? null : value.toString().trim();
  }

  static String _stringOrEmpty(dynamic value, {String fallback = ''}) {
    final parsed = _stringOrNull(value);
    return parsed ?? fallback;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => _stringOrNull(item))
        .whereType<String>()
        .toSet()
        .toList(growable: false);
  }

  static String _resolvedUsername(Map<String, dynamic> json) {
    final explicit = _stringOrNull(json['username']);
    if (explicit != null) {
      return explicit;
    }

    final displayName = _stringOrNull(json['displayName'] ?? json['name']);
    if (displayName != null) {
      return displayName;
    }

    final email = _stringOrNull(json['email']);
    if (email != null && email.contains('@')) {
      final handle = email.split('@').first.trim();
      if (handle.isNotEmpty) {
        return handle;
      }
    }

    final id = _stringOrNull(json['id'] ?? json['uid']) ?? '';
    final compact = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (compact.isEmpty) {
      return 'MixVy Member';
    }
    final suffix = compact.substring(
      0,
      compact.length < 4 ? compact.length : 4,
    );
    return 'Member $suffix';
  }

  String get uid => id;
  String get displayName => username;
  String? get photoUrl => avatarUrl;
  bool get isComplete => username.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'uid': id,
    'email': email,
    'username': username,
    'displayName': username,
    'avatarUrl': avatarUrl,
    'photoUrl': avatarUrl,
    'isComplete': isComplete,
    'coverPhotoUrl': coverPhotoUrl,
    'galleryUrls': galleryUrls,
    'introVideoUrl': introVideoUrl,
    'bio': bio,
    'aboutMe': aboutMe,
    'age': age,
    'gender': gender,
    'location': location,
    'relationshipStatus': relationshipStatus,
    'vibePrompt': vibePrompt,
    'firstDatePrompt': firstDatePrompt,
    'musicTastePrompt': musicTastePrompt,
    'interests': interests,
    'createdAt': createdAt.toIso8601String(),
    'balance': coinBalance,
    'coinBalance': coinBalance,
    'membershipLevel': membershipLevel,
    'followers': followers,
    'camViewPolicy': camViewPolicy,
    'adultModeEnabled': adultModeEnabled,
    'adultConsentAccepted': adultConsentAccepted,
    'themeId': themeId,
    'profileAccentColor': profileAccentColor,
    'profileBgGradientStart': profileBgGradientStart,
    'profileBgGradientEnd': profileBgGradientEnd,
    'profileMusicUrl': profileMusicUrl,
    'profileMusicTitle': profileMusicTitle,
  };

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return UserModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }
}

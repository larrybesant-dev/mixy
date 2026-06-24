import 'package:cloud_firestore/cloud_firestore.dart';

/// The active mode displayed at top of profile.
enum ProfileMode { social, dating, creator, eventHost }

/// Source platform for a user's favourite track preview.
enum TrackSource { spotify, appleMusic, soundcloud, internal, other }

class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String? nickname;
  final String? photoUrl;
  final String? coverPhotoUrl;
  final List<String>? galleryPhotos;
  final List<String>? galleryVideos;
  final List<String>? badgeIds;
  final List<String>? interests;
  final String? location;
  final double? latitude;
  final double? longitude;
  final DateTime? birthday;
  final String? gender;
  final String? pronouns;
  final String? bio;
  final List<String>?
      lookingFor; // friends, dating, networking, activity partners
  final String? relationshipType; // casual, serious, long-term
  final int? minAgePreference;
  final int? maxAgePreference;
  final List<String>? preferredGenders;
  final Map<String, String>?
      personalityPrompts; // "My ideal day...", "A green flag..."
  final List<String>? musicTastes;
  final Map<String, bool>?
      lifestylePrompts; // smoking, drinking, fitness, pets, kids
  final bool? isPhotoVerified;
  final bool? isPhoneVerified;
  final bool? isEmailVerified;
  final bool? isIdVerified;
  final Map<String, String>?
      socialLinks; // Instagram, TikTok, Snapchat, X/Twitter
  final bool? verifiedOnlyMode;
  final bool? privateMode;
  final int followersCount;
  final int followingCount;
  final String? presenceStatus; // online, offline, in_room, in_event
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Profile Mode (Layer Router) ─────────────────────────────
  final ProfileMode profileMode;

  // ── Layer 1 extras: Attraction ──────────────────────────────
  final bool isPremium;
  final bool isCreatorBadge;

  // ── Layer 2: Live Presence ──────────────────────────────────
  final int roomsHostedCount;
  final double avgRoomRating;
  final String? topCategory;
  final int eventsHostingCount;
  final String? activeRoomId;

  // ── Layer 3: Social Proof ───────────────────────────────────
  final int mutualsCount;
  final int eventsAttended;
  final double communityRating;
  final int totalRoomsJoined;

  // ── Layer 4: Creator Monetization (18+) ─────────────────────
  final bool isCreatorEnabled;
  final bool is18PlusVerified; // age-verified gate, required for adult content
  final bool isAdultContentEnabled; // explicit content flag, 18+ only
  final double? subscriptionPrice; // monthly USD
  final int subscriberCount;
  final String? creatorHeadline;
  final bool hasPaidRooms;
  final bool hasContentVault;
  final double totalEarnings; // private – only shown to owner

  // ── Layer 5: Safety / Control ────────────────────────────────
  final String dmRestriction; // 'everyone' | 'followers' | 'nobody'
  final bool hideDistance;
  final bool hideFollowers;
  final bool restrictRoomInvites;
  final bool twoFactorEnabled;

  // ── Onboarding ──────────────────────────────────────────────
  /// Set to true once the user has dismissed the first-run welcome overlay.
  /// Used to show the welcome tour exactly once per new account.
  final bool onboardingComplete;

  // ── Sprint 1: Vibe & Genres ──────────────────────────────────
  /// The user's chosen energy vibe (e.g. "Chill", "Hype", "Deep Talk").
  /// Displayed on the NeonProfileCard and used in search/room filters.
  final String? vibeTag;

  /// Favourite music genres (e.g. "Afrobeat", "Lo-Fi", "House").
  /// Distinct from the legacy free-form [musicTastes] field.
  final List<String>? musicGenres;

  /// ISO 3166-1 alpha-2 country code (e.g. "GB", "NG").
  /// Converted to a flag emoji on the NeonProfileCard.
  final String? countryCode;

  // ── Sprint 4 Stubs: Monetisation Rails (read-only until enabled) ─
  /// VIP tier: null | 'bronze' | 'silver' | 'gold'
  final String? vipTier;

  /// True when the user has any active VIP entitlement.
  final bool isVip;

  /// True when the user has an active profile boost.
  final bool isBoosted;

  /// When the active boost expires. Null when not boosted.
  final DateTime? boostExpiresAt;

  // ── Intelligence Layer: Self-Improving Systems ───────────────
  /// Vibe join history: maps vibe name → cumulative join count.
  /// Incremented by VibeIntelligenceService on every room join.
  final Map<String, int> vibeHistory;

  /// Behavior-computed tags written by a Cloud Function nightly.
  /// Examples: "Night Owl", "Super Host", "Party Animal"
  final List<String> computedTags;

  // ── Profile Music (MySpace-style) ────────────────────────────
  /// Platform-specific track ID (Spotify track ID, etc.).
  final String? favoriteTrackId;

  /// Where the track comes from.
  final TrackSource? favoriteTrackSource;

  /// Direct URL to a short audio preview (10–30 s).
  final String? favoriteTrackPreviewUrl;

  /// Display title of the track.
  final String? favoriteTrackTitle;

  /// Display artist name.
  final String? favoriteTrackArtist;

  UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.nickname,
    this.photoUrl,
    this.coverPhotoUrl,
    this.galleryPhotos,
    this.galleryVideos,
    this.badgeIds,
    this.interests,
    this.location,
    this.latitude,
    this.longitude,
    this.birthday,
    this.gender,
    this.pronouns,
    this.bio,
    this.lookingFor,
    this.relationshipType,
    this.minAgePreference,
    this.maxAgePreference,
    this.preferredGenders,
    this.personalityPrompts,
    this.musicTastes,
    this.lifestylePrompts,
    this.isPhotoVerified,
    this.isPhoneVerified,
    this.isEmailVerified,
    this.isIdVerified,
    this.socialLinks,
    this.verifiedOnlyMode,
    this.privateMode,
    this.followersCount = 0,
    this.followingCount = 0,
    this.presenceStatus,
    required this.createdAt,
    required this.updatedAt,
    // new fields
    this.profileMode = ProfileMode.social,
    this.isPremium = false,
    this.isCreatorBadge = false,
    this.roomsHostedCount = 0,
    this.avgRoomRating = 0.0,
    this.topCategory,
    this.eventsHostingCount = 0,
    this.activeRoomId,
    this.mutualsCount = 0,
    this.eventsAttended = 0,
    this.communityRating = 0.0,
    this.totalRoomsJoined = 0,
    this.isCreatorEnabled = false,
    this.is18PlusVerified = false,
    this.isAdultContentEnabled = false,
    this.subscriptionPrice,
    this.subscriberCount = 0,
    this.creatorHeadline,
    this.hasPaidRooms = false,
    this.hasContentVault = false,
    this.totalEarnings = 0.0,
    this.dmRestriction = 'everyone',
    this.hideDistance = false,
    this.hideFollowers = false,
    this.restrictRoomInvites = false,
    this.twoFactorEnabled = false,
    this.onboardingComplete = false,
    // Sprint 1
    this.vibeTag,
    this.musicGenres,
    this.countryCode,
    // Sprint 4 stubs
    this.vipTier,
    this.isVip = false,
    this.isBoosted = false,
    this.boostExpiresAt,
    // Intelligence layer
    this.vibeHistory = const {},
    this.computedTags = const [],
    // Profile music
    this.favoriteTrackId,
    this.favoriteTrackSource,
    this.favoriteTrackPreviewUrl,
    this.favoriteTrackTitle,
    this.favoriteTrackArtist,
  });

  // Computed property for age
  int? get age {
    if (birthday == null) return null;
    final now = DateTime.now();
    final birthYear = birthday!.year;
    final birthMonth = birthday!.month;
    final birthDay = birthday!.day;
    int age = now.year - birthYear;
    if (now.month < birthMonth ||
        (now.month == birthMonth && now.day < birthDay)) {
      age--;
    }
    return age;
  }

  // Convenience getters for backward compatibility
  List<String> get photos => galleryPhotos ?? [];
  String? get profileImageUrl => photoUrl;
  String? get username => displayName ?? nickname;
  bool get isOnline => false; // Default to false, override with presence data

  // ── Intelligence: computed getters ──────────────────────────

  /// The vibe the user has joined most. Falls back to [vibeTag] if no history.
  String? get topVibe {
    if (vibeHistory.isEmpty) return vibeTag;
    return vibeHistory.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// How many times the user has joined their top vibe.
  int get topVibeCount => topVibe != null ? (vibeHistory[topVibe] ?? 0) : 0;

  /// Energy score (0–100) computed from activity metrics.
  int get energyScore {
    final raw =
        (roomsHostedCount * 3) + (eventsAttended * 2) + totalRoomsJoined;
    return raw.clamp(0, 100);
  }

  /// The user's second-most-joined vibe (useful for suggestions).
  String? get secondVibe {
    if (vibeHistory.length < 2) return null;
    final sorted = vibeHistory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted[1].key;
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    ProfileMode parseMode(String? v) {
      switch (v) {
        case 'dating':
          return ProfileMode.dating;
        case 'creator':
          return ProfileMode.creator;
        case 'eventHost':
          return ProfileMode.eventHost;
        default:
          return ProfileMode.social;
      }
    }

    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String?,
      nickname: map['nickname'] as String?,
      photoUrl: map['photoUrl'] as String?,
      coverPhotoUrl: map['coverPhotoUrl'] as String?,
      galleryPhotos: (map['galleryPhotos'] as List<dynamic>?)?.cast<String>(),
      galleryVideos: (map['galleryVideos'] as List<dynamic>?)?.cast<String>(),
      badgeIds: (map['badgeIds'] as List<dynamic>?)?.cast<String>(),
      interests: (map['interests'] as List<dynamic>?)?.cast<String>(),
      location: map['location'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      birthday: map['birthday'] != null
          ? (map['birthday'] as Timestamp).toDate()
          : null,
      gender: map['gender'] as String?,
      pronouns: map['pronouns'] as String?,
      bio: map['bio'] as String?,
      lookingFor: (map['lookingFor'] as List<dynamic>?)?.cast<String>(),
      relationshipType: map['relationshipType'] as String?,
      minAgePreference: map['minAgePreference'] as int?,
      maxAgePreference: map['maxAgePreference'] as int?,
      preferredGenders:
          (map['preferredGenders'] as List<dynamic>?)?.cast<String>(),
      personalityPrompts: (map['personalityPrompts'] as Map<String, dynamic>?)
          ?.cast<String, String>(),
      musicTastes: (map['musicTastes'] as List<dynamic>?)?.cast<String>(),
      lifestylePrompts: (map['lifestylePrompts'] as Map<String, dynamic>?)
          ?.cast<String, bool>(),
      isPhotoVerified: map['isPhotoVerified'] as bool?,
      isPhoneVerified: map['isPhoneVerified'] as bool?,
      isEmailVerified: map['isEmailVerified'] as bool?,
      isIdVerified: map['isIdVerified'] as bool?,
      socialLinks:
          (map['socialLinks'] as Map<String, dynamic>?)?.cast<String, String>(),
      verifiedOnlyMode: map['verifiedOnlyMode'] as bool?,
      privateMode: map['privateMode'] as bool?,
      followersCount: map['followersCount'] as int? ?? 0,
      followingCount: map['followingCount'] as int? ?? 0,
      presenceStatus: map['presenceStatus'] as String?,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(map['updatedAt'] as String),
      // new fields
      profileMode: parseMode(map['profileMode'] as String?),
      isPremium: map['isPremium'] as bool? ?? false,
      isCreatorBadge: map['isCreatorBadge'] as bool? ?? false,
      roomsHostedCount: map['roomsHostedCount'] as int? ?? 0,
      avgRoomRating: (map['avgRoomRating'] as num?)?.toDouble() ?? 0.0,
      topCategory: map['topCategory'] as String?,
      eventsHostingCount: map['eventsHostingCount'] as int? ?? 0,
      activeRoomId: map['activeRoomId'] as String?,
      mutualsCount: map['mutualsCount'] as int? ?? 0,
      eventsAttended: map['eventsAttended'] as int? ?? 0,
      communityRating: (map['communityRating'] as num?)?.toDouble() ?? 0.0,
      totalRoomsJoined: map['totalRoomsJoined'] as int? ?? 0,
      isCreatorEnabled: map['isCreatorEnabled'] as bool? ?? false,
      is18PlusVerified: map['is18PlusVerified'] as bool? ?? false,
      isAdultContentEnabled: map['isAdultContentEnabled'] as bool? ?? false,
      subscriptionPrice: (map['subscriptionPrice'] as num?)?.toDouble(),
      subscriberCount: map['subscriberCount'] as int? ?? 0,
      creatorHeadline: map['creatorHeadline'] as String?,
      hasPaidRooms: map['hasPaidRooms'] as bool? ?? false,
      hasContentVault: map['hasContentVault'] as bool? ?? false,
      totalEarnings: (map['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      dmRestriction: map['dmRestriction'] as String? ?? 'everyone',
      hideDistance: map['hideDistance'] as bool? ?? false,
      hideFollowers: map['hideFollowers'] as bool? ?? false,
      restrictRoomInvites: map['restrictRoomInvites'] as bool? ?? false,
      twoFactorEnabled: map['twoFactorEnabled'] as bool? ?? false,
      onboardingComplete: map['onboardingComplete'] as bool? ?? false,
      // Sprint 1
      vibeTag: map['vibeTag'] as String?,
      musicGenres: (map['musicGenres'] as List<dynamic>?)?.cast<String>(),
      countryCode: map['countryCode'] as String?,
      // Sprint 4 stubs
      vipTier: map['vipTier'] as String?,
      isVip: map['isVip'] as bool? ?? false,
      isBoosted: map['isBoosted'] as bool? ?? false,
      boostExpiresAt: map['boostExpiresAt'] is Timestamp
          ? (map['boostExpiresAt'] as Timestamp).toDate()
          : null,
      // Intelligence layer
      vibeHistory: (map['vibeHistory'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
          const {},
      computedTags:
          (map['computedTags'] as List<dynamic>?)?.cast<String>() ?? const [],
      // Profile music
      favoriteTrackId: map['favoriteTrackId'] as String?,
      favoriteTrackSource:
          _parseTrackSource(map['favoriteTrackSource'] as String?),
      favoriteTrackPreviewUrl: map['favoriteTrackPreviewUrl'] as String?,
      favoriteTrackTitle: map['favoriteTrackTitle'] as String?,
      favoriteTrackArtist: map['favoriteTrackArtist'] as String?,
    );
  }

  static TrackSource? _parseTrackSource(String? raw) {
    switch (raw) {
      case 'spotify':
        return TrackSource.spotify;
      case 'appleMusic':
        return TrackSource.appleMusic;
      case 'soundcloud':
        return TrackSource.soundcloud;
      case 'internal':
        return TrackSource.internal;
      case 'other':
        return TrackSource.other;
      default:
        return null;
    }
  }

  // ── Public profile: safe to expose to any authenticated user ──
  Map<String, dynamic> toPublicMap() {
    return {
      'id': id,
      'displayName': displayName,
      'nickname': nickname,
      'photoUrl': photoUrl,
      'coverPhotoUrl': coverPhotoUrl,
      'galleryPhotos': galleryPhotos,
      'galleryVideos': galleryVideos,
      'badgeIds': badgeIds,
      'interests': interests,
      'location': location, // city-level only, no lat/lng
      'gender': gender,
      'pronouns': pronouns,
      'bio': bio,
      'socialLinks': socialLinks,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'presenceStatus': presenceStatus,
      'profileMode': profileMode.name,
      'isPremium': isPremium,
      'isCreatorBadge': isCreatorBadge,
      'isCreatorEnabled': isCreatorEnabled,
      'creatorHeadline': creatorHeadline,
      'subscriberCount': subscriberCount,
      'hasPaidRooms': hasPaidRooms,
      'hasContentVault': hasContentVault,
      'roomsHostedCount': roomsHostedCount,
      'avgRoomRating': avgRoomRating,
      'topCategory': topCategory,
      'eventsHostingCount': eventsHostingCount,
      'activeRoomId': activeRoomId,
      'mutualsCount': mutualsCount,
      'eventsAttended': eventsAttended,
      'communityRating': communityRating,
      'totalRoomsJoined': totalRoomsJoined,
      'isPhotoVerified': isPhotoVerified,
      'isPhoneVerified': isPhoneVerified,
      'isEmailVerified': isEmailVerified,
      'isIdVerified': isIdVerified,
      'is18PlusVerified': is18PlusVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      // Sprint 1
      'vibeTag': vibeTag,
      'musicGenres': musicGenres,
      'countryCode': countryCode,
      // Sprint 4 stubs
      'vipTier': vipTier,
      'isVip': isVip,
      'isBoosted': isBoosted,
      'boostExpiresAt': boostExpiresAt != null
          ? Timestamp.fromDate(boostExpiresAt!)
          : null, // Intelligence layer
      'vibeHistory': vibeHistory,
      'computedTags': computedTags,
      // Profile music (public – shared on profile view)
      'favoriteTrackId': favoriteTrackId,
      'favoriteTrackSource': favoriteTrackSource?.name,
      'favoriteTrackPreviewUrl': favoriteTrackPreviewUrl,
      'favoriteTrackTitle': favoriteTrackTitle,
      'favoriteTrackArtist': favoriteTrackArtist,
    };
  }

  // ── Private profile: owner-only sensitive data ──
  Map<String, dynamic> toPrivateMap() {
    return {
      'userId': id,
      'email': email,
      'isAdultContentEnabled': isAdultContentEnabled,
      'subscriptionPrice': subscriptionPrice,
      'totalEarnings': totalEarnings,
      'dmRestriction': dmRestriction,
      'hideDistance': hideDistance,
      'hideFollowers': hideFollowers,
      'restrictRoomInvites': restrictRoomInvites,
      'twoFactorEnabled': twoFactorEnabled,
      'verifiedOnlyMode': verifiedOnlyMode,
      'privateMode': privateMode,
      'latitude': latitude,
      'longitude': longitude,
      // Dating preferences — private
      'lookingFor': lookingFor,
      'relationshipType': relationshipType,
      'minAgePreference': minAgePreference,
      'maxAgePreference': maxAgePreference,
      'preferredGenders': preferredGenders,
      'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'nickname': nickname,
      'photoUrl': photoUrl,
      'coverPhotoUrl': coverPhotoUrl,
      'galleryPhotos': galleryPhotos,
      'galleryVideos': galleryVideos,
      'badgeIds': badgeIds,
      'interests': interests,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
      'gender': gender,
      'pronouns': pronouns,
      'bio': bio,
      'lookingFor': lookingFor,
      'relationshipType': relationshipType,
      'minAgePreference': minAgePreference,
      'maxAgePreference': maxAgePreference,
      'preferredGenders': preferredGenders,
      'personalityPrompts': personalityPrompts,
      'musicTastes': musicTastes,
      'lifestylePrompts': lifestylePrompts,
      'isPhotoVerified': isPhotoVerified,
      'isPhoneVerified': isPhoneVerified,
      'isEmailVerified': isEmailVerified,
      'isIdVerified': isIdVerified,
      'socialLinks': socialLinks,
      'verifiedOnlyMode': verifiedOnlyMode,
      'privateMode': privateMode,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'presenceStatus': presenceStatus,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      // new fields
      'profileMode': profileMode.name,
      'isPremium': isPremium,
      'isCreatorBadge': isCreatorBadge,
      'roomsHostedCount': roomsHostedCount,
      'avgRoomRating': avgRoomRating,
      'topCategory': topCategory,
      'eventsHostingCount': eventsHostingCount,
      'activeRoomId': activeRoomId,
      'mutualsCount': mutualsCount,
      'eventsAttended': eventsAttended,
      'communityRating': communityRating,
      'totalRoomsJoined': totalRoomsJoined,
      'isCreatorEnabled': isCreatorEnabled,
      'is18PlusVerified': is18PlusVerified,
      'isAdultContentEnabled': isAdultContentEnabled,
      'subscriptionPrice': subscriptionPrice,
      'subscriberCount': subscriberCount,
      'creatorHeadline': creatorHeadline,
      'hasPaidRooms': hasPaidRooms,
      'hasContentVault': hasContentVault,
      // NOTE: totalEarnings is never exposed in public profile reads
      'dmRestriction': dmRestriction,
      'hideDistance': hideDistance,
      'hideFollowers': hideFollowers,
      'restrictRoomInvites': restrictRoomInvites,
      'twoFactorEnabled': twoFactorEnabled,
      'onboardingComplete': onboardingComplete,
      // Sprint 1
      'vibeTag': vibeTag,
      'musicGenres': musicGenres,
      'countryCode': countryCode,
      // Sprint 4 stubs
      'vipTier': vipTier,
      'isVip': isVip,
      'isBoosted': isBoosted,
      'boostExpiresAt':
          boostExpiresAt != null ? Timestamp.fromDate(boostExpiresAt!) : null,
      // Intelligence layer
      'vibeHistory': vibeHistory,
      'computedTags': computedTags,
      // Profile music
      'favoriteTrackId': favoriteTrackId,
      'favoriteTrackSource': favoriteTrackSource?.name,
      'favoriteTrackPreviewUrl': favoriteTrackPreviewUrl,
      'favoriteTrackTitle': favoriteTrackTitle,
      'favoriteTrackArtist': favoriteTrackArtist,
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? nickname,
    String? photoUrl,
    String? coverPhotoUrl,
    List<String>? galleryPhotos,
    List<String>? galleryVideos,
    List<String>? badgeIds,
    List<String>? interests,
    String? location,
    double? latitude,
    double? longitude,
    DateTime? birthday,
    String? gender,
    String? bio,
    DateTime? updatedAt,
    ProfileMode? profileMode,
    bool? isPremium,
    bool? isCreatorBadge,
    int? roomsHostedCount,
    double? avgRoomRating,
    String? topCategory,
    int? eventsHostingCount,
    String? activeRoomId,
    int? mutualsCount,
    int? eventsAttended,
    double? communityRating,
    int? totalRoomsJoined,
    bool? isCreatorEnabled,
    bool? is18PlusVerified,
    bool? isAdultContentEnabled,
    double? subscriptionPrice,
    int? subscriberCount,
    String? creatorHeadline,
    bool? hasPaidRooms,
    bool? hasContentVault,
    double? totalEarnings,
    String? dmRestriction,
    bool? hideDistance,
    bool? hideFollowers,
    bool? restrictRoomInvites,
    bool? twoFactorEnabled,
    bool? onboardingComplete,
    // Sprint 1
    String? vibeTag,
    List<String>? musicGenres,
    String? countryCode,
    // Sprint 4 stubs
    String? vipTier,
    bool? isVip,
    bool? isBoosted,
    DateTime? boostExpiresAt,
    // Intelligence layer
    Map<String, int>? vibeHistory,
    List<String>? computedTags,
    // Profile music
    String? favoriteTrackId,
    TrackSource? favoriteTrackSource,
    String? favoriteTrackPreviewUrl,
    String? favoriteTrackTitle,
    String? favoriteTrackArtist,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      nickname: nickname ?? this.nickname,
      photoUrl: photoUrl ?? this.photoUrl,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      galleryPhotos: galleryPhotos ?? this.galleryPhotos,
      galleryVideos: galleryVideos ?? this.galleryVideos,
      badgeIds: badgeIds ?? this.badgeIds,
      interests: interests ?? this.interests,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      profileMode: profileMode ?? this.profileMode,
      isPremium: isPremium ?? this.isPremium,
      isCreatorBadge: isCreatorBadge ?? this.isCreatorBadge,
      roomsHostedCount: roomsHostedCount ?? this.roomsHostedCount,
      avgRoomRating: avgRoomRating ?? this.avgRoomRating,
      topCategory: topCategory ?? this.topCategory,
      eventsHostingCount: eventsHostingCount ?? this.eventsHostingCount,
      activeRoomId: activeRoomId ?? this.activeRoomId,
      mutualsCount: mutualsCount ?? this.mutualsCount,
      eventsAttended: eventsAttended ?? this.eventsAttended,
      communityRating: communityRating ?? this.communityRating,
      totalRoomsJoined: totalRoomsJoined ?? this.totalRoomsJoined,
      isCreatorEnabled: isCreatorEnabled ?? this.isCreatorEnabled,
      is18PlusVerified: is18PlusVerified ?? this.is18PlusVerified,
      isAdultContentEnabled:
          isAdultContentEnabled ?? this.isAdultContentEnabled,
      subscriptionPrice: subscriptionPrice ?? this.subscriptionPrice,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      creatorHeadline: creatorHeadline ?? this.creatorHeadline,
      hasPaidRooms: hasPaidRooms ?? this.hasPaidRooms,
      hasContentVault: hasContentVault ?? this.hasContentVault,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      dmRestriction: dmRestriction ?? this.dmRestriction,
      hideDistance: hideDistance ?? this.hideDistance,
      hideFollowers: hideFollowers ?? this.hideFollowers,
      restrictRoomInvites: restrictRoomInvites ?? this.restrictRoomInvites,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      // Sprint 1
      vibeTag: vibeTag ?? this.vibeTag,
      musicGenres: musicGenres ?? this.musicGenres,
      countryCode: countryCode ?? this.countryCode,
      // Sprint 4 stubs
      vipTier: vipTier ?? this.vipTier,
      isVip: isVip ?? this.isVip,
      isBoosted: isBoosted ?? this.isBoosted,
      boostExpiresAt: boostExpiresAt ?? this.boostExpiresAt,
      // Intelligence layer
      vibeHistory: vibeHistory ?? this.vibeHistory,
      computedTags: computedTags ?? this.computedTags,
      // Profile music
      favoriteTrackId: favoriteTrackId ?? this.favoriteTrackId,
      favoriteTrackSource: favoriteTrackSource ?? this.favoriteTrackSource,
      favoriteTrackPreviewUrl:
          favoriteTrackPreviewUrl ?? this.favoriteTrackPreviewUrl,
      favoriteTrackTitle: favoriteTrackTitle ?? this.favoriteTrackTitle,
      favoriteTrackArtist: favoriteTrackArtist ?? this.favoriteTrackArtist,
    );
  }
}

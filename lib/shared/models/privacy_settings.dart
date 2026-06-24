enum PrivacyLevel {
  public,
  friendsOnly,
  private,
}

extension PrivacyLevelExtension on PrivacyLevel {
  String get displayName {
    switch (this) {
      case PrivacyLevel.public:
        return 'Public';
      case PrivacyLevel.friendsOnly:
        return 'Friends Only';
      case PrivacyLevel.private:
        return 'Private';
    }
  }
}

PrivacyLevel privacyLevelFromString(String value) {
  switch (value) {
    case 'public':
      return PrivacyLevel.public;
    case 'friendsOnly':
      return PrivacyLevel.friendsOnly;
    case 'private':
      return PrivacyLevel.private;
    default:
      return PrivacyLevel.public;
  }
}

class PrivacySettings {
  final String userId;
  final PrivacyLevel displayName;
  final PrivacyLevel avatar;
  final PrivacyLevel bio;
  final PrivacyLevel location;
  final PrivacyLevel interests;
  final PrivacyLevel socialLinks;
  final PrivacyLevel recentMedia;
  final PrivacyLevel roomsCreated;
  final PrivacyLevel tipsReceived;

  PrivacySettings({
    required this.userId,
    this.displayName = PrivacyLevel.public,
    this.avatar = PrivacyLevel.public,
    this.bio = PrivacyLevel.public,
    this.location = PrivacyLevel.friendsOnly,
    this.interests = PrivacyLevel.public,
    this.socialLinks = PrivacyLevel.friendsOnly,
    this.recentMedia = PrivacyLevel.public,
    this.roomsCreated = PrivacyLevel.public,
    this.tipsReceived = PrivacyLevel.friendsOnly,
  });

  factory PrivacySettings.fromMap(String userId, Map<String, dynamic> map) {
    return PrivacySettings(
      userId: userId,
      displayName: privacyLevelFromString(map['displayName'] ?? 'public'),
      avatar: privacyLevelFromString(map['avatar'] ?? 'public'),
      bio: privacyLevelFromString(map['bio'] ?? 'public'),
      location: privacyLevelFromString(map['location'] ?? 'friendsOnly'),
      interests: privacyLevelFromString(map['interests'] ?? 'public'),
      socialLinks: privacyLevelFromString(map['socialLinks'] ?? 'friendsOnly'),
      recentMedia: privacyLevelFromString(map['recentMedia'] ?? 'public'),
      roomsCreated: privacyLevelFromString(map['roomsCreated'] ?? 'public'),
      tipsReceived:
          privacyLevelFromString(map['tipsReceived'] ?? 'friendsOnly'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName.name,
      'avatar': avatar.name,
      'bio': bio.name,
      'location': location.name,
      'interests': interests.name,
      'socialLinks': socialLinks.name,
      'recentMedia': recentMedia.name,
      'roomsCreated': roomsCreated.name,
      'tipsReceived': tipsReceived.name,
    };
  }

  PrivacySettings copyWith({
    PrivacyLevel? displayName,
    PrivacyLevel? avatar,
    PrivacyLevel? bio,
    PrivacyLevel? location,
    PrivacyLevel? interests,
    PrivacyLevel? socialLinks,
    PrivacyLevel? recentMedia,
    PrivacyLevel? roomsCreated,
    PrivacyLevel? tipsReceived,
  }) {
    return PrivacySettings(
      userId: userId,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      interests: interests ?? this.interests,
      socialLinks: socialLinks ?? this.socialLinks,
      recentMedia: recentMedia ?? this.recentMedia,
      roomsCreated: roomsCreated ?? this.roomsCreated,
      tipsReceived: tipsReceived ?? this.tipsReceived,
    );
  }
}

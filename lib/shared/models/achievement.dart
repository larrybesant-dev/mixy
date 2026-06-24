class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int xpReward;
  final int coinReward;
  final AchievementCategory category;
  final int targetValue; // e.g., join 10 rooms, send 50 messages
  final DateTime? unlockedAt;
  final int currentProgress;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.xpReward,
    required this.coinReward,
    required this.category,
    required this.targetValue,
    this.unlockedAt,
    this.currentProgress = 0,
  });

  bool get isUnlocked => unlockedAt != null;
  double get progress => currentProgress / targetValue;

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'] ?? 'ðŸ†',
      xpReward: map['xpReward'] ?? 0,
      coinReward: map['coinReward'] ?? 0,
      category: AchievementCategory.values.firstWhere(
        (e) => e.toString() == 'AchievementCategory.${map['category']}',
        orElse: () => AchievementCategory.social,
      ),
      targetValue: map['targetValue'] ?? 1,
      unlockedAt:
          map['unlockedAt'] != null ? DateTime.parse(map['unlockedAt']) : null,
      currentProgress: map['currentProgress'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'xpReward': xpReward,
      'coinReward': coinReward,
      'category': category.toString().split('.').last,
      'targetValue': targetValue,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'currentProgress': currentProgress,
    };
  }

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    int? xpReward,
    int? coinReward,
    AchievementCategory? category,
    int? targetValue,
    DateTime? unlockedAt,
    int? currentProgress,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      xpReward: xpReward ?? this.xpReward,
      coinReward: coinReward ?? this.coinReward,
      category: category ?? this.category,
      targetValue: targetValue ?? this.targetValue,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      currentProgress: currentProgress ?? this.currentProgress,
    );
  }
}

enum AchievementCategory {
  social, // Friends, matches, conversations
  rooms, // Room participation
  events, // Event attendance/hosting
  engagement, // Likes, gifts, tips
  milestone, // Level ups, streaks
}

// Predefined achievements
class Achievements {
  static final List<Achievement> all = [
    // Social
    Achievement(
      id: 'first_friend',
      title: 'First Friend',
      description: 'Make your first friend',
      icon: 'ðŸ‘‹',
      xpReward: 10,
      coinReward: 5,
      category: AchievementCategory.social,
      targetValue: 1,
    ),
    Achievement(
      id: 'social_butterfly',
      title: 'Social Butterfly',
      description: 'Have 10 friends',
      icon: 'ðŸ¦‹',
      xpReward: 50,
      coinReward: 25,
      category: AchievementCategory.social,
      targetValue: 10,
    ),
    Achievement(
      id: 'popular',
      title: 'Popular',
      description: 'Have 50 friends',
      icon: 'â­',
      xpReward: 200,
      coinReward: 100,
      category: AchievementCategory.social,
      targetValue: 50,
    ),
    Achievement(
      id: 'first_match',
      title: 'Perfect Match',
      description: 'Get your first match in Speed Dating',
      icon: 'ðŸ’•',
      xpReward: 20,
      coinReward: 10,
      category: AchievementCategory.social,
      targetValue: 1,
    ),
    Achievement(
      id: 'match_maker',
      title: 'Match Maker',
      description: 'Get 10 matches',
      icon: 'ðŸ’–',
      xpReward: 100,
      coinReward: 50,
      category: AchievementCategory.social,
      targetValue: 10,
    ),

    // Rooms
    Achievement(
      id: 'room_explorer',
      title: 'Room Explorer',
      description: 'Join 5 different rooms',
      icon: 'ðŸšª',
      xpReward: 25,
      coinReward: 10,
      category: AchievementCategory.rooms,
      targetValue: 5,
    ),
    Achievement(
      id: 'room_veteran',
      title: 'Room Veteran',
      description: 'Join 25 rooms',
      icon: 'ðŸŽ¯',
      xpReward: 100,
      coinReward: 50,
      category: AchievementCategory.rooms,
      targetValue: 25,
    ),
    Achievement(
      id: 'host_debut',
      title: 'Host Debut',
      description: 'Host your first room',
      icon: 'ðŸŽ¤',
      xpReward: 30,
      coinReward: 15,
      category: AchievementCategory.rooms,
      targetValue: 1,
    ),
    Achievement(
      id: 'super_host',
      title: 'Super Host',
      description: 'Host 10 rooms',
      icon: 'ðŸ‘‘',
      xpReward: 150,
      coinReward: 75,
      category: AchievementCategory.rooms,
      targetValue: 10,
    ),

    // Events
    Achievement(
      id: 'event_goer',
      title: 'Event Goer',
      description: 'Attend your first event',
      icon: 'ðŸŽ‰',
      xpReward: 15,
      coinReward: 10,
      category: AchievementCategory.events,
      targetValue: 1,
    ),
    Achievement(
      id: 'party_animal',
      title: 'Party Animal',
      description: 'Attend 10 events',
      icon: 'ðŸŽŠ',
      xpReward: 75,
      coinReward: 40,
      category: AchievementCategory.events,
      targetValue: 10,
    ),
    Achievement(
      id: 'event_host',
      title: 'Event Organizer',
      description: 'Host your first event',
      icon: 'ðŸ“…',
      xpReward: 40,
      coinReward: 20,
      category: AchievementCategory.events,
      targetValue: 1,
    ),

    // Engagement
    Achievement(
      id: 'generous',
      title: 'Generous Soul',
      description: 'Send 10 gifts',
      icon: 'ðŸŽ',
      xpReward: 50,
      coinReward: 0,
      category: AchievementCategory.engagement,
      targetValue: 10,
    ),
    Achievement(
      id: 'big_tipper',
      title: 'Big Tipper',
      description: 'Send 100 coins in tips',
      icon: 'ðŸ’°',
      xpReward: 100,
      coinReward: 50,
      category: AchievementCategory.engagement,
      targetValue: 100,
    ),
    Achievement(
      id: 'appreciated',
      title: 'Appreciated',
      description: 'Receive 50 tips total',
      icon: 'ðŸŒŸ',
      xpReward: 75,
      coinReward: 25,
      category: AchievementCategory.engagement,
      targetValue: 50,
    ),

    // Milestones
    Achievement(
      id: 'week_streak',
      title: 'Week Warrior',
      description: 'Login for 7 consecutive days',
      icon: 'ðŸ”¥',
      xpReward: 50,
      coinReward: 25,
      category: AchievementCategory.milestone,
      targetValue: 7,
    ),
    Achievement(
      id: 'month_streak',
      title: 'Month Master',
      description: 'Login for 30 consecutive days',
      icon: 'ðŸ’¯',
      xpReward: 300,
      coinReward: 150,
      category: AchievementCategory.milestone,
      targetValue: 30,
    ),
    Achievement(
      id: 'level_10',
      title: 'Rising Star',
      description: 'Reach level 10',
      icon: 'â­',
      xpReward: 100,
      coinReward: 50,
      category: AchievementCategory.milestone,
      targetValue: 10,
    ),
    Achievement(
      id: 'level_25',
      title: 'Mix & Mingle Legend',
      description: 'Reach level 25',
      icon: 'ðŸ‘‘',
      xpReward: 500,
      coinReward: 250,
      category: AchievementCategory.milestone,
      targetValue: 25,
    ),
  ];
}

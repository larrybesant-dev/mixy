import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/achievement.dart';
import '../../shared/models/user_level.dart';
import '../../shared/models/user_streak.dart';
import '../../shared/models/activity.dart';
import 'badge_service.dart';

class GamificationService {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============ ACHIEVEMENTS ============

  Future<List<Achievement>> getUserAchievements(String userId) async {
    try {
      final doc =
          await _firestore.collection('user_achievements').doc(userId).get();
      if (!doc.exists) return [];

      final data = doc.data() as Map<String, dynamic>;
      final achievements = (data['achievements'] as List? ?? [])
          .map((a) => Achievement.fromMap(a as Map<String, dynamic>))
          .toList();
      return achievements;
    } catch (e) {
      debugPrint('Error getting user achievements: $e');
      return [];
    }
  }

  Future<void> initializeAchievements(String userId) async {
    final achievements = Achievements.all.map((a) => a.toMap()).toList();
    await _firestore.collection('user_achievements').doc(userId).set({
      'userId': userId,
      'achievements': achievements,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> trackProgress(
      String userId, String achievementId, int progress) async {
    try {
      final docRef = _firestore.collection('user_achievements').doc(userId);
      final doc = await docRef.get();

      if (!doc.exists) {
        await initializeAchievements(userId);
      }

      final data = doc.data() as Map<String, dynamic>;
      final achievements = (data['achievements'] as List)
          .map((a) => Achievement.fromMap(a as Map<String, dynamic>))
          .toList();

      final index = achievements.indexWhere((a) => a.id == achievementId);
      if (index == -1) return;

      final achievement = achievements[index];
      if (achievement.isUnlocked) return;

      final newProgress = achievement.currentProgress + progress;
      final unlocked = newProgress >= achievement.targetValue;

      achievements[index] = achievement.copyWith(
        currentProgress: newProgress,
        unlockedAt: unlocked ? DateTime.now() : null,
      );

      await docRef.update({
        'achievements': achievements.map((a) => a.toMap()).toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (unlocked) {
        // Award XP and coins
        await addXP(userId, achievement.xpReward);
        await addCoins(userId, achievement.coinReward,
            'Achievement: ${achievement.title}');

        // Log activity
        await logActivity(
          userId: userId,
          type: ActivityType.achievementUnlocked,
          description: 'Unlocked achievement: ${achievement.title}',
          metadata: {'achievementId': achievementId},
        );
      }
    } catch (e) {
      debugPrint('Error tracking achievement progress: $e');
    }
  }

  // ============ LEVELS & XP ============

  Future<UserLevel> getUserLevel(String userId) async {
    try {
      final doc = await _firestore.collection('user_levels').doc(userId).get();
      if (!doc.exists) {
        final newLevel = UserLevel(
          userId: userId,
          level: 1,
          xp: 0,
          xpToNextLevel: 100,
          lastUpdated: DateTime.now(),
        );
        await _firestore
            .collection('user_levels')
            .doc(userId)
            .set(newLevel.toMap());
        return newLevel;
      }
      return UserLevel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error getting user level: $e');
      return UserLevel(
        userId: userId,
        level: 1,
        xp: 0,
        xpToNextLevel: 100,
        lastUpdated: DateTime.now(),
      );
    }
  }

  Future<void> addXP(String userId, int xp) async {
    try {
      final docRef = _firestore.collection('user_levels').doc(userId);
      final doc = await docRef.get();

      UserLevel currentLevel;
      if (!doc.exists) {
        currentLevel = UserLevel(
          userId: userId,
          level: 1,
          xp: 0,
          xpToNextLevel: 100,
          lastUpdated: DateTime.now(),
        );
      } else {
        currentLevel = UserLevel.fromMap(doc.data() as Map<String, dynamic>);
      }

      int newXP = currentLevel.xp + xp;
      int newLevel = currentLevel.level;
      int xpToNext = currentLevel.xpToNextLevel;

      // Check for level up
      while (newXP >= xpToNext) {
        newXP -= xpToNext;
        newLevel++;
        xpToNext = UserLevel.calculateXPForLevel(newLevel);

        // Log level up activity
        await logActivity(
          userId: userId,
          type: ActivityType.leveledUp,
          description: 'Reached level $newLevel!',
          metadata: {'level': newLevel},
        );

        // Award level up bonus (10 coins per level)
        await addCoins(userId, 10 * newLevel, 'Level $newLevel reward');
      }

      final updatedLevel = currentLevel.copyWith(
        level: newLevel,
        xp: newXP,
        xpToNextLevel: xpToNext,
        lastUpdated: DateTime.now(),
      );

      await docRef.set(updatedLevel.toMap());
    } catch (e) {
      debugPrint('Error adding XP: $e');
    }
  }

  // ============ STREAKS ============

  Future<UserStreak> getUserStreak(String userId) async {
    try {
      final doc = await _firestore.collection('user_streaks').doc(userId).get();
      if (!doc.exists) {
        final newStreak = UserStreak(
          userId: userId,
          currentStreak: 0,
          longestStreak: 0,
          lastActiveDate: DateTime.now(),
          totalDaysActive: 0,
          rewardsEarned: {},
        );
        await _firestore
            .collection('user_streaks')
            .doc(userId)
            .set(newStreak.toMap());
        return newStreak;
      }
      return UserStreak.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error getting user streak: $e');
      return UserStreak(
        userId: userId,
        currentStreak: 0,
        longestStreak: 0,
        lastActiveDate: DateTime.now(),
        totalDaysActive: 0,
        rewardsEarned: {},
      );
    }
  }

  Future<void> checkAndUpdateStreak(String userId) async {
    try {
      final streak = await getUserStreak(userId);

      if (!streak.canClaimToday) return;

      final now = DateTime.now();
      final lastActive = streak.lastActiveDate;
      final daysDiff = now
          .difference(
              DateTime(lastActive.year, lastActive.month, lastActive.day))
          .inDays;

      int newStreak;
      if (daysDiff == 1) {
        // Continue streak
        newStreak = streak.currentStreak + 1;
      } else if (daysDiff > 1) {
        // Streak broken
        newStreak = 1;
      } else {
        return; // Same day
      }

      final reward = UserStreak(
        userId: userId,
        currentStreak: newStreak,
        longestStreak: newStreak,
        lastActiveDate: now,
        totalDaysActive: 0,
        rewardsEarned: {},
      ).dailyReward;

      final newRewards = Map<String, int>.from(streak.rewardsEarned);
      newRewards[now.toIso8601String().split('T')[0]] = reward;

      final updatedStreak = streak.copyWith(
        currentStreak: newStreak,
        longestStreak:
            newStreak > streak.longestStreak ? newStreak : streak.longestStreak,
        lastActiveDate: now,
        totalDaysActive: streak.totalDaysActive + 1,
        rewardsEarned: newRewards,
      );

      await _firestore
          .collection('user_streaks')
          .doc(userId)
          .set(updatedStreak.toMap());

      // Award streak reward
      await addCoins(userId, reward, 'Daily streak bonus (Day $newStreak)');

      // Check streak milestones for achievements
      if (newStreak == 7) {
        await trackProgress(userId, 'week_streak', 1);
      } else if (newStreak == 30) {
        await trackProgress(userId, 'month_streak', 1);
      }

      // Log activity for significant streaks
      if (newStreak % 7 == 0) {
        await logActivity(
          userId: userId,
          type: ActivityType.streakMilestone,
          description: '$newStreak day streak! ðŸ”¥',
          metadata: {'streak': newStreak},
        );
      }
    } catch (e) {
      debugPrint('Error updating streak: $e');
    }
  }

  // ============ ACTIVITIES ============

  Future<void> logActivity({
    required String userId,
    required ActivityType type,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      final activity = Activity(
        id: _firestore.collection('activities').doc().id,
        userId: userId,
        userName: userData?['displayName'] ?? 'User',
        userPhotoUrl: userData?['photoUrl'],
        type: type,
        description: description,
        timestamp: DateTime.now(),
        metadata: metadata,
      );

      await _firestore.collection('activities').add(activity.toMap());
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  Future<List<Activity>> getActivityFeed(String userId,
      {int limit = 20}) async {
    try {
      // Get user's friends
      final friendsDoc =
          await _firestore.collection('friends').doc(userId).get();
      final friendIds = friendsDoc.exists
          ? List<String>.from(friendsDoc.data()?['friendIds'] ?? [])
          : [];

      // Include user's own ID
      friendIds.add(userId);

      final snapshot = await _firestore
          .collection('activities')
          .where('userId',
              whereIn:
                  friendIds.isEmpty ? ['none'] : friendIds.take(10).toList())
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => Activity.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting activity feed: $e');
      return [];
    }
  }

  // ============ HELPER ============

  Future<void> addCoins(String userId, int amount, String reason) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'coinBalance': FieldValue.increment(amount),
      });

      await _firestore.collection('coin_transactions').add({
        'userId': userId,
        'amount': amount,
        'type': 'reward',
        'description': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding coins: $e');
    }
  }

  // ============ PROVIDER-EXPECTED METHODS ============

  /// Get available achievements catalog
  Future<List<Achievement>> getAvailableAchievements() async {
    try {
      return Achievements.all;
    } catch (e) {
      debugPrint('Error getting available achievements: $e');
      return [];
    }
  }

  /// Award XP to user
  Future<void> awardXP(String userId, int amount, String reason) async {
    await addXP(userId, amount);
  }

  /// Check and update daily streak
  Future<void> checkDailyStreak(String userId) async {
    try {
      final streakDoc =
          await _firestore.collection('user_streaks').doc(userId).get();

      if (!streakDoc.exists) {
        // Initialize streak
        await _firestore.collection('user_streaks').doc(userId).set({
          'userId': userId,
          'currentStreak': 1,
          'longestStreak': 1,
          'lastLoginDate': FieldValue.serverTimestamp(),
        });
        return;
      }

      final data = streakDoc.data()!;
      final lastLogin = (data['lastLoginDate'] as Timestamp?)?.toDate();
      final now = DateTime.now();

      if (lastLogin != null) {
        final daysDiff = now.difference(lastLogin).inDays;

        if (daysDiff == 1) {
          // Consecutive day - increment streak
          final newStreak = (data['currentStreak'] as int? ?? 0) + 1;
          final longestStreak = data['longestStreak'] as int? ?? 0;

          await _firestore.collection('user_streaks').doc(userId).update({
            'currentStreak': newStreak,
            'longestStreak':
                newStreak > longestStreak ? newStreak : longestStreak,
            'lastLoginDate': FieldValue.serverTimestamp(),
          });
        } else if (daysDiff > 1) {
          // Streak broken - reset to 1
          await _firestore.collection('user_streaks').doc(userId).update({
            'currentStreak': 1,
            'lastLoginDate': FieldValue.serverTimestamp(),
          });
        }
        // Same day - no update needed
      }
    } catch (e) {
      debugPrint('Error checking daily streak: $e');
    }
  }

  /// Unlock achievement
  Future<void> unlockAchievement(String userId, String achievementId) async {
    await trackProgress(userId, achievementId, 999999); // Force unlock
  }

  /// Get leaderboard
  Future<List<Map<String, dynamic>>> getLeaderboard(
      String type, int limit) async {
    try {
      String orderField;
      switch (type) {
        case 'xp':
          orderField = 'xp';
          break;
        case 'level':
          orderField = 'level';
          break;
        case 'coins':
          orderField = 'coinBalance';
          break;
        default:
          orderField = 'xp';
      }

      final query = _firestore
          .collection('user_levels')
          .orderBy(orderField, descending: true)
          .limit(limit);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error getting leaderboard: $e');
      return [];
    }
  }

  // ============ STREAM METHODS (FOR REAL-TIME UPDATES) ============

  /// Stream user level updates in real-time from Firestore
  Stream<UserLevel> streamUserLevel(String userId) {
    return _firestore
        .collection('user_levels')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        // Return default if doesn't exist
        return UserLevel(
          userId: userId,
          level: 1,
          xp: 0,
          xpToNextLevel: 100,
          lastUpdated: DateTime.now(),
        );
      }
      return UserLevel.fromMap(doc.data() as Map<String, dynamic>);
    }).handleError((e) {
      debugPrint('Error streaming user level: $e');
      return UserLevel(
        userId: userId,
        level: 1,
        xp: 0,
        xpToNextLevel: 100,
        lastUpdated: DateTime.now(),
      );
    });
  }

  /// Stream user streak updates in real-time from Firestore
  Stream<UserStreak> streamUserStreak(String userId) {
    return _firestore
        .collection('user_streaks')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        // Return default if doesn't exist
        return UserStreak(
          userId: userId,
          currentStreak: 0,
          longestStreak: 0,
          lastActiveDate: DateTime.now(),
          totalDaysActive: 0,
          rewardsEarned: {},
        );
      }
      return UserStreak.fromMap(doc.data() as Map<String, dynamic>);
    }).handleError((e) {
      debugPrint('Error streaming user streak: $e');
      return UserStreak(
        userId: userId,
        currentStreak: 0,
        longestStreak: 0,
        lastActiveDate: DateTime.now(),
        totalDaysActive: 0,
        rewardsEarned: {},
      );
    });
  }

  /// Stream user badges updates in real-time from Firestore
  Stream<List<UserBadge>> streamUserBadges(String userId) {
    return _firestore
        .collection('user_badges')
        .doc(userId)
        .snapshots()
        .map<List<UserBadge>>((doc) {
      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>;
      final badges = (data['badges'] as List? ?? [])
          .map((b) => UserBadge.fromMap(b as Map<String, dynamic>))
          .toList();
      return badges;
    }).handleError((e, stackTrace) {
      debugPrint('Error streaming user badges: $e');
      return <UserBadge>[];
    });
  }
}

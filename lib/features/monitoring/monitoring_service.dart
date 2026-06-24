/// Monitoring Service
///
/// Tracks key app health metrics including crash-free sessions,
/// room join success rates, video reliability, retention, and VIP conversion.
library;

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/analytics/analytics_service.dart';

/// Service for monitoring app health and key metrics
class MonitoringService {
  static MonitoringService? _instance;
  static MonitoringService get instance => _instance ??= MonitoringService._();

  MonitoringService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // ignore: unused_field
  final AnalyticsService _analytics = AnalyticsService.instance;

  // Collections
  static const String _metricsCollection = 'monitoring_metrics';
  static const String _snapshotsCollection = 'monitoring_snapshots';

  // ============================================================
  // CRASH-FREE SESSIONS
  // ============================================================

  /// Track crash-free session rate
  Future<CrashMetrics> trackCrashFreeSessions({
    DateTime? date,
    int lookbackDays = 7,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final startDate = targetDate.subtract(Duration(days: lookbackDays));

      // Get session data
      final sessionsQuery = await _firestore
          .collection('analytics_events')
          .where('event', isEqualTo: 'session_start')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .count()
          .get();

      // Get crash data
      final crashesQuery = await _firestore
          .collection('crashes')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .count()
          .get();

      final totalSessions = sessionsQuery.count ?? 0;
      final totalCrashes = crashesQuery.count ?? 0;
      final crashFreeSessions = totalSessions - totalCrashes;

      final crashFreeRate =
          totalSessions > 0 ? (crashFreeSessions / totalSessions * 100) : 100.0;

      final metrics = CrashMetrics(
        date: targetDate,
        totalSessions: totalSessions,
        crashFreeSessions: crashFreeSessions,
        crashCount: totalCrashes,
        crashFreeRate: crashFreeRate,
        status: _getCrashFreeStatus(crashFreeRate),
      );

      await _recordMetric('crash_free_sessions', metrics.toMap());

      debugPrint(
          'ðŸ“Š [Monitor] Crash-free rate: ${crashFreeRate.toStringAsFixed(2)}%');

      return metrics;
    } catch (e) {
      debugPrint('âŒ [Monitor] Failed to track crash metrics: $e');
      return CrashMetrics(
        date: date ?? DateTime.now(),
        totalSessions: 0,
        crashFreeSessions: 0,
        crashCount: 0,
        crashFreeRate: 0,
        status: HealthStatus.unknown,
      );
    }
  }

  // ============================================================
  // ROOM JOIN SUCCESS RATE
  // ============================================================

  /// Track room join success rate
  Future<RoomJoinMetrics> trackRoomJoinSuccessRate({
    DateTime? date,
    int lookbackDays = 7,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final startDate = targetDate.subtract(Duration(days: lookbackDays));

      // Get join attempts
      final attemptsQuery = await _firestore
          .collection('room_events')
          .where('event', isEqualTo: 'join_attempt')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      // Get successful joins
      final successQuery = await _firestore
          .collection('room_events')
          .where('event', isEqualTo: 'join_success')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      // Get failures by reason
      final failuresQuery = await _firestore
          .collection('room_events')
          .where('event', isEqualTo: 'join_failed')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      final totalAttempts = attemptsQuery.docs.length;
      final successfulJoins = successQuery.docs.length;

      // Categorize failures
      final failuresByReason = <String, int>{};
      for (final doc in failuresQuery.docs) {
        final reason = doc.data()['reason'] ?? 'unknown';
        failuresByReason[reason] = (failuresByReason[reason] ?? 0) + 1;
      }

      final successRate =
          totalAttempts > 0 ? (successfulJoins / totalAttempts * 100) : 100.0;

      // Calculate average join time
      double avgJoinTime = 0;
      if (successQuery.docs.isNotEmpty) {
        final times = successQuery.docs
            .map((d) => (d.data()['joinTimeMs'] ?? 0) as int)
            .where((t) => t > 0)
            .toList();
        if (times.isNotEmpty) {
          avgJoinTime = times.reduce((a, b) => a + b) / times.length;
        }
      }

      final metrics = RoomJoinMetrics(
        date: targetDate,
        totalAttempts: totalAttempts,
        successfulJoins: successfulJoins,
        failedJoins: failuresQuery.docs.length,
        successRate: successRate,
        averageJoinTimeMs: avgJoinTime,
        failuresByReason: failuresByReason,
        status: _getRoomJoinStatus(successRate),
      );

      await _recordMetric('room_join_success', metrics.toMap());

      debugPrint(
          'ðŸ“Š [Monitor] Room join success: ${successRate.toStringAsFixed(2)}%');

      return metrics;
    } catch (e) {
      debugPrint('âŒ [Monitor] Failed to track room join metrics: $e');
      return RoomJoinMetrics(
        date: date ?? DateTime.now(),
        totalAttempts: 0,
        successfulJoins: 0,
        failedJoins: 0,
        successRate: 0,
        averageJoinTimeMs: 0,
        failuresByReason: {},
        status: HealthStatus.unknown,
      );
    }
  }

  // ============================================================
  // VIDEO RELIABILITY
  // ============================================================

  /// Track video reliability metrics
  Future<VideoMetrics> trackVideoReliability({
    DateTime? date,
    int lookbackDays = 7,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final startDate = targetDate.subtract(Duration(days: lookbackDays));

      // Get video sessions
      final sessionsQuery = await _firestore
          .collection('video_events')
          .where('event', isEqualTo: 'video_started')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      // Get video quality events
      final qualityQuery = await _firestore
          .collection('video_events')
          .where('event', isEqualTo: 'quality_report')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      // Get reconnection events
      final reconnectsQuery = await _firestore
          .collection('video_events')
          .where('event', isEqualTo: 'reconnected')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .count()
          .get();

      // Get freeze events
      final freezesQuery = await _firestore
          .collection('video_events')
          .where('event', isEqualTo: 'video_freeze')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .count()
          .get();

      final totalSessions = sessionsQuery.docs.length;
      final reconnects = reconnectsQuery.count ?? 0;
      final freezes = freezesQuery.count ?? 0;

      // Calculate average quality
      double avgQuality = 0;
      double avgBitrate = 0;
      double avgFps = 0;

      if (qualityQuery.docs.isNotEmpty) {
        final qualities =
            qualityQuery.docs.map((d) => (d.data()['quality'] ?? 0) as int);
        final bitrates =
            qualityQuery.docs.map((d) => (d.data()['bitrate'] ?? 0) as int);
        final fpsList =
            qualityQuery.docs.map((d) => (d.data()['fps'] ?? 0) as int);

        avgQuality =
            (qualities.reduce((a, b) => a + b) / qualityQuery.docs.length)
                .toDouble();
        avgBitrate =
            (bitrates.reduce((a, b) => a + b) / qualityQuery.docs.length)
                .toDouble();
        avgFps = (fpsList.reduce((a, b) => a + b) / qualityQuery.docs.length)
            .toDouble();
      }

      // Calculate reliability score
      final reconnectRate =
          totalSessions > 0 ? (reconnects / totalSessions) : 0.0;
      final freezeRate = totalSessions > 0 ? (freezes / totalSessions) : 0.0;
      final reliabilityScore =
          (100 - (reconnectRate * 10 + freezeRate * 15).clamp(0, 100))
              .toDouble();

      final metrics = VideoMetrics(
        date: targetDate,
        totalSessions: totalSessions,
        reconnects: reconnects,
        freezes: freezes,
        averageQuality: avgQuality,
        averageBitrate: avgBitrate,
        averageFps: avgFps,
        reliabilityScore: reliabilityScore,
        status: _getVideoStatus(reliabilityScore),
      );

      await _recordMetric('video_reliability', metrics.toMap());

      debugPrint(
          'ðŸ“Š [Monitor] Video reliability: ${reliabilityScore.toStringAsFixed(2)}%');

      return metrics;
    } catch (e) {
      debugPrint('âŒ [Monitor] Failed to track video metrics: $e');
      return VideoMetrics(
        date: date ?? DateTime.now(),
        totalSessions: 0,
        reconnects: 0,
        freezes: 0,
        averageQuality: 0,
        averageBitrate: 0,
        averageFps: 0,
        reliabilityScore: 0,
        status: HealthStatus.unknown,
      );
    }
  }

  // ============================================================
  // RETENTION METRICS
  // ============================================================

  /// Track retention metrics
  Future<RetentionMetrics> trackRetentionMetrics({
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();

      // D1 retention (users who returned day after signup)
      final d1Retention = await _calculateDayRetention(targetDate, 1);

      // D7 retention (users who returned 7 days after signup)
      final d7Retention = await _calculateDayRetention(targetDate, 7);

      // D30 retention (users who returned 30 days after signup)
      final d30Retention = await _calculateDayRetention(targetDate, 30);

      // Weekly active users
      final wauQuery = await _firestore
          .collection('users')
          .where('lastActiveAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                  targetDate.subtract(const Duration(days: 7))))
          .count()
          .get();

      // Monthly active users
      final mauQuery = await _firestore
          .collection('users')
          .where('lastActiveAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                  targetDate.subtract(const Duration(days: 30))))
          .count()
          .get();

      // Daily active users
      final dauQuery = await _firestore
          .collection('users')
          .where('lastActiveAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                  targetDate.subtract(const Duration(days: 1))))
          .count()
          .get();

      final dau = dauQuery.count ?? 0;
      final wau = wauQuery.count ?? 0;
      final mau = mauQuery.count ?? 0;

      // Calculate stickiness (DAU/MAU)
      final stickiness = mau > 0 ? (dau / mau * 100) : 0.0;

      final metrics = RetentionMetrics(
        date: targetDate,
        d1Retention: d1Retention,
        d7Retention: d7Retention,
        d30Retention: d30Retention,
        dau: dau,
        wau: wau,
        mau: mau,
        stickiness: stickiness,
        status: _getRetentionStatus(d7Retention),
      );

      await _recordMetric('retention', metrics.toMap());

      debugPrint(
          'ðŸ“Š [Monitor] D7 retention: ${d7Retention.toStringAsFixed(2)}%');

      return metrics;
    } catch (e) {
      debugPrint('âŒ [Monitor] Failed to track retention metrics: $e');
      return RetentionMetrics(
        date: date ?? DateTime.now(),
        d1Retention: 0,
        d7Retention: 0,
        d30Retention: 0,
        dau: 0,
        wau: 0,
        mau: 0,
        stickiness: 0,
        status: HealthStatus.unknown,
      );
    }
  }

  Future<double> _calculateDayRetention(DateTime date, int days) async {
    try {
      final cohortDate = date.subtract(Duration(days: days));
      final cohortStart =
          DateTime(cohortDate.year, cohortDate.month, cohortDate.day);
      final cohortEnd = cohortStart.add(const Duration(days: 1));

      // Users who signed up on cohort day
      final signupsQuery = await _firestore
          .collection('users')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(cohortStart))
          .where('createdAt', isLessThan: Timestamp.fromDate(cohortEnd))
          .get();

      if (signupsQuery.docs.isEmpty) return 0;

      // Check how many returned on target day
      final targetStart = DateTime(date.year, date.month, date.day);
      final targetEnd = targetStart.add(const Duration(days: 1));

      int returned = 0;
      for (final doc in signupsQuery.docs) {
        final lastActive = (doc.data()['lastActiveAt'] as Timestamp?)?.toDate();
        if (lastActive != null &&
            lastActive.isAfter(targetStart) &&
            lastActive.isBefore(targetEnd)) {
          returned++;
        }
      }

      return (returned / signupsQuery.docs.length * 100);
    } catch (e) {
      return 0;
    }
  }

  // ============================================================
  // VIP CONVERSION
  // ============================================================

  /// Track VIP conversion metrics
  Future<ConversionMetrics> trackVipConversion({
    DateTime? date,
    int lookbackDays = 30,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final startDate = targetDate.subtract(Duration(days: lookbackDays));

      // Total users
      final totalUsersQuery = await _firestore
          .collection('users')
          .where('createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(targetDate))
          .count()
          .get();

      // VIP users
      final vipQuery = await _firestore
          .collection('users')
          .where('membershipTier', isEqualTo: 'vip')
          .count()
          .get();

      // VIP+ users
      final vipPlusQuery = await _firestore
          .collection('users')
          .where('membershipTier', isEqualTo: 'vip_plus')
          .count()
          .get();

      // New conversions this period
      final newVipQuery = await _firestore
          .collection('membership_events')
          .where('event', isEqualTo: 'upgraded_to_vip')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .count()
          .get();

      final newVipPlusQuery = await _firestore
          .collection('membership_events')
          .where('event', isEqualTo: 'upgraded_to_vip_plus')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .count()
          .get();

      // Churned VIP
      final churnedQuery = await _firestore
          .collection('membership_events')
          .where('event', isEqualTo: 'vip_cancelled')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .count()
          .get();

      final totalUsers = totalUsersQuery.count ?? 0;
      final vipUsers = vipQuery.count ?? 0;
      final vipPlusUsers = vipPlusQuery.count ?? 0;
      final newVip = newVipQuery.count ?? 0;
      final newVipPlus = newVipPlusQuery.count ?? 0;
      final churned = churnedQuery.count ?? 0;

      final totalPaidUsers = vipUsers + vipPlusUsers;
      final conversionRate =
          totalUsers > 0 ? (totalPaidUsers / totalUsers * 100) : 0.0;

      final metrics = ConversionMetrics(
        date: targetDate,
        totalUsers: totalUsers,
        vipUsers: vipUsers,
        vipPlusUsers: vipPlusUsers,
        conversionRate: conversionRate,
        newConversions: newVip + newVipPlus,
        churned: churned,
        netGrowth: newVip + newVipPlus - churned,
        status: _getConversionStatus(conversionRate),
      );

      await _recordMetric('vip_conversion', metrics.toMap());

      debugPrint(
          'ðŸ“Š [Monitor] VIP conversion: ${conversionRate.toStringAsFixed(2)}%');

      return metrics;
    } catch (e) {
      debugPrint('âŒ [Monitor] Failed to track conversion metrics: $e');
      return ConversionMetrics(
        date: date ?? DateTime.now(),
        totalUsers: 0,
        vipUsers: 0,
        vipPlusUsers: 0,
        conversionRate: 0,
        newConversions: 0,
        churned: 0,
        netGrowth: 0,
        status: HealthStatus.unknown,
      );
    }
  }

  // ============================================================
  // AGGREGATE DASHBOARD
  // ============================================================

  /// Get all metrics for dashboard
  Future<DashboardSnapshot> getDashboardSnapshot() async {
    final crash = await trackCrashFreeSessions();
    final roomJoin = await trackRoomJoinSuccessRate();
    final video = await trackVideoReliability();
    final retention = await trackRetentionMetrics();
    final conversion = await trackVipConversion();

    final overallHealth = _calculateOverallHealth([
      crash.status,
      roomJoin.status,
      video.status,
      retention.status,
      conversion.status,
    ]);

    final snapshot = DashboardSnapshot(
      timestamp: DateTime.now(),
      crashMetrics: crash,
      roomJoinMetrics: roomJoin,
      videoMetrics: video,
      retentionMetrics: retention,
      conversionMetrics: conversion,
      overallHealth: overallHealth,
    );

    // Save snapshot
    await _firestore.collection(_snapshotsCollection).add({
      'timestamp': FieldValue.serverTimestamp(),
      'overallHealth': overallHealth.name,
      'data': snapshot.toMap(),
    });

    return snapshot;
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  Future<void> _recordMetric(
      String metricType, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(_metricsCollection).add({
        'type': metricType,
        'timestamp': FieldValue.serverTimestamp(),
        ...data,
      });
    } catch (e) {
      debugPrint('âš ï¸ [Monitor] Failed to record metric: $e');
    }
  }

  HealthStatus _getCrashFreeStatus(double rate) {
    if (rate >= 99.5) return HealthStatus.healthy;
    if (rate >= 99) return HealthStatus.warning;
    if (rate >= 95) return HealthStatus.degraded;
    return HealthStatus.critical;
  }

  HealthStatus _getRoomJoinStatus(double rate) {
    if (rate >= 98) return HealthStatus.healthy;
    if (rate >= 95) return HealthStatus.warning;
    if (rate >= 90) return HealthStatus.degraded;
    return HealthStatus.critical;
  }

  HealthStatus _getVideoStatus(double score) {
    if (score >= 95) return HealthStatus.healthy;
    if (score >= 85) return HealthStatus.warning;
    if (score >= 70) return HealthStatus.degraded;
    return HealthStatus.critical;
  }

  HealthStatus _getRetentionStatus(double d7Retention) {
    if (d7Retention >= 40) return HealthStatus.healthy;
    if (d7Retention >= 30) return HealthStatus.warning;
    if (d7Retention >= 20) return HealthStatus.degraded;
    return HealthStatus.critical;
  }

  HealthStatus _getConversionStatus(double rate) {
    if (rate >= 5) return HealthStatus.healthy;
    if (rate >= 3) return HealthStatus.warning;
    if (rate >= 1) return HealthStatus.degraded;
    return HealthStatus.critical;
  }

  HealthStatus _calculateOverallHealth(List<HealthStatus> statuses) {
    if (statuses.any((s) => s == HealthStatus.critical)) {
      return HealthStatus.critical;
    }
    if (statuses.any((s) => s == HealthStatus.degraded)) {
      return HealthStatus.degraded;
    }
    if (statuses.any((s) => s == HealthStatus.warning)) {
      return HealthStatus.warning;
    }
    if (statuses.any((s) => s == HealthStatus.unknown)) {
      return HealthStatus.unknown;
    }
    return HealthStatus.healthy;
  }
}

// ============================================================
// ENUMS
// ============================================================

enum HealthStatus {
  healthy,
  warning,
  degraded,
  critical,
  unknown,
}

// ============================================================
// DATA CLASSES
// ============================================================

class CrashMetrics {
  final DateTime date;
  final int totalSessions;
  final int crashFreeSessions;
  final int crashCount;
  final double crashFreeRate;
  final HealthStatus status;

  const CrashMetrics({
    required this.date,
    required this.totalSessions,
    required this.crashFreeSessions,
    required this.crashCount,
    required this.crashFreeRate,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'totalSessions': totalSessions,
        'crashFreeSessions': crashFreeSessions,
        'crashCount': crashCount,
        'crashFreeRate': crashFreeRate,
        'status': status.name,
      };
}

class RoomJoinMetrics {
  final DateTime date;
  final int totalAttempts;
  final int successfulJoins;
  final int failedJoins;
  final double successRate;
  final double averageJoinTimeMs;
  final Map<String, int> failuresByReason;
  final HealthStatus status;

  const RoomJoinMetrics({
    required this.date,
    required this.totalAttempts,
    required this.successfulJoins,
    required this.failedJoins,
    required this.successRate,
    required this.averageJoinTimeMs,
    required this.failuresByReason,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'totalAttempts': totalAttempts,
        'successfulJoins': successfulJoins,
        'failedJoins': failedJoins,
        'successRate': successRate,
        'averageJoinTimeMs': averageJoinTimeMs,
        'failuresByReason': failuresByReason,
        'status': status.name,
      };
}

class VideoMetrics {
  final DateTime date;
  final int totalSessions;
  final int reconnects;
  final int freezes;
  final double averageQuality;
  final double averageBitrate;
  final double averageFps;
  final double reliabilityScore;
  final HealthStatus status;

  const VideoMetrics({
    required this.date,
    required this.totalSessions,
    required this.reconnects,
    required this.freezes,
    required this.averageQuality,
    required this.averageBitrate,
    required this.averageFps,
    required this.reliabilityScore,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'totalSessions': totalSessions,
        'reconnects': reconnects,
        'freezes': freezes,
        'averageQuality': averageQuality,
        'averageBitrate': averageBitrate,
        'averageFps': averageFps,
        'reliabilityScore': reliabilityScore,
        'status': status.name,
      };
}

class RetentionMetrics {
  final DateTime date;
  final double d1Retention;
  final double d7Retention;
  final double d30Retention;
  final int dau;
  final int wau;
  final int mau;
  final double stickiness;
  final HealthStatus status;

  const RetentionMetrics({
    required this.date,
    required this.d1Retention,
    required this.d7Retention,
    required this.d30Retention,
    required this.dau,
    required this.wau,
    required this.mau,
    required this.stickiness,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'd1Retention': d1Retention,
        'd7Retention': d7Retention,
        'd30Retention': d30Retention,
        'dau': dau,
        'wau': wau,
        'mau': mau,
        'stickiness': stickiness,
        'status': status.name,
      };
}

class ConversionMetrics {
  final DateTime date;
  final int totalUsers;
  final int vipUsers;
  final int vipPlusUsers;
  final double conversionRate;
  final int newConversions;
  final int churned;
  final int netGrowth;
  final HealthStatus status;

  const ConversionMetrics({
    required this.date,
    required this.totalUsers,
    required this.vipUsers,
    required this.vipPlusUsers,
    required this.conversionRate,
    required this.newConversions,
    required this.churned,
    required this.netGrowth,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'totalUsers': totalUsers,
        'vipUsers': vipUsers,
        'vipPlusUsers': vipPlusUsers,
        'conversionRate': conversionRate,
        'newConversions': newConversions,
        'churned': churned,
        'netGrowth': netGrowth,
        'status': status.name,
      };
}

class DashboardSnapshot {
  final DateTime timestamp;
  final CrashMetrics crashMetrics;
  final RoomJoinMetrics roomJoinMetrics;
  final VideoMetrics videoMetrics;
  final RetentionMetrics retentionMetrics;
  final ConversionMetrics conversionMetrics;
  final HealthStatus overallHealth;

  const DashboardSnapshot({
    required this.timestamp,
    required this.crashMetrics,
    required this.roomJoinMetrics,
    required this.videoMetrics,
    required this.retentionMetrics,
    required this.conversionMetrics,
    required this.overallHealth,
  });

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.toIso8601String(),
        'crashMetrics': crashMetrics.toMap(),
        'roomJoinMetrics': roomJoinMetrics.toMap(),
        'videoMetrics': videoMetrics.toMap(),
        'retentionMetrics': retentionMetrics.toMap(),
        'conversionMetrics': conversionMetrics.toMap(),
        'overallHealth': overallHealth.name,
      };
}

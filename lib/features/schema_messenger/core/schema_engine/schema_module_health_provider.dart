import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../friends/providers/schema_boot_timeline_provider.dart';
import '../../friends/providers/schema_friend_links_providers.dart';
import '../../friends/providers/schema_friend_presence_stability_provider.dart';
import '../../friends/providers/schema_friend_render_mode_provider.dart';
import '../../messages/providers/messages_render_mode_provider.dart';
import 'schema_parity_monitor.dart';

enum MigrationHealthTrend {
  improving,
  stable,
  degrading,
}

/// Unified schema health model for all modules.
/// Replaces module-specific health classes.
class SchemaModuleHealth {
  const SchemaModuleHealth({
    required this.moduleId,
    required this.compositeScore,
    required this.structuralScore,
    required this.parityScore,
    required this.enforcementScore,
    required this.trend,
    required this.comparable,
    required this.parityMatch,
    required this.mismatchCount,
    required this.reasons,
  });

  final String moduleId;
  final int compositeScore;
  final int structuralScore;
  final int parityScore;
  final int enforcementScore;
  final MigrationHealthTrend trend;
  final bool comparable;
  final bool parityMatch;
  final int mismatchCount;
  final List<String> reasons;
}

/// Single source of truth for schema module health across all modules.
/// Input: module identifier (friends, message, etc.)
/// Output: unified health snapshot
///
/// Replaces:
/// - friendModuleHealthProvider
/// - messageModuleHealthProvider
final schemaModuleHealthProvider =
    Provider.autoDispose.family<SchemaModuleHealth, String>((ref, moduleId) {
      final normalizedModuleId = moduleId.trim().toLowerCase();

      switch (normalizedModuleId) {
        case 'friends':
          final parity = ref.watch(schemaParityMonitorProvider('friends'));
          final renderMode = ref.watch(friendPaneRenderModeProvider);
          final linksAsync = ref.watch(schemaFriendLinksProvider);
          final stablePresenceAsync = ref.watch(
            schemaStableFriendPresenceMapProvider,
          );
          final bootMetrics = ref.watch(schemaLatestBootMetricsProvider);

          return _buildFriendsHealth(
            parity: parity,
            renderModeName: renderMode.name,
            linksReady: linksAsync.hasValue,
            presenceReady: stablePresenceAsync.hasValue,
            bootMetrics: bootMetrics,
          );
        case 'message':
          final parity = ref.watch(schemaParityMonitorProvider('message'));
          final renderMode = ref.watch(messagePaneRenderModeProvider);
          final bootMetrics = ref.watch(schemaLatestBootMetricsProvider);

          return _buildmessageHealth(
            parity: parity,
            renderModeName: renderMode.name,
            bootMetrics: bootMetrics,
          );
        default:
          return SchemaModuleHealth(
            moduleId: normalizedModuleId,
            compositeScore: 40,
            structuralScore: 45,
            parityScore: 0,
            enforcementScore: 40,
            trend: MigrationHealthTrend.degrading,
            comparable: false,
            parityMatch: false,
            mismatchCount: 1,
            reasons: <String>['unsupported_module:$normalizedModuleId'],
          );
      }
    });

SchemaModuleHealth _buildFriendsHealth({
  required SchemaParityMonitorReport parity,
  required String renderModeName,
  required bool linksReady,
  required bool presenceReady,
  required SchemaBootMetrics? bootMetrics,
}) {
  final structuralScore = _computeStructuralScore(
    readinessSignals: <bool>[linksReady, presenceReady],
    bootMetrics: bootMetrics,
  );

  final reasons = <String>[
    'mode:$renderModeName',
    if (!linksReady) 'schema_links_loading',
    if (!presenceReady) 'presence_stability_warming',
    ..._buildParityReasons(parity),
  ];

  return _healthFromScores(
    moduleId: 'friends',
    structuralScore: structuralScore,
    parityScore: _computeParityScore(parity),
    enforcementScore: _computeEnforcementScore(renderMode: renderModeName),
    comparable: parity.isComparable,
    parityMatch: parity.isMatch,
    mismatchCount: parity.mismatchCount,
    reasons: reasons,
  );
}

SchemaModuleHealth _buildmessageHealth({
  required SchemaParityMonitorReport parity,
  required String renderModeName,
  required SchemaBootMetrics? bootMetrics,
}) {
  final reasons = <String>[
    'mode:$renderModeName',
    if (!parity.isComparable) 'waiting_for_comparable_state',
    ..._buildParityReasons(parity),
  ];

  return _healthFromScores(
    moduleId: 'message',
    structuralScore: _computeStructuralScore(
      readinessSignals: <bool>[parity.isComparable],
      bootMetrics: bootMetrics,
    ),
    parityScore: _computeParityScore(parity),
    enforcementScore: _computeEnforcementScore(renderMode: renderModeName),
    comparable: parity.isComparable,
    parityMatch: parity.isMatch,
    mismatchCount: parity.mismatchCount,
    reasons: reasons,
  );
}

SchemaModuleHealth _healthFromScores({
  required String moduleId,
  required int structuralScore,
  required int parityScore,
  required int enforcementScore,
  required bool comparable,
  required bool parityMatch,
  required int mismatchCount,
  required List<String> reasons,
}) {
  final compositeScore = _averageScores(<int>[
    structuralScore,
    parityScore,
    enforcementScore,
  ]);

  return SchemaModuleHealth(
    moduleId: moduleId,
    compositeScore: compositeScore,
    structuralScore: structuralScore,
    parityScore: parityScore,
    enforcementScore: enforcementScore,
    trend: _resolveTrend(
      comparable: comparable,
      parityMatch: parityMatch,
      mismatchCount: mismatchCount,
      enforcementScore: enforcementScore,
    ),
    comparable: comparable,
    parityMatch: parityMatch,
    mismatchCount: mismatchCount,
    reasons: reasons
        .map((reason) => reason.trim())
        .where((reason) => reason.isNotEmpty)
        .toSet()
        .toList(growable: false),
  );
}

int _computeStructuralScore({
  required List<bool> readinessSignals,
  SchemaBootMetrics? bootMetrics,
}) {
  if (readinessSignals.isEmpty) {
    return 100;
  }

  final readyCount = readinessSignals.where((signal) => signal).length;
  int score = (60 + ((readyCount / readinessSignals.length) * 40)).round();

  if (bootMetrics != null && bootMetrics.duration > const Duration(seconds: 3)) {
    score -= 5;
  }

  return _clampScore(score);
}

int _computeParityScore(SchemaParityMonitorReport parity) {
  if (!parity.isComparable) {
    return 85;
  }

  return _clampScore(100 - (parity.mismatchCount * 12));
}

int _computeEnforcementScore({required String renderMode}) {
  switch (renderMode) {
    case 'schema':
      return 100;
    case 'dual':
      return 94;
    default:
      return 86;
  }
}

MigrationHealthTrend _resolveTrend({
  required bool comparable,
  required bool parityMatch,
  required int mismatchCount,
  required int enforcementScore,
}) {
  if (!comparable) {
    return MigrationHealthTrend.stable;
  }

  if (!parityMatch || mismatchCount > 0) {
    return mismatchCount >= 3
        ? MigrationHealthTrend.degrading
        : MigrationHealthTrend.stable;
  }

  if (enforcementScore >= 94) {
    return MigrationHealthTrend.improving;
  }

  return MigrationHealthTrend.stable;
}

List<String> _buildParityReasons(SchemaParityMonitorReport parity) {
  return <String>[
    if (!parity.isComparable) 'parity_not_comparable:${parity.signature}',
    ...parity.missingInSchema.map((id) => 'missing_in_schema:$id'),
    ...parity.missingInLegacy.map((id) => 'missing_in_legacy:$id'),
    ...parity.mismatchDetails.map((detail) => 'mismatch:$detail'),
  ];
}

int _averageScores(List<int> scores) {
  if (scores.isEmpty) {
    return 0;
  }

  final total = scores.fold<int>(0, (sum, score) => sum + score);
  return _clampScore((total / scores.length).round());
}

int _clampScore(int value) {
  if (value < 0) {
    return 0;
  }
  if (value > 100) {
    return 100;
  }
  return value;
}

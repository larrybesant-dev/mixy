import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/environment.dart';
import '../../../../core/layout/app_layout.dart';
import '../../../../core/telemetry/app_telemetry.dart';
import '../../../../core/theme.dart';
import '../../core/schema_engine/schema_module_health_provider.dart';
import '../../../../presentation/providers/user_provider.dart';
import '../../../friends/panes/friends_pane_view.dart';
import '../../../friends/providers/friends_providers.dart';
import '../../../messaging/providers/messaging_provider.dart';
import '../parity/friend_parity_validator.dart';
import '../providers/schema_boot_timeline_provider.dart';
import '../providers/schema_friend_links_providers.dart';
import '../providers/schema_friend_presence_stability_provider.dart';
import '../providers/schema_friend_render_mode_provider.dart';
import '../providers/schema_friend_selection_provider.dart';
import 'schema_friends_module_view.dart';

/// Component Name: FriendsSchemaBridgeView
/// Firestore Read Paths: friend_links, users/{uid}, users/{uid}/profile_public/*,
/// rooms/*/participants/*, legacy friends pane paths (in comparison mode)
/// Firestore Write Paths: friend_links/{uid_pair} only through schema controls
/// Allowed Fields: users, status, requestedBy, createdAt, updatedAt, username,
/// email, avatarUrl, profileAccentColor, participants.userId,
/// participants.userStatus, participants.lastActiveAt, participants.camOn,
/// participants.micOn
/// Forbidden Fields: users/{uid}.friends, wallet fields, verification/security
/// fields, participants.role mutation
class FriendsSchemaBridgeView extends ConsumerStatefulWidget {
  const FriendsSchemaBridgeView({super.key});

  @override
  ConsumerState<FriendsSchemaBridgeView> createState() =>
      _FriendsSchemaBridgeViewState();
}

class _FriendsSchemaBridgeViewState
    extends ConsumerState<FriendsSchemaBridgeView> {
  String _lastEmittedMismatchSignature = '';
  String _candidateMismatchSignature = '';
  int _candidateMismatchCount = 0;
  String? _lastBootUserId;
  SchemaConversationBootSource _nextBootSource =
      SchemaConversationBootSource.unknown;
  static const int _stableMismatchThreshold = 2;

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(friendPaneRenderModeProvider);
    final notifier = ref.read(friendPaneRenderModeProvider.notifier);
    final health = ref.watch(schemaModuleHealthProvider('friends'));
    final isDesktop = context.isExpandedLayout;
    final showGovernance = currentEnv == Environment.dev;
    final currentUser = ref.watch(userProvider);
    final authUserId = ref.watch(schemaAuthUserIdProvider).value;
    final bootTarget = ref.watch(schemaConversationFirstBootTargetProvider);
    final onStartChat = currentUser == null
        ? null
        : (String friendUserId, String friendUsername, String? friendAvatarUrl) =>
              _openDirectChat(
                context: context,
                currentUserId: currentUser.id,
                currentUsername: currentUser.username,
                currentAvatarUrl: currentUser.avatarUrl,
                friendUserId: friendUserId,
                friendUsername: friendUsername,
                friendAvatarUrl: friendAvatarUrl,
              );

    _syncBootSession(authUserId);
    if (kDebugMode) {
      _runParityDiagnostics(mode);
    }
    _runConversationFirstBoot(
      bootTarget: bootTarget,
    );

    return Column(
      children: [
        if (showGovernance) ...[
          _ModeHeader(
            mode: mode,
            onModeChanged: notifier.setMode,
            isDesktop: isDesktop,
            health: health,
          ),
          if (kDebugMode) const _BootTimelineStrip(),
          const Divider(height: 1, color: VelvetNoir.outlineVariant),
        ],
        Expanded(
          child: switch (mode) {
            FriendPaneRenderMode.legacy => const FriendsPaneView(showHeader: false),
            FriendPaneRenderMode.schema => SchemaFriendsModuleView(onStartChat: onStartChat),
            FriendPaneRenderMode.dual => isDesktop
                ? _DualDesktopFriendPanes(
                    schemaPane: SchemaFriendsModuleView(onStartChat: onStartChat),
                  )
                : SchemaFriendsModuleView(onStartChat: onStartChat),
          },
        ),
      ],
    );
  }

  void _syncBootSession(String? authUserId) {
    final normalizedUserId = authUserId?.trim();
    if (_lastBootUserId == normalizedUserId) {
      return;
    }

    final previousUserId = _lastBootUserId;
    _lastBootUserId = normalizedUserId;
    _nextBootSource = previousUserId == null
        ? SchemaConversationBootSource.appStart
        : SchemaConversationBootSource.authSwitch;
    ref.read(schemaConversationBootStateProvider.notifier).reset();
  }

  void _runConversationFirstBoot({
    required SchemaConversationBootTarget? bootTarget,
  }) {
    if (bootTarget == null || !mounted) {
      return;
    }
    final bootState = ref.read(schemaConversationBootStateProvider);
    if (bootState.isTerminal || bootState.isInFlight) {
      return;
    }

    final source = _nextBootSource;
    _nextBootSource = SchemaConversationBootSource.unknown;

    ref.read(schemaConversationBootEngineProvider).startConversationBoot(
          target: bootTarget,
          source: source,
          navigate: (conversationId) async {
            if (!mounted) {
              return;
            }
            GoRouter.of(context).go('/chat/$conversationId');
          },
        );
  }

  Future<void> _openDirectChat({
    required BuildContext context,
    required String currentUserId,
    required String currentUsername,
    required String? currentAvatarUrl,
    required String friendUserId,
    required String friendUsername,
    required String? friendAvatarUrl,
  }) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final conversationId = await ref.read(messagingControllerProvider).createDirectConversation(
            userId1: currentUserId,
            user1Name: currentUsername,
            user1AvatarUrl: currentAvatarUrl,
            userId2: friendUserId,
            user2Name: friendUsername,
            user2AvatarUrl: friendAvatarUrl,
          );

      if (!mounted) {
        return;
      }

      unawaited(router.push('/chat/$conversationId'));
    } catch (error) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Could not open chat: $error')),
      );
    }
  }

  void _runParityDiagnostics(FriendPaneRenderMode mode) {
    final authUserId = ref.watch(schemaAuthUserIdProvider).value;
    if (authUserId == null || authUserId.isEmpty) return;

    final legacyRosterAsync = ref.watch(friendRosterProvider);
    final schemaLinksAsync = ref.watch(schemaFriendLinksProvider);
    final schemaPresenceMapAsync = ref.watch(schemaStableFriendPresenceMapProvider);

    final legacyRoster = legacyRosterAsync.valueOrNull;
    final schemaAcceptedLinks = ref.watch(schemaAcceptedFriendLinksProvider);
    final schemaPresenceMap = schemaPresenceMapAsync.valueOrNull;

    final snapshot = FriendParitySnapshot(
      legacyIdsOrdered:
          legacyRoster?.map((entry) => entry.friendId).toList(growable: false) ??
              const <String>[],
      schemaIdsOrdered: schemaAcceptedLinks
          .map((link) => link.otherUserId(authUserId))
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
      legacyOnlineIds: legacyRoster
              ?.where((entry) => entry.isOnline)
              .map((entry) => entry.friendId)
              .toSet() ??
          const <String>{},
      schemaOnlineIds: schemaPresenceMap?.entries
              .where((entry) => entry.value.isOnline)
              .map((entry) => entry.key)
              .toSet() ??
          const <String>{},
      legacyReady: legacyRosterAsync.hasValue,
      schemaReady: schemaLinksAsync.hasValue,
      schemaPresenceReady: schemaPresenceMapAsync.hasValue,
    );

    final result = evaluateFriendParity(snapshot);

    if (!result.isComparable) {
      _candidateMismatchSignature = '';
      _candidateMismatchCount = 0;
      return;
    }

    if (result.isMatch) {
      if (_lastEmittedMismatchSignature.isNotEmpty) {
        AppTelemetry.logParityEvent(
          domain: 'friends',
          action: 'friend_parity_restored',
          message: 'Friend parity restored between legacy and schema panes.',
          userId: authUserId,
          result: mode.name,
        );
        developer.log(
          'friend_parity_restored mode=${mode.name}',
          name: 'FriendsSchemaBridge',
        );
      }
      _lastEmittedMismatchSignature = '';
      _candidateMismatchSignature = '';
      _candidateMismatchCount = 0;
      return;
    }

    final mismatchSignature = result.paritySignature;
    if (_candidateMismatchSignature == mismatchSignature) {
      _candidateMismatchCount += 1;
    } else {
      _candidateMismatchSignature = mismatchSignature;
      _candidateMismatchCount = 1;
    }

    if (_candidateMismatchCount < _stableMismatchThreshold) {
      return;
    }

    if (_lastEmittedMismatchSignature == mismatchSignature) {
      return;
    }

    _lastEmittedMismatchSignature = mismatchSignature;

    AppTelemetry.logParityEvent(
      level: 'warning',
      domain: 'friends',
      action: 'friend_parity_diff',
      message: 'Stable friend parity mismatch detected.',
      userId: authUserId,
      result: mode.name,
      metadata: <String, Object?>{
        'legacyCount': snapshot.legacyIdsOrdered.length,
        'schemaCount': snapshot.schemaIdsOrdered.length,
        'countDelta': snapshot.legacyIdsOrdered.length - snapshot.schemaIdsOrdered.length,
        'missingInSchema': result.missingInSchema.join(','),
        'missingInLegacy': result.missingInLegacy.join(','),
        'statusMismatches': result.statusMismatches.join(','),
        'legacyOrderHash': result.legacyOrderHash,
        'schemaOrderHash': result.schemaOrderHash,
      },
    );

    developer.log(
      'friend_parity_diff mode=${mode.name} '
      'legacyCount=${snapshot.legacyIdsOrdered.length} '
      'schemaCount=${snapshot.schemaIdsOrdered.length} '
      'countDelta=${snapshot.legacyIdsOrdered.length - snapshot.schemaIdsOrdered.length} '
      'missingInSchema=${result.missingInSchema.join(',')} '
      'missingInLegacy=${result.missingInLegacy.join(',')} '
      'statusMismatches=${result.statusMismatches.join(',')} '
      'legacyOrderHash=${result.legacyOrderHash} '
      'schemaOrderHash=${result.schemaOrderHash}',
      name: 'FriendsSchemaBridge',
    );

    assert(() {
      debugPrint(
        '[FriendsSchemaBridge] Stable mismatch '
        'missingInSchema=${result.missingInSchema.join(',')} '
        'missingInLegacy=${result.missingInLegacy.join(',')} '
        'statusMismatches=${result.statusMismatches.join(',')}',
      );
      return true;
    }());
  }
}

class _BootTimelineStrip extends ConsumerWidget {
  const _BootTimelineStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(
      schemaConversationBootStateProvider.select((state) => state.phase),
    );
    final latest = ref.watch(
      schemaBootTimelineProvider.select(
        (events) => events.isEmpty ? null : events.last,
      ),
    );
    final metrics = ref.watch(schemaLatestBootMetricsProvider);

    Color levelColor(SchemaBootTimelineLevel level) {
      switch (level) {
        case SchemaBootTimelineLevel.info:
          return const Color(0xFF34D399);
        case SchemaBootTimelineLevel.warning:
          return const Color(0xFFF59E0B);
        case SchemaBootTimelineLevel.error:
          return const Color(0xFFEF4444);
      }
    }

    final statusColor = latest == null
        ? VelvetNoir.onSurfaceVariant
        : levelColor(latest.level);

    final latestSummary = latest == null
        ? 'No boot timeline events yet.'
        : '[${latest.source.name}] ${latest.phase.name}: ${latest.message}';

    final metricsSummary = metrics == null
      ? null
      : '${metrics.eventCount} events, ${metrics.phaseCount} phases, ${metrics.duration.inMilliseconds}ms';

    return Container(
      width: double.infinity,
      color: VelvetNoir.surfaceHigh.withValues(alpha: 0.8),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        children: [
          Text(
            'Boot ${phase.name}',
            style: const TextStyle(
              color: VelvetNoir.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              latestSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (metricsSummary != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                metricsSummary,
                style: const TextStyle(
                  color: VelvetNoir.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TextButton(
            onPressed: () => ref.read(schemaBootTimelineProvider.notifier).clear(),
            style: TextButton.styleFrom(
              foregroundColor: VelvetNoir.onSurfaceVariant,
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _ModeHeader extends StatelessWidget {
  const _ModeHeader({
    required this.mode,
    required this.onModeChanged,
    required this.isDesktop,
    required this.health,
  });

  final FriendPaneRenderMode mode;
  final ValueChanged<FriendPaneRenderMode> onModeChanged;
  final bool isDesktop;
  final SchemaModuleHealth health;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VelvetNoir.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Friend System Mode',
                  style: TextStyle(
                    color: VelvetNoir.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scoreColor(health.compositeScore).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _scoreColor(health.compositeScore).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Health ${health.compositeScore}%',
                    style: TextStyle(
                      color: _scoreColor(health.compositeScore),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SegmentedButton<FriendPaneRenderMode>(
            segments: [
              const ButtonSegment(
                value: FriendPaneRenderMode.legacy,
                label: Text('Legacy'),
                icon: Icon(Icons.history_toggle_off_rounded),
              ),
              const ButtonSegment(
                value: FriendPaneRenderMode.schema,
                label: Text('Schema'),
                icon: Icon(Icons.shield_rounded),
              ),
              if (isDesktop)
                const ButtonSegment(
                  value: FriendPaneRenderMode.dual,
                  label: Text('Dual'),
                  icon: Icon(Icons.splitscreen_rounded),
                ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) {
              final selectedMode = selection.isEmpty ? mode : selection.first;
              onModeChanged(selectedMode);
            },
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 90) return const Color(0xFF34D399);
    if (score >= 75) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class _DualDesktopFriendPanes extends StatelessWidget {
  const _DualDesktopFriendPanes({required this.schemaPane});

  final Widget schemaPane;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PaneCard(
            title: 'Legacy Pane (Baseline)',
            child: FriendsPaneView(showHeader: false),
          ),
        ),
        const VerticalDivider(width: 1, color: VelvetNoir.outlineVariant),
        Expanded(
          child: _PaneCard(
            title: 'Schema Pane (Contract)',
            child: schemaPane,
          ),
        ),
      ],
    );
  }
}

class _PaneCard extends StatelessWidget {
  const _PaneCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: VelvetNoir.surfaceHigh,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: VelvetNoir.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

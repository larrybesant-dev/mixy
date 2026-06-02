import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/environment.dart';
import '../../../../core/theme.dart';
import '../../../messaging/panes/messages_pane_view.dart';
import '../../consistency/architecture_health_interpretation_provider.dart';
import '../../core/schema_engine/schema_module_health_provider.dart';
import '../providers/messages_render_mode_provider.dart';
import 'schema_messages_module_view.dart';

/// messageschemaBridgeView — UI-only governance bridge.
///
/// CONSOLIDATED: Does NOT monitor parity or validate compliance.
/// Uses unified SchemaModuleHealth for display only.
class MessageSchemaBridgeView extends ConsumerWidget {
  const MessageSchemaBridgeView({
    super.key,
    required this.userId,
    required this.username,
  });

  final String userId;
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(messagePaneRenderModeProvider);
    final health = ref.watch(schemaModuleHealthProvider('message'));
    final interpretation = ref.watch(architectureHealthInterpretationProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;
    final showGovernance = currentEnv == Environment.dev;

    return Column(
      children: [
        if (showGovernance) ...[
          _GovernanceHeader(
            mode: mode,
            health: health,
            isDesktop: isDesktop,
            interpretationLabel: _interpretationLabel(
              interpretation.classification,
            ),
            onModeChanged:
                ref.read(messagePaneRenderModeProvider.notifier).setMode,
          ),
          const Divider(height: 1, color: VelvetNoir.outlineVariant),
        ],
        Expanded(
          child: switch (mode) {
            MessagePaneRenderMode.legacy => MessagesPaneView(
                userId: userId,
                username: username,
                showHeader: false,
              ),
            MessagePaneRenderMode.schema => SchemamessageModuleView(
                userId: userId,
              ),
            MessagePaneRenderMode.dual => isDesktop
                ? _DualmessagePanes(userId: userId, username: username)
                : SchemamessageModuleView(userId: userId),
          },
        ),
      ],
    );
  }

  String _interpretationLabel(DriftClassification classification) {
    return switch (classification) {
      DriftClassification.acceptableNoise => 'Interpretation: ACCEPTABLE',
      DriftClassification.structuralWarning =>
        'Interpretation: STRUCTURAL WARNING',
      DriftClassification.behavioralDrift => 'Interpretation: BEHAVIORAL DRIFT',
    };
  }
}

class _GovernanceHeader extends StatelessWidget {
  const _GovernanceHeader({
    required this.mode,
    required this.health,
    required this.isDesktop,
    required this.interpretationLabel,
    required this.onModeChanged,
  });

  final MessagePaneRenderMode mode;
  final SchemaModuleHealth health;
  final bool isDesktop;
  final String interpretationLabel;
  final ValueChanged<MessagePaneRenderMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VelvetNoir.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HealthStatus(
                score: health.compositeScore,
                isHealthy: health.parityMatch,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  interpretationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VelvetNoir.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SegmentedButton<MessagePaneRenderMode>(
                segments: [
                  const ButtonSegment(
                    value: MessagePaneRenderMode.legacy,
                    label: Text('Legacy'),
                    icon: Icon(Icons.history_toggle_off_rounded),
                  ),
                  const ButtonSegment(
                    value: MessagePaneRenderMode.schema,
                    label: Text('Schema'),
                    icon: Icon(Icons.shield_rounded),
                  ),
                  if (isDesktop)
                    const ButtonSegment(
                      value: MessagePaneRenderMode.dual,
                      label: Text('Dual'),
                      icon: Icon(Icons.splitscreen_rounded),
                    ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) {
                  onModeChanged(selection.isEmpty ? mode : selection.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          _HealthChips(health: health),
        ],
      ),
    );
  }
}

class _HealthStatus extends StatelessWidget {
  const _HealthStatus({required this.score, required this.isHealthy});

  final int score;
  final bool isHealthy;

  @override
  Widget build(BuildContext context) {
    final color = isHealthy ? const Color(0xFF34D399) : const Color(0xFFF87171);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'Health $score%',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HealthChips extends StatelessWidget {
  const _HealthChips({required this.health});

  final SchemaModuleHealth health;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _chip(
          'Composite ${health.compositeScore}%',
          _scoreColor(health.compositeScore),
        ),
        _chip(
          'Structural ${health.structuralScore}%',
          _scoreColor(health.structuralScore),
        ),
        _chip('Parity ${health.parityScore}%', _scoreColor(health.parityScore)),
        _chip(
          'Enforcement ${health.enforcementScore}%',
          _scoreColor(health.enforcementScore),
        ),
        _chip(_trendLabel(health.trend), _trendColor(health.trend)),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.amber;
    return Colors.red;
  }

  String _trendLabel(MigrationHealthTrend trend) => switch (trend) {
        MigrationHealthTrend.improving => 'Improving',
        MigrationHealthTrend.stable => 'Stable',
        MigrationHealthTrend.degrading => 'Degrading',
      };

  Color _trendColor(MigrationHealthTrend trend) => switch (trend) {
        MigrationHealthTrend.improving => Colors.green,
        MigrationHealthTrend.stable => Colors.amber,
        MigrationHealthTrend.degrading => Colors.red,
      };
}

class _DualmessagePanes extends StatelessWidget {
  const _DualmessagePanes({required this.userId, required this.username});

  final String userId;
  final String username;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PaneCard(
            title: 'Legacy',
            child: MessagesPaneView(
              userId: userId,
              username: username,
              showHeader: false,
            ),
          ),
        ),
        const VerticalDivider(width: 1, color: VelvetNoir.outlineVariant),
        Expanded(
          child: _PaneCard(
            title: 'Schema',
            child: SchemamessageModuleView(userId: userId),
          ),
        ),
      ],
    );
  }
}

class _PaneCard extends StatelessWidget {
  const _PaneCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: VelvetNoir.surfaceHigh,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: VelvetNoir.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

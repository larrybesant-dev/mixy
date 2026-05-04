import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme.dart';
import '../../consistency/architecture_health_interpretation_provider.dart';
import '../../consistency/cross_module_equivalence_provider.dart';
import '../../core/schema_engine/schema_compliance_checker.dart';
import '../../core/schema_engine/schema_parity_monitor.dart';
import '../messages_consistency_contract.dart';

/// Component Name: SchemamessageModuleView
/// Firestore Read Paths: conversations, conversations/{conversationId}/message
/// Firestore Write Paths: none (read-only validation view)
/// Allowed Fields: participantIds/participants, lastMessageAt, lastMessagePreview,
/// unread indicators derived from conversation state
/// Forbidden Fields: wallet/security/verification writes, role mutation, legacy
/// friends arrays
class SchemamessageModuleView extends ConsumerWidget {
  const SchemamessageModuleView({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contract = ref.watch(messageConsistencyContractProvider);
    final compliance = ref.watch(schemaComplianceCheckerProvider('message'));
    final equivalence = ref.watch(crossModuleEquivalenceProvider);
    final architecture = ref.watch(architectureHealthInterpretationProvider);
    final parity = ref.watch(schemaParityMonitorProvider('message'));
    final snapshot = contract.buildSnapshot(ref, readOnly: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MetricCard(
          label: 'Compliance',
          value: compliance.isCompliant ? 'PASS' : 'FAIL',
          tone: compliance.isCompliant
              ? const Color(0xFF34D399)
              : const Color(0xFFF87171),
          details: compliance.violations.isEmpty
              ? 'Template contract matched.'
              : compliance.violations.join(' | '),
        ),
        const SizedBox(height: 12),
        _MetricCard(
          label: 'Cross-Module Equivalence',
          value: equivalence.isEquivalent ? 'ALIGNED' : 'DRIFT',
          tone: equivalence.isEquivalent
              ? const Color(0xFF34D399)
              : const Color(0xFFF87171),
          details: equivalence.violations.isEmpty
              ? 'message governance matches shared schema contract.'
              : equivalence.violations.join(' | '),
        ),
        const SizedBox(height: 12),
        _MetricCard(
          label: 'Architecture Interpretation',
          value: _classificationLabel(architecture.classification),
          tone: _classificationTone(architecture.classification),
          details:
              '${architecture.summary} | friend=${architecture.friendCompositeScore}% '
              'message=${architecture.messageCompositeScore}% '
              'policy=${architecture.policyVersion} '
              'advisory=${architecture.advisoryOnly} '
              '${architecture.reasons.join(' | ')}',
        ),
        const SizedBox(height: 12),
        _MetricCard(
          label: 'Parity',
          value: parity.isComparable
              ? (parity.isMatch ? 'MATCH' : 'MISMATCH')
              : 'LOADING',
          tone: !parity.isComparable
              ? const Color(0xFFFBBF24)
              : (parity.isMatch
                    ? const Color(0xFF34D399)
                    : const Color(0xFFF87171)),
          details:
              'legacy=${snapshot.legacyConversationIds.length} schema=${snapshot.schemaConversationIds.length}',
        ),
        const SizedBox(height: 12),
        Text(
          'Schema Conversation Snapshot',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: VelvetNoir.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (snapshot.schemaConversationIds.isEmpty)
          const _EmptyCard(label: 'No schema conversations to display.')
        else
          ...snapshot.schemaConversationIds.map((conversationId) {
            final unread =
                snapshot.schemaUnreadByConversation[conversationId] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: VelvetNoir.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: VelvetNoir.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversationId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: VelvetNoir.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      unread > 0 ? 'Unread' : 'Read',
                      style: TextStyle(
                        color: unread > 0
                            ? const Color(0xFFFBBF24)
                            : VelvetNoir.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  String _classificationLabel(DriftClassification classification) {
    return switch (classification) {
      DriftClassification.acceptableNoise => 'ACCEPTABLE',
      DriftClassification.structuralWarning => 'STRUCTURAL WARN',
      DriftClassification.behavioralDrift => 'BEHAVIORAL DRIFT',
    };
  }

  Color _classificationTone(DriftClassification classification) {
    return switch (classification) {
      DriftClassification.acceptableNoise => const Color(0xFF34D399),
      DriftClassification.structuralWarning => const Color(0xFFFBBF24),
      DriftClassification.behavioralDrift => const Color(0xFFF87171),
    };
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.tone,
    required this.details,
  });

  final String label;
  final String value;
  final Color tone;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: VelvetNoir.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: tone,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            details,
            style: const TextStyle(
              color: VelvetNoir.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: VelvetNoir.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(
        label,
        style: const TextStyle(
          color: VelvetNoir.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }
}

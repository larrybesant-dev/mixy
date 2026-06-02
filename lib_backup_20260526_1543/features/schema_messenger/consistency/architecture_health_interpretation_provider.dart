import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'architecture_health_interpretation_contract.dart';
import '../core/schema_engine/schema_module_health_provider.dart';
import 'cross_module_equivalence_provider.dart';

enum DriftClassification { acceptableNoise, structuralWarning, behavioralDrift }

class ArchitectureHealthInterpretationReport {
  const ArchitectureHealthInterpretationReport({
    required this.policyVersion,
    required this.advisoryOnly,
    required this.classification,
    required this.summary,
    required this.reasons,
    required this.friendCompositeScore,
    required this.messageCompositeScore,
    required this.crossModuleEquivalent,
    required this.friendComparable,
    required this.messageComparable,
    required this.friendParityMatch,
    required this.messageParityMatch,
    required this.friendTrend,
    required this.messageTrend,
  });

  final String policyVersion;
  final bool advisoryOnly;
  final DriftClassification classification;
  final String summary;
  final List<String> reasons;

  final int friendCompositeScore;
  final int messageCompositeScore;
  final bool crossModuleEquivalent;
  final bool friendComparable;
  final bool messageComparable;
  final bool friendParityMatch;
  final bool messageParityMatch;
  final String friendTrend;
  final String messageTrend;
}

/// Advisory-only interpretation layer.
///
/// This provider must not be used to drive writes, enforcement, or mutation.
/// It translates existing signal providers into a stable semantic category.
final architectureHealthInterpretationProvider =
    Provider.autoDispose<ArchitectureHealthInterpretationReport>((ref) {
  final friendHealth = ref.watch(schemaModuleHealthProvider('friends'));
  final messageHealth = ref.watch(schemaModuleHealthProvider('message'));
  final equivalence = ref.watch(crossModuleEquivalenceProvider);

  final reasons = <String>[];

  final isLoadingNoise = !friendHealth.comparable || !messageHealth.comparable;
  if (isLoadingNoise) {
    reasons.add(
      ArchitectureHealthInterpretationContract.reasonLoadingNoise,
    );
    return ArchitectureHealthInterpretationReport(
      policyVersion: ArchitectureHealthInterpretationContract.version,
      advisoryOnly: true,
      classification: DriftClassification.acceptableNoise,
      summary: ArchitectureHealthInterpretationContract.summaryLoadingNoise,
      reasons: reasons,
      friendCompositeScore: friendHealth.compositeScore,
      messageCompositeScore: messageHealth.compositeScore,
      crossModuleEquivalent: equivalence.isEquivalent,
      friendComparable: friendHealth.comparable,
      messageComparable: messageHealth.comparable,
      friendParityMatch: friendHealth.parityMatch,
      messageParityMatch: messageHealth.parityMatch,
      friendTrend: friendHealth.trend.name,
      messageTrend: messageHealth.trend.name,
    );
  }

  if (!equivalence.isEquivalent) {
    reasons.addAll(
      equivalence.violations.map((violation) => 'structural:$violation'),
    );
    return ArchitectureHealthInterpretationReport(
      policyVersion: ArchitectureHealthInterpretationContract.version,
      advisoryOnly: true,
      classification: DriftClassification.structuralWarning,
      summary:
          ArchitectureHealthInterpretationContract.summaryStructuralWarning,
      reasons: reasons,
      friendCompositeScore: friendHealth.compositeScore,
      messageCompositeScore: messageHealth.compositeScore,
      crossModuleEquivalent: equivalence.isEquivalent,
      friendComparable: friendHealth.comparable,
      messageComparable: messageHealth.comparable,
      friendParityMatch: friendHealth.parityMatch,
      messageParityMatch: messageHealth.parityMatch,
      friendTrend: friendHealth.trend.name,
      messageTrend: messageHealth.trend.name,
    );
  }

  final hasBehaviorDrift =
      !friendHealth.parityMatch || !messageHealth.parityMatch;
  if (hasBehaviorDrift) {
    reasons.add(
      'behavior:friendParity=${friendHealth.parityMatch};messageParity=${messageHealth.parityMatch}',
    );
    if (friendHealth.trend.name == 'degrading' ||
        messageHealth.trend.name == 'degrading') {
      reasons.add(
        'behavior:degrading_trend '
        'friend=${friendHealth.trend.name} message=${messageHealth.trend.name}',
      );
    }
    return ArchitectureHealthInterpretationReport(
      policyVersion: ArchitectureHealthInterpretationContract.version,
      advisoryOnly: true,
      classification: DriftClassification.behavioralDrift,
      summary: ArchitectureHealthInterpretationContract.summaryBehavioralDrift,
      reasons: reasons,
      friendCompositeScore: friendHealth.compositeScore,
      messageCompositeScore: messageHealth.compositeScore,
      crossModuleEquivalent: equivalence.isEquivalent,
      friendComparable: friendHealth.comparable,
      messageComparable: messageHealth.comparable,
      friendParityMatch: friendHealth.parityMatch,
      messageParityMatch: messageHealth.parityMatch,
      friendTrend: friendHealth.trend.name,
      messageTrend: messageHealth.trend.name,
    );
  }

  reasons.add(ArchitectureHealthInterpretationContract.reasonAligned);
  return ArchitectureHealthInterpretationReport(
    policyVersion: ArchitectureHealthInterpretationContract.version,
    advisoryOnly: true,
    classification: DriftClassification.acceptableNoise,
    summary: ArchitectureHealthInterpretationContract.summaryAligned,
    reasons: reasons,
    friendCompositeScore: friendHealth.compositeScore,
    messageCompositeScore: messageHealth.compositeScore,
    crossModuleEquivalent: equivalence.isEquivalent,
    friendComparable: friendHealth.comparable,
    messageComparable: messageHealth.comparable,
    friendParityMatch: friendHealth.parityMatch,
    messageParityMatch: messageHealth.parityMatch,
    friendTrend: friendHealth.trend.name,
    messageTrend: messageHealth.trend.name,
  );
});

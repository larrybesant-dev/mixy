import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/schema_engine/schema_compliance_checker.dart';
import '../core/schema_engine/schema_governance_contract.dart';
import '../messages/messages_consistency_contract.dart';

class CrossModuleEquivalenceReport {
  const CrossModuleEquivalenceReport({
    required this.isEquivalent,
    required this.expectedReference,
    required this.moduleReference,
    required this.expectedStableThreshold,
    required this.moduleStableThreshold,
    required this.expectedReconcileMinutes,
    required this.moduleReconcileMinutes,
    required this.violations,
  });

  final bool isEquivalent;
  final String expectedReference;
  final String moduleReference;
  final int expectedStableThreshold;
  final int moduleStableThreshold;
  final int expectedReconcileMinutes;
  final int moduleReconcileMinutes;
  final List<String> violations;
}

final crossModuleEquivalenceProvider = Provider<CrossModuleEquivalenceReport>((
  ref,
) {
  final messageContract = ref.watch(messageConsistencyContractProvider);
  final messageCompliance = ref.watch(
    schemaComplianceCheckerProvider('message'),
  );

  final violations = <String>[];

  final expectedReference = SchemaGovernanceContract.canonicalModel;
  final moduleReference = messageContract.canonicalReference;
  if (expectedReference != moduleReference) {
    violations.add('reference_mismatch:$moduleReference!=$expectedReference');
  }

  final expectedStableThreshold =
      SchemaGovernanceContract.stableMismatchThreshold;
  final moduleStableThreshold = messageContract.stableMismatchThreshold;
  if (expectedStableThreshold != moduleStableThreshold) {
    violations.add(
      'stable_threshold_mismatch:$moduleStableThreshold!=$expectedStableThreshold',
    );
  }

  final expectedReconcileMinutes =
      SchemaGovernanceContract.reconcileEveryMinutes;
  final moduleReconcileMinutes = messageContract.reconcileEveryMinutes;
  if (expectedReconcileMinutes != moduleReconcileMinutes) {
    violations.add(
      'reconcile_minutes_mismatch:$moduleReconcileMinutes!=$expectedReconcileMinutes',
    );
  }

  if (!messageCompliance.isCompliant) {
    violations.addAll(messageCompliance.violations.map((v) => 'message_$v'));
  }

  return CrossModuleEquivalenceReport(
    isEquivalent: violations.isEmpty,
    expectedReference: expectedReference,
    moduleReference: moduleReference,
    expectedStableThreshold: expectedStableThreshold,
    moduleStableThreshold: moduleStableThreshold,
    expectedReconcileMinutes: expectedReconcileMinutes,
    moduleReconcileMinutes: moduleReconcileMinutes,
    violations: violations,
  );
});





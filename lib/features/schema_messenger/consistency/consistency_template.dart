import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared trend classification for module health providers.
/// All governed modules import from here — do NOT redefine in module files.
enum MigrationHealthTrend { improving, stable, degrading }

/// Reusable consistency template for schema-vs-legacy module comparisons.
///
/// Module contract:
/// 1) Build one normalized snapshot from both pipelines.
/// 2) Evaluate deterministic parity through a pure function.
/// 3) Gate noisy events through stable mismatch threshold + dedupe.
/// 4) Emit structured telemetry from a single orchestration point.
abstract class ConsistencySnapshot {}

abstract class ConsistencyParityResult {
  bool get isComparable;
  bool get isMatch;
  String get signature;
}

typedef BuildSnapshot<TSnapshot extends ConsistencySnapshot> =
    TSnapshot Function(WidgetRef ref, {required bool readOnly});

typedef EvaluateSnapshot<
  TSnapshot extends ConsistencySnapshot,
  TResult extends ConsistencyParityResult
> = TResult Function(TSnapshot snapshot);

abstract class ConsistencyModuleContract<
  TSnapshot extends ConsistencySnapshot,
  TResult extends ConsistencyParityResult
> {
  const ConsistencyModuleContract();

  String get moduleId;
  String get canonicalReference;
  int get stableMismatchThreshold;
  int get reconcileEveryMinutes;

  TSnapshot buildSnapshot(WidgetRef ref, {required bool readOnly});
  TResult evaluate(TSnapshot snapshot);
}

class ConsistencyGateState {
  const ConsistencyGateState({
    required this.lastEmittedSignature,
    required this.candidateSignature,
    required this.candidateCount,
    required this.lastReconcileSignature,
  });

  final String lastEmittedSignature;
  final String candidateSignature;
  final int candidateCount;
  final String lastReconcileSignature;

  ConsistencyGateState copyWith({
    String? lastEmittedSignature,
    String? candidateSignature,
    int? candidateCount,
    String? lastReconcileSignature,
  }) {
    return ConsistencyGateState(
      lastEmittedSignature: lastEmittedSignature ?? this.lastEmittedSignature,
      candidateSignature: candidateSignature ?? this.candidateSignature,
      candidateCount: candidateCount ?? this.candidateCount,
      lastReconcileSignature:
          lastReconcileSignature ?? this.lastReconcileSignature,
    );
  }

  static const empty = ConsistencyGateState(
    lastEmittedSignature: '',
    candidateSignature: '',
    candidateCount: 0,
    lastReconcileSignature: '',
  );
}

class ConsistencyGateDecision {
  const ConsistencyGateDecision({
    required this.emitReactiveMismatch,
    required this.emitRestore,
    required this.emitReconcile,
    required this.nextState,
  });

  final bool emitReactiveMismatch;
  final bool emitRestore;
  final bool emitReconcile;
  final ConsistencyGateState nextState;
}

class ConsistencyComplianceReport {
  const ConsistencyComplianceReport({
    required this.isCompliant,
    required this.violations,
  });

  final bool isCompliant;
  final List<String> violations;
}

ConsistencyComplianceReport validateContractCompliance<
  TSnapshot extends ConsistencySnapshot,
  TResult extends ConsistencyParityResult
>(
  ConsistencyModuleContract<TSnapshot, TResult> contract, {
  required String expectedReference,
  required int expectedStableMismatchThreshold,
  required int expectedReconcileMinutes,
}) {
  final violations = <String>[];

  if (contract.canonicalReference != expectedReference) {
    violations.add(
      'reference_mismatch:${contract.canonicalReference}!=$expectedReference',
    );
  }
  if (contract.stableMismatchThreshold != expectedStableMismatchThreshold) {
    violations.add(
      'stable_threshold_mismatch:${contract.stableMismatchThreshold}!=$expectedStableMismatchThreshold',
    );
  }
  if (contract.reconcileEveryMinutes != expectedReconcileMinutes) {
    violations.add(
      'reconcile_minutes_mismatch:${contract.reconcileEveryMinutes}!=$expectedReconcileMinutes',
    );
  }
  if (contract.moduleId.trim().isEmpty) {
    violations.add('module_id_empty');
  }

  return ConsistencyComplianceReport(
    isCompliant: violations.isEmpty,
    violations: violations,
  );
}

ConsistencyGateDecision
evaluateConsistencyGate<TResult extends ConsistencyParityResult>({
  required TResult result,
  required ConsistencyGateState state,
  required int stableMismatchThreshold,
  required bool isPeriodicReconcile,
}) {
  if (!result.isComparable) {
    return ConsistencyGateDecision(
      emitReactiveMismatch: false,
      emitRestore: false,
      emitReconcile: false,
      nextState: state.copyWith(candidateSignature: '', candidateCount: 0),
    );
  }

  if (result.isMatch) {
    return ConsistencyGateDecision(
      emitReactiveMismatch: false,
      emitRestore:
          state.lastEmittedSignature.isNotEmpty && !isPeriodicReconcile,
      emitReconcile:
          isPeriodicReconcile &&
          state.lastReconcileSignature != result.signature,
      nextState: state.copyWith(
        lastEmittedSignature: '',
        candidateSignature: '',
        candidateCount: 0,
        lastReconcileSignature: isPeriodicReconcile
            ? result.signature
            : state.lastReconcileSignature,
      ),
    );
  }

  if (isPeriodicReconcile) {
    final suppress =
        state.lastEmittedSignature == result.signature ||
        state.lastReconcileSignature == result.signature;
    return ConsistencyGateDecision(
      emitReactiveMismatch: false,
      emitRestore: false,
      emitReconcile: !suppress,
      nextState: state.copyWith(lastReconcileSignature: result.signature),
    );
  }

  final sameCandidate = state.candidateSignature == result.signature;
  final nextCandidateCount = sameCandidate ? state.candidateCount + 1 : 1;
  final nextCandidateSignature = result.signature;

  final stable = nextCandidateCount >= stableMismatchThreshold;
  final isDuplicate = state.lastEmittedSignature == result.signature;

  return ConsistencyGateDecision(
    emitReactiveMismatch: stable && !isDuplicate,
    emitRestore: false,
    emitReconcile: false,
    nextState: state.copyWith(
      candidateSignature: nextCandidateSignature,
      candidateCount: nextCandidateCount,
      lastEmittedSignature: stable && !isDuplicate
          ? result.signature
          : state.lastEmittedSignature,
    ),
  );
}





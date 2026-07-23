import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mixvy/features/schema_messenger/consistency/architecture_health_interpretation_contract.dart';
import 'package:mixvy/features/schema_messenger/consistency/architecture_health_interpretation_provider.dart';
import 'package:mixvy/features/schema_messenger/consistency/cross_module_equivalence_provider.dart';
import 'package:mixvy/features/schema_messenger/core/schema_engine/schema_module_health_provider.dart';

void main() {
  group('architectureHealthInterpretationProvider', () {
    test('returns acceptable noise while comparability is pending', () {
      final container = ProviderContainer(
        overrides: [
          schemaModuleHealthProvider('friends').overrideWithValue(
            const SchemaModuleHealth(
              moduleId: 'friends',
              compositeScore: 80,
              structuralScore: 80,
              enforcementScore: 90,
              parityScore: 70,
              trend: MigrationHealthTrend.stable,
              comparable: false,
              parityMatch: false,
              mismatchCount: 0,
              reasons: <String>['parity_loading'],
            ),
          ),
          schemaModuleHealthProvider('message').overrideWithValue(
            const SchemaModuleHealth(
              moduleId: 'message',
              compositeScore: 85,
              structuralScore: 90,
              parityScore: 80,
              enforcementScore: 85,
              trend: MigrationHealthTrend.stable,
              comparable: true,
              parityMatch: true,
              mismatchCount: 0,
              reasons: <String>[],
            ),
          ),
          crossModuleEquivalenceProvider.overrideWithValue(
            const CrossModuleEquivalenceReport(
              isEquivalent: true,
              expectedReference: 'schema_v1',
              moduleReference: 'schema_v1',
              expectedStableThreshold: 2,
              moduleStableThreshold: 2,
              expectedReconcileMinutes: 5,
              moduleReconcileMinutes: 5,
              violations: <String>[],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final report = container.read(architectureHealthInterpretationProvider);

      expect(report.classification, DriftClassification.acceptableNoise);
      expect(report.advisoryOnly, isTrue);
      expect(
        report.policyVersion,
        ArchitectureHealthInterpretationContract.version,
      );
    });

    test('prioritizes structural warning over behavioral drift', () {
      final container = ProviderContainer(
        overrides: [
          schemaModuleHealthProvider('friends').overrideWithValue(
            const SchemaModuleHealth(
              moduleId: 'friends',
              compositeScore: 70,
              structuralScore: 70,
              enforcementScore: 90,
              parityScore: 60,
              trend: MigrationHealthTrend.degrading,
              comparable: true,
              parityMatch: false,
              mismatchCount: 2,
              reasons: <String>['status_mismatch:1'],
            ),
          ),
          schemaModuleHealthProvider('message').overrideWithValue(
            const SchemaModuleHealth(
              moduleId: 'message',
              compositeScore: 75,
              structuralScore: 80,
              parityScore: 65,
              enforcementScore: 85,
              trend: MigrationHealthTrend.degrading,
              comparable: true,
              parityMatch: false,
              mismatchCount: 1,
              reasons: <String>['unread_mismatch:1'],
            ),
          ),
          crossModuleEquivalenceProvider.overrideWithValue(
            const CrossModuleEquivalenceReport(
              isEquivalent: false,
              expectedReference: 'schema_v1',
              moduleReference: 'schema_v2',
              expectedStableThreshold: 2,
              moduleStableThreshold: 3,
              expectedReconcileMinutes: 5,
              moduleReconcileMinutes: 10,
              violations: <String>['reference_mismatch'],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final report = container.read(architectureHealthInterpretationProvider);

      expect(report.classification, DriftClassification.structuralWarning);
      expect(
        report.summary,
        ArchitectureHealthInterpretationContract.summaryStructuralWarning,
      );
    });

    test(
      'returns behavioral drift when structure is aligned but parity drifts',
      () {
        final container = ProviderContainer(
          overrides: [
            schemaModuleHealthProvider('friends').overrideWithValue(
              const SchemaModuleHealth(
                moduleId: 'friends',
                compositeScore: 82,
                structuralScore: 92,
                enforcementScore: 90,
                parityScore: 70,
                trend: MigrationHealthTrend.degrading,
                comparable: true,
                parityMatch: false,
                mismatchCount: 2,
                reasons: <String>['status_mismatch:2'],
              ),
            ),
            schemaModuleHealthProvider('message').overrideWithValue(
              const SchemaModuleHealth(
                moduleId: 'message',
                compositeScore: 84,
                structuralScore: 94,
                parityScore: 72,
                enforcementScore: 90,
                trend: MigrationHealthTrend.stable,
                comparable: true,
                parityMatch: true,
                mismatchCount: 0,
                reasons: <String>[],
              ),
            ),
            crossModuleEquivalenceProvider.overrideWithValue(
              const CrossModuleEquivalenceReport(
                isEquivalent: true,
                expectedReference: 'schema_v1',
                moduleReference: 'schema_v1',
                expectedStableThreshold: 2,
                moduleStableThreshold: 2,
                expectedReconcileMinutes: 5,
                moduleReconcileMinutes: 5,
                violations: <String>[],
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final report = container.read(architectureHealthInterpretationProvider);

        expect(report.classification, DriftClassification.behavioralDrift);
        expect(
          report.summary,
          ArchitectureHealthInterpretationContract.summaryBehavioralDrift,
        );
      },
    );
  });
}

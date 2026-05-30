import 'package:flutter/material.dart';
/// Frozen semantics for architecture interpretation.
///
/// This file is the only place where interpretation meaning may be revised.
/// Treat changes here as governance-versioned changes, not routine refactors.
class ArchitectureHealthInterpretationContract {
  const ArchitectureHealthInterpretationContract._();

  static const String version = 'v1_frozen_2026_04_12';

  // Strict precedence:
  // 1) comparability not ready => acceptable noise
  // 2) equivalence mismatch => structural warning
  // 3) parity mismatch with aligned structure => behavioral drift
  // 4) otherwise aligned baseline => acceptable noise
  static const String summaryLoadingNoise =
      'Signals are still converging; treat drift as loading noise.';

  static const String summaryStructuralWarning =
      'Cross-domain governance contracts diverged. Investigate structural semantics before runtime behavior.';

  static const String summaryBehavioralDrift =
      'Contract structure is aligned, but observed runtime behavior is drifting between governed modules.';

  static const String summaryAligned =
      'Contracts and behavior are aligned across Friends and message.';

  static const String reasonLoadingNoise =
      'loading_noise:comparability_pending';

  static const String reasonAligned = 'aligned:contracts_and_behavior';
}





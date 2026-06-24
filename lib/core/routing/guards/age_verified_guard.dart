/// Age Verified Guard
/// Protects routes that require 18+ age verification
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// TEMP DISABLED: import '../../features/onboarding/providers/onboarding_controller.dart';
// TEMP DISABLED: import '../../features/onboarding/screens/age_gate_page.dart';

/// Guard widget that checks if user has verified their age (18+)
/// If not verified, shows AgeGatePage
class AgeVerifiedGuard extends ConsumerWidget {
  final Widget child;

  const AgeVerifiedGuard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TEMP DISABLED: Onboarding bypassed for development
    return child;

    // Original guard logic (commented out):
    // final ageVerifiedAsync = ref.watch(hasVerifiedAgeProvider);
    // return ageVerifiedAsync.when(
    //   data: (isVerified) => isVerified ? child : AgeGatePage(...),
    //   loading: () => CircularProgressIndicator(),
    //   error: (error, stack) => ErrorScreen(),
    // );
  }
}

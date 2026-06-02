import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/presentation/screens/feature_degraded_screen.dart';

abstract final class AuthInvariant {
  static bool hasAuthenticatedUid(String? uid) {
    final normalized = uid?.trim() ?? '';
    return normalized.isNotEmpty;
  }

  static Widget redirectToAuth() => const _AuthInvariantRedirect();

  static Widget authRequiredScreen({required String message}) {
    return FeatureDegradedScreen(
      title: 'Sign in required',
      message: message,
      primaryLabel: 'Sign in',
      primaryRoute: '/auth',
      icon: Icons.lock_outline,
    );
  }
}

class _AuthInvariantRedirect extends StatefulWidget {
  const _AuthInvariantRedirect();

  @override
  State<_AuthInvariantRedirect> createState() => _AuthInvariantRedirectState();
}

class _AuthInvariantRedirectState extends State<_AuthInvariantRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GoRouter.of(context).go('/auth');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

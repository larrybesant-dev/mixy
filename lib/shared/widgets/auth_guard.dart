import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/shared/providers/providers.dart';
import 'package:mixmingle/shared/widgets/club_background.dart';

/// Authentication guard widget that checks if user is logged in
/// before allowing access to protected routes
class AuthGuard extends ConsumerWidget {
  final Widget child;
  final Widget? loadingWidget;
  final Widget? unauthenticatedWidget;

  const AuthGuard({
    super.key,
    required this.child,
    this.loadingWidget,
    this.unauthenticatedWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if we're in test mode (bypass authentication for testing)
    const isTestMode = bool.fromEnvironment('TEST_MODE', defaultValue: false);

    if (isTestMode) {
      return child;
    }

    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // User is authenticated, show the protected content
          return child;
        } else {
          // User is not authenticated, redirect to login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/login');
          });
          return const SizedBox
              .shrink(); // Return empty widget while navigating
        }
      },
      loading: () {
        // Still checking authentication status
        return loadingWidget ?? _buildLoadingWidget();
      },
      error: (error, stack) {
        // Error checking authentication, redirect to login
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed('/login');
        });
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoadingWidget() {
    return const ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFFFF4C4C),
              ),
              SizedBox(height: 16),
              Text(
                'Checking authentication...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/shared/providers/all_providers.dart';
import 'package:mixmingle/core/stubs/dev_stubs.dart';
import 'package:mixmingle/app/app_routes.dart';

/// Guard that checks if user is eligible to access event-related features
/// such as speed dating or specific events
class EventGuard extends ConsumerWidget {
  final Widget child;
  final bool requiresActiveEvent;
  final String? eventId;

  const EventGuard({
    super.key,
    required this.child,
    this.requiresActiveEvent = false,
    this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If specific event is required, check if it exists and is accessible
    if (eventId != null) {
      final eventAsync = ref.watch(eventProvider(eventId!));

      return eventAsync.when(
        data: (event) {
          if (event == null) {
            return _buildErrorState(
              context,
              'Event not found',
              'The event you\'re trying to access doesn\'t exist.',
            );
          }

          // Check if event is in the future or currently active
          if (event.startTime
              .isBefore(DateTime.now().subtract(const Duration(hours: 2)))) {
            return _buildErrorState(
              context,
              'Event has ended',
              'This event has already finished.',
            );
          }

          return child;
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stack) => _buildErrorState(
          context,
          'Error loading event',
          error.toString(),
        ),
      );
    }

    // If requires active event (e.g., for speed dating)
    if (requiresActiveEvent) {
      final activeSession = ref.watch(activeSpeedDatingSessionProvider);

      return activeSession.when(
        data: (session) {
          if (session == null) {
            // No active session, show information screen
            return Scaffold(
              appBar: AppBar(
                title: const Text('Speed Dating'),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.event_busy,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'No Active Session',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'There are no active speed dating sessions right now. Check the events page for upcoming sessions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context)
                              .pushReplacementNamed(AppRoutes.events);
                        },
                        icon: const Icon(Icons.event),
                        label: const Text('Browse Events'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context)
                              .pushReplacementNamed(AppRoutes.home);
                        },
                        child: const Text('Back to Home'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Has active session, allow access
          return child;
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stack) => _buildErrorState(
          context,
          'Error checking session',
          error.toString(),
        ),
      );
    }

    // No specific requirements, allow access
    return child;
  }

  Widget _buildErrorState(BuildContext context, String title, String message) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.home);
                },
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

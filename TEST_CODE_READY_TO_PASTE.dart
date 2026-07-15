/// ============================================================================
/// PASTE THIS INTO: lib/features/room/presentation/live_room_screen.dart
/// 
/// INSTRUCTIONS:
/// 1. Find this line: class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen>
/// 2. Replace "with WidgetsBindingObserver" with the code below
/// 3. This enables test buttons for alert verification
/// ============================================================================

import 'package:mixvy/services/diagnostic_logger.dart'; // ADD THIS IMPORT AT TOP

// CHANGE THIS LINE:
// class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen>
//     with WidgetsBindingObserver {

// TO THIS:
// class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen>
//     with WidgetsBindingObserver, DiagnosticLogger {

/// Then in your build() method's Scaffold, add this to the Stack or Positioned widgets:
/// 
/// Add this code inside your build() method to create the test button overlay:

// ============================================================================
// COPY THIS ENTIRE BLOCK INTO YOUR build() METHOD
// ============================================================================

// TEMPORARY TEST BUTTONS - DELETE BEFORE COMMIT
if (kDebugMode) // Only show in debug mode
  Positioned(
    bottom: 120,
    right: 16,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Test WARNING trigger
        FloatingActionButton.extended(
          heroTag: 'warning-test',
          label: const Text('⚠️ Test WARNING'),
          backgroundColor: Colors.orange,
          tooltip: 'Trigger a test WARNING alert',
          onPressed: () {
            logWarning(
              'Test Warning Triggered - Verifying alert pipeline',
              metadata: {
                'test_type': 'warning',
                'timestamp': DateTime.now().toIso8601String(),
                'room_id': widget.roomId,
              },
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ WARNING logged to Crashlytics (check in 2 min)'),
                duration: Duration(seconds: 3),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // Test ERROR trigger
        FloatingActionButton.extended(
          heroTag: 'error-test',
          label: const Text('🔴 Test ERROR'),
          backgroundColor: Colors.red,
          tooltip: 'Trigger a test ERROR alert',
          onPressed: () {
            logError(
              'Test Error Triggered - Verifying alert pipeline',
              error: Exception('Controlled test failure'),
              metadata: {
                'test_type': 'error',
                'timestamp': DateTime.now().toIso8601String(),
                'room_id': widget.roomId,
              },
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ ERROR logged to Crashlytics (check in 2 min)'),
                duration: Duration(seconds: 3),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // Test CRITICAL trigger
        FloatingActionButton.extended(
          heroTag: 'critical-test',
          label: const Text('🚨 Test CRITICAL'),
          backgroundColor: Colors.redAccent,
          tooltip: 'Trigger a test CRITICAL alert',
          onPressed: () {
            logCritical(
              'Test Critical Triggered - Verifying EMERGENCY alert pipeline',
              error: Exception('Controlled critical test failure'),
              metadata: {
                'test_type': 'critical',
                'timestamp': DateTime.now().toIso8601String(),
                'room_id': widget.roomId,
              },
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ CRITICAL logged to Crashlytics (check in 2 min)'),
                duration: Duration(seconds: 3),
              ),
            );
          },
        ),
      ],
    ),
  ),

// ============================================================================
// THAT'S IT! After adding the above:
// 
// 1. Run: flutter run -d chrome
// 2. Navigate to any live room
// 3. Click the buttons (⚠️ then 🔴 then 🚨)
// 4. Check Gmail in 2 minutes
// 5. Delete this entire block before committing
// ============================================================================

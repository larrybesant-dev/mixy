import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mixvy/firebase_options.dart';
import 'package:mixvy/core/theme.dart';
import 'observability/provider_observer.dart';

/// DIAGNOSTIC TEST ENTRY POINT
/// This bypasses the router entirely to isolate the crash.
/// If this runs without errors, the issue is in the router setup.
/// If this also crashes, the issue is in core app initialization.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ProviderScope(
      observers: [MixvyProviderObserver()],
      child: const _DiagnosticApp(),
    ),
  );
}

class _DiagnosticApp extends StatelessWidget {
  const _DiagnosticApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MixVy Diagnostic',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: VelvetNoir.surface,
      ),
      home: Scaffold(
        backgroundColor: VelvetNoir.surface,
        appBar: AppBar(
          title: const Text('Diagnostic Test'),
          backgroundColor: VelvetNoir.surface,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                size: 64,
                color: VelvetNoir.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'App Rendering Success!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: VelvetNoir.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'If you see this, the crash is in:\n→ GoRouter initialization\n→ Provider setup\n→ Not in LiveRoomScreen refactor',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: VelvetNoir.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Button works! No provider errors.'),
                      backgroundColor: VelvetNoir.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.touch_app),
                label: const Text('Test Button'),
                style: FilledButton.styleFrom(
                  backgroundColor: VelvetNoir.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/router/app_router.dart';
import 'package:mixvy/features/payments/payment_provider.dart';
import 'boot_state.dart';
import 'boot_state_notifier.dart';

class MixVyApp extends ConsumerWidget {
  const MixVyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootState = ref.watch(bootStateProvider);

    // Initialize Stripe early in the app lifecycle
    ref.watch(stripeInitializationProvider);

    // Automatically transition to ready state for local development run
    if (bootState == BootState.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(bootStateProvider.notifier).setReady();
      });
    }

    // While loading, show the loading container
    if (bootState == BootState.loading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF0A0A0E),
          body: Center(
            child: CircularProgressIndicator(color: Colors.purple),
          ),
        ),
      );
    }

    // Keep router instance stable (cached, not recreated on rebuild).
    // State changes are driven by refreshListenable in routerProvider,
    // which watches auth/user changes without recreating the router itself.
    final router = ref.read(routerProvider);

    return MaterialApp.router(
      title: 'MixVy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0E), // VelvetNoir surface tint
      ),
      routerConfig: router,
    );
  }
}

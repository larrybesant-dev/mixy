import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/app_settings_service.dart';
import 'boot_state.dart';
import 'boot_state_notifier.dart';
import '../router/app_router.dart';
import '../presentation/providers/app_settings_provider.dart';
import '../theme/font_fallbacks.dart';
import '../theme/app_theme.dart';
import '../core/theme.dart';
import '../shared/widgets/beta_feedback_overlay.dart';
import '../shared/widgets/app_debug_overlay.dart';
import '../shared/widgets/incoming_call_overlay.dart';
import '../features/after_dark/providers/after_dark_provider.dart';
import '../features/after_dark/theme/after_dark_theme.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/profile/profile_controller.dart';
import '../services/presence_controller.dart';
import '../core/events/event_providers.dart';
import '../core/services/feature_gate_service.dart';
import '../observability/startup_timeline.dart';
import '../firebase_options.dart';
import '../dev/system_stress_runner.dart';
import '../services/push_messaging_service.dart';

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final startup = StartupProfiler.instance;
  final bootStateNotifier = ref.read(bootStateProvider.notifier);
  if (Firebase.apps.isEmpty) {
    bootStateNotifier.setFailed();
    developer.log(
      'Firebase app is not initialized during bootstrap',
      name: 'appBootstrapProvider',
    );
    startup.markBootstrapResolved(
      resolution: BootstrapResolution.failed,
      detail: 'reason=firebase_apps_empty',
    );
    return;
  }

  final auth = FirebaseAuth.instance;

  try {
    bool timeoutHit = false;
    User? authUser;
    try {
      authUser = await auth.authStateChanges().first.timeout(
        const Duration(seconds: 20),
      );
    } on TimeoutException {
      timeoutHit = true;
      // Fallback: use current user immediately available.
      authUser = auth.currentUser;
      developer.log(
        'Auth bootstrap stream timed out; using currentUser as fallback',
        name: 'appBootstrapProvider',
      );
    }

    if (timeoutHit && authUser == null) {
      bootStateNotifier.setDegraded();
      startup.markBootstrapResolved(
        resolution: BootstrapResolution.degraded,
        detail: 'reason=auth_timeout_without_user',
      );
      return;
    }

    await ref.read(appSettingsControllerProvider.notifier).load();
    // Auth check succeeded; boot is ready
    bootStateNotifier.setReady();
    startup.markBootstrapResolved(
      resolution: BootstrapResolution.ready,
      detail: 'user=${auth.currentUser != null}',
    );
  } catch (error, stackTrace) {
    developer.log(
      'Auth state check failed during bootstrap',
      error: error,
      stackTrace: stackTrace,
      name: 'appBootstrapProvider',
    );
    bootStateNotifier.setDegraded();
    startup.markBootstrapResolved(
      resolution: BootstrapResolution.degraded,
      error: error,
      stackTrace: stackTrace,
    );
  }

  if (!kIsWeb) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
});

class MixVyApp extends ConsumerStatefulWidget {
  const MixVyApp({super.key});

  @override
  ConsumerState<MixVyApp> createState() => _MixVyAppState();
}

class _MixVyAppState extends ConsumerState<MixVyApp> {
  bool _runtimeStarted = false;
  bool _runtimeQueued = false;
  bool _stressRunnerQueued = false;
  int _bootHintIndex = 0;
  Timer? _bootHintTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  ProviderSubscription<FeatureGateState>? _featureGateSub;

  static const List<String> _bootHints = <String>[
    'Connecting...',
    'Preparing your space...',
    'Almost ready...',
  ];

  @override
  void initState() {
    super.initState();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.contains(ConnectivityResult.none);
      if (isOffline) {
        developer.log('App is offline', name: 'MixVyApp');
      }
    });
    _bootHintTimer = Timer.periodic(const Duration(milliseconds: 1400), (
      timer,
    ) {
      if (!mounted || _bootHintIndex >= _bootHints.length - 1) {
        timer.cancel();
        return;
      }

      setState(() {
        _bootHintIndex += 1;
      });
    });

    _featureGateSub = ref.listenManual<FeatureGateState>(
      featureGateControllerProvider,
      (_, next) {
        unawaited(
          PushMessagingService.instance.setPushEnabled(
            next.enablePushNotifications,
          ),
        );
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _bootHintTimer?.cancel();
    _connectivitySub?.cancel();
    _featureGateSub?.close();
    super.dispose();
  }

  Future<void> _startRuntimeServices() async {
    if (_runtimeStarted || _runtimeQueued) return;

    _runtimeQueued = true;

    try {
      final uid = ref.read(authControllerProvider).uid;

      if (uid != null && uid.isNotEmpty) {
        await ref.read(profileControllerProvider.notifier).loadCurrentProfile();
      }

      ref.read(presenceControllerProvider);
      ref.read(eventPipelineProvider);
    } catch (error, stackTrace) {
      developer.log(
        'Runtime services failed during startup',
        error: error,
        stackTrace: stackTrace,
        name: 'MixVyApp',
      );
      ref.read(bootStateProvider.notifier).setDegraded();
    } finally {
      if (mounted) {
        setState(() => _runtimeStarted = true);
      }
    }
  }

  Future<void> _retryStartup() async {
    ref.read(bootStateProvider.notifier).setLoading();

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      ref.invalidate(appBootstrapProvider);
    } catch (error, stackTrace) {
      developer.log(
        'Retry startup failed',
        error: error,
        stackTrace: stackTrace,
        name: 'MixVyApp',
      );
      ref.read(bootStateProvider.notifier).setFailed();
    }
  }

  void _queueStressRunnerIfEnabled({
    required GoRouter router,
    required AuthState authState,
  }) {
    if (!kEnableSystemStressRunner || _stressRunnerQueued) {
      return;
    }
    if (!authState.isRoutingStable) {
      return;
    }

    _stressRunnerQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        MixVySystemStressRunner.run(
          ref: ref,
          router: router,
          authState: authState,
        ),
      );
    });
  }

  Widget _buildBootShell({
    String? message,
    String? actionLabel,
    Future<void> Function()? onAction,
  }) {
    final bootMessage = message ?? _bootHints[_bootHintIndex];
    final body = Scaffold(
      backgroundColor: VelvetNoir.surface,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF130F0C), VelvetNoir.surface, Color(0xFF221118)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: VelvetNoir.primary.withValues(alpha: 0.45),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x33D4AF37), Color(0x33781E2B)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33781E2B),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'M',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: VelvetNoir.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'MixVy',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: VelvetNoir.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.06),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    key: ValueKey<String>(bootMessage),
                    children: [
                      Text(
                        bootMessage,
                        style: const TextStyle(
                          color: VelvetNoir.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Loading your rooms, profile, and live state.',
                        style: TextStyle(
                          color: Color(0xCCF7EDE2),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: VelvetNoir.primary,
                    strokeWidth: 2.6,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => unawaited(onAction()),
                    child: Text(actionLabel),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return MaterialApp(
      title: 'MixVy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: midnightCreativeTheme,
      home: body,
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => body),
    );
  }

  Widget _buildDegradedBanner(Widget child) {
    return Stack(
      children: [
        child,
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade900,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Limited mode: some cloud features are temporarily unavailable.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check fatal failure first — before touching appBootstrapProvider — so
    // we never show a spurious loading frame when Firebase init already failed.
    final bootState = ref.watch(bootStateProvider);

    if (bootState == BootState.failed) {
      return _buildBootShell(
        message: 'Session startup failed. Retry session.',
        actionLabel: 'Retry session',
        onAction: _retryStartup,
      );
    }

    final boot = ref.watch(appBootstrapProvider);
    final authState = ref.watch(authControllerProvider);

    if (bootState == BootState.loading || boot.isLoading) {
      return _buildBootShell();
    }

    // Only route once auth bootstrap has reached a stable phase.
    if (!authState.isRoutingStable) {
      final statusMessage = switch (authState.phase) {
        AuthBootstrapPhase.booting => 'Launching auth runtime...',
        AuthBootstrapPhase.initializingAuth =>
          'Resolving your secure session...',
        _ => 'Preparing your connection and live state...',
      };
      return _buildBootShell(message: statusMessage);
    }

    return boot.when(
      loading: () => _buildBootShell(),
      error: (_, stackTrace) =>
          _buildBootShell(message: 'Recovering startup...'),
      data: (_) {
        if (!_runtimeStarted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_startRuntimeServices());
          });

          return _buildBootShell(message: 'Preparing your rooms...');
        }

        final router = ref.watch(routerProvider);
        _queueStressRunnerIfEnabled(router: router, authState: authState);

        final settings =
            ref.watch(appSettingsControllerProvider).valueOrNull ??
            const AppSettings.defaults();

        final locale = Locale(settings.localeCode);
        final afterDark = ref.watch(afterDarkSessionProvider);

        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          StartupProfiler.instance.markFirstFrameRendered();
        });

        return MaterialApp.router(
          title: 'MixVy',
          theme: afterDark ? afterDarkTheme : AppTheme.light,
          darkTheme: afterDark ? afterDarkTheme : midnightCreativeTheme,
          themeMode: afterDark ? ThemeMode.dark : settings.themeMode,
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('es'), Locale('fr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final routedChild = child ?? const SizedBox.shrink();
            final diagnosticsChild = kDebugMode
                ? AppDebugOverlay(child: routedChild)
                : routedChild;

            final appChild = DefaultTextStyle.merge(
              style: const TextStyle(
                fontFamilyFallback: mixvyFontFamilyFallback,
              ),
              child: IncomingCallOverlay(
                child: BetaFeedbackOverlay(child: diagnosticsChild),
              ),
            );

            if (bootState == BootState.degraded) {
              return _buildDegradedBanner(appChild);
            }

            return appChild;
          },
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

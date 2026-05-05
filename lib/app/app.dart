import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
import '../core/providers/push_messaging_providers.dart';
import '../core/services/feature_gate_service.dart';
import '../presentation/providers/wallet_provider.dart';
import '../features/payments/premium_entitlement.dart';
import '../features/feed/providers/feed_providers.dart';
import '../observability/startup_timeline.dart';
import '../firebase_options.dart';
import '../dev/system_stress_runner.dart';
import '../services/push_messaging_service.dart';

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final startup = StartupProfiler.instance;
  final bootStateNotifier = ref.read(bootStateProvider.notifier);
  bootStateNotifier.setLoading();

  final bootstrapWatchdog = Timer(const Duration(seconds: 8), () {
    if (bootStateNotifier.isLoadingState) {
      bootStateNotifier.setFailed();
      startup.markBootstrapResolved(
        resolution: BootstrapResolution.failed,
        detail: 'reason=bootstrap_timeout',
      );
      developer.log(
        'BOOTSTRAP TIMEOUT: exceeded 8s while still loading',
        name: 'appBootstrapProvider',
      );
    }
  });

  var hasDegradedDependency = false;

  try {
    // Env is optional at boot time. Keep startup alive if the file is missing
    // or malformed and allow feature-level fallbacks.
    try {
      await dotenv.load(fileName: 'assets/.env');
    } catch (error, stackTrace) {
      developer.log(
        'ENV LOAD FAILED: $error',
        error: error,
        stackTrace: stackTrace,
        name: 'appBootstrapProvider',
      );
      hasDegradedDependency = true;
    }

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }

    FirebaseFirestore.instance.settings = kIsWeb
        ? const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
            webPersistentTabManager: WebPersistentMultipleTabManager(),
          )
        : const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );

    // Push is optional per platform/runtime; do not fail app boot if unavailable.
    // Time-box initialization so web/incognito push capability checks cannot
    // pin the app in a perpetual loading shell.
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      PushMessagingService.instance.setNavigatorKey(rootNavigatorKey);
      await PushMessagingService.instance
          .initialize()
          .timeout(const Duration(seconds: 4));
    } catch (error, stackTrace) {
      developer.log(
        'PUSH INIT FAILED: $error',
        error: error,
        stackTrace: stackTrace,
        name: 'appBootstrapProvider',
      );
      hasDegradedDependency = true;
    }

    // Crashlytics is optional for app startup.
    try {
      if (!kIsWeb && const bool.fromEnvironment('dart.vm.product')) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      }
    } catch (error, stackTrace) {
      developer.log(
        'CRASHLYTICS INIT FAILED: $error',
        error: error,
        stackTrace: stackTrace,
        name: 'appBootstrapProvider',
      );
      hasDegradedDependency = true;
    }

    if (bootStateNotifier.isLoadingState) {
      bootStateNotifier.setReady();
      if (hasDegradedDependency) {
        bootStateNotifier.setDegraded();
      }
    }

    startup.markFirebaseReady(success: true);
    startup.markBootstrapResolved(
      resolution: hasDegradedDependency
          ? BootstrapResolution.degraded
          : BootstrapResolution.ready,
      detail: hasDegradedDependency
          ? 'firebase_initialized_optional_dependency_failed'
          : 'firebase_initialized',
    );
  } catch (error, stackTrace) {
    bootStateNotifier.setFailed();
    developer.log(
      'FIREBASE INIT FAILED: $error',
      error: error,
      stackTrace: stackTrace,
      name: 'appBootstrapProvider',
    );
    startup.markFirebaseReady(
      success: false,
      error: error,
      stackTrace: stackTrace,
    );
    startup.markBootstrapResolved(
      resolution: BootstrapResolution.failed,
      detail: 'reason=firebase_init_failed',
    );
  } finally {
    bootstrapWatchdog.cancel();
  }
});

class MixVyApp extends ConsumerStatefulWidget {
  const MixVyApp({super.key});

  @override
  ConsumerState<MixVyApp> createState() => _MixVyAppState();
}

class _MixVyAppState extends ConsumerState<MixVyApp>
    with WidgetsBindingObserver {
  bool _fastLaneQueued = false;
  bool _fastLaneStarted = false;
  bool _backgroundLaneQueued = false;
  bool _interactiveReadyMarked = false;
  bool _wasPaused = false;
  bool _stressRunnerQueued = false;
  bool _isOffline = false;
  int _bootHintIndex = 0;
  Timer? _bootHintTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  ProviderSubscription<FeatureGateState>? _featureGateSub;
  bool? _pendingPushEnabled;

  static const List<String> _bootHints = <String>[
    'Connecting...',
    'Preparing your space...',
    'Almost ready...',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.contains(ConnectivityResult.none);
      if (isOffline != _isOffline) {
        setState(() => _isOffline = isOffline);
        developer.log(
          isOffline ? 'App went offline' : 'App back online',
          name: 'MixVyApp',
        );
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
        _pendingPushEnabled = next.enablePushNotifications;
        _maybeApplyPushFeatureGate();
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bootHintTimer?.cancel();
    _connectivitySub?.cancel();
    _featureGateSub?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
      // Record session dropoff for funnel analytics.
      SessionFunnelTracker.instance.markSessionDropoff();
      return;
    }

    if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      StartupProfiler.instance.markWarmStartBegin();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        StartupProfiler.instance.markWarmInteractiveReady();
      });
    }
  }

  Future<void> _applyPushFeatureGate(bool enabled) async {
    try {
      await PushMessagingService.instance.setPushEnabled(enabled);
    } catch (error, stackTrace) {
      developer.log(
        'Push feature-gate sync skipped until messaging is available',
        error: error,
        stackTrace: stackTrace,
        name: 'MixVyApp',
      );
    }
  }

  void _maybeApplyPushFeatureGate() {
    final pending = _pendingPushEnabled;
    if (pending == null || Firebase.apps.isEmpty) {
      return;
    }
    _pendingPushEnabled = null;
    unawaited(_applyPushFeatureGate(pending));
  }

  Future<void> _startFastLaneServices() async {
    if (_fastLaneStarted) return;
    _fastLaneStarted = true;

    try {
      unawaited(ref.read(appSettingsControllerProvider.notifier).load());

      final uid = ref.read(authControllerProvider).uid;
      if (uid != null && uid.isNotEmpty) {
        unawaited(ref.read(profileControllerProvider.notifier).loadCurrentProfile());
      }

      ref.read(presenceControllerProvider);
      ref.read(eventPipelineProvider);
      ref.read(walletDetailsProvider);
      ref.read(vipEntitlementProvider);
    } catch (error, stackTrace) {
      developer.log(
        'Fast lane services failed during startup',
        error: error,
        stackTrace: stackTrace,
        name: 'MixVyApp',
      );
    }
  }

  Future<void> _startBackgroundLaneServices() async {
    if (_backgroundLaneQueued) return;
    _backgroundLaneQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        // Keep only lightweight warmups here to avoid long-lived startup listeners.
        unawaited(ref.read(currentUserActivitiesProvider.future));
        ref.read(homeFeedSnapshotProvider);
      });
    });
  }

  void _queueStartupLanes(AuthState authState) {
    if (!authState.isAuthenticatedStable || _fastLaneQueued) {
      return;
    }
    _fastLaneQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_startFastLaneServices());
      unawaited(_startBackgroundLaneServices());
    });
  }

  Future<void> _retryStartup() async {
    ref.read(bootStateProvider.notifier).setLoading();
    ref.invalidate(appBootstrapProvider);
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

  /// Shown whenever the device reports no network connectivity.
  /// Cached Firestore data continues to work; this banner tells the user
  /// why live content may be stale.
  Widget _buildOfflineBanner(Widget child) {
    return Stack(
      children: [
        child,
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: VelvetNoir.onSurface.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 15,
                    color: VelvetNoir.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'You\'re offline — showing cached content.',
                    style: TextStyle(
                      color: VelvetNoir.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appBootstrapProvider);
    ref.watch(pushMessagingAuthCoordinatorProvider);  // Coordinate push auth with canonical auth stream
    final bootState = ref.watch(bootStateProvider);

    if (bootState == BootState.loading) {
      return _buildBootShell();
    }

    if (bootState == BootState.failed) {
      return _buildBootShell(
        message: 'Session startup failed. Retry session.',
        actionLabel: 'Retry session',
        onAction: _retryStartup,
      );
    }

    if (bootState == BootState.ready || bootState == BootState.degraded) {
      _maybeApplyPushFeatureGate();
    }

    final authState = ref.watch(authControllerProvider);
    final router = ref.watch(routerProvider);
    _queueStressRunnerIfEnabled(router: router, authState: authState);
    _queueStartupLanes(authState);

    final settings =
        ref.watch(appSettingsControllerProvider).valueOrNull ??
        const AppSettings.defaults();

    final locale = Locale(settings.localeCode);
    final afterDark = ref.watch(afterDarkSessionProvider);

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      StartupProfiler.instance.markFirstFrameRendered();
      if (!_interactiveReadyMarked) {
        _interactiveReadyMarked = true;
        StartupProfiler.instance.markFirstInteractiveReady(
          launchType: 'cold',
        );
      }
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

        if (_isOffline) {
          return _buildOfflineBanner(appChild);
        }

        return appChild;
      },
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

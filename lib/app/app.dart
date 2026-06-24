// Removed invalid imports
// import 'dart:js_util' as js_util;
// import 'package:mixmingle/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'app_routes.dart';
import '../core/theme/neon_theme.dart';
import '../services/fcm_notification_service.dart';

/// Global navigator key — shared with FcmNotificationService so that push
/// notification taps can navigate without a BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'appNavigator');

class MixMingleApp extends StatefulWidget {
  const MixMingleApp({super.key});

  @override
  State<MixMingleApp> createState() => _MixMingleAppState();
}

class _MixMingleAppState extends State<MixMingleApp> {
  @override
  void initState() {
    super.initState();
    // Wire the navigator key so FCM notification taps can navigate.
    FcmNotificationService.setNavigatorKey(appNavigatorKey);
    debugPrint('[MixMingleApp] navigator key registered with FCM service');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('ðŸ—ï¸ Building MixMingleApp...');

    // NOTE: ProviderScope is intentionally NOT nested here.
    // The root ProviderScope lives in main.dart and is the single source of
    // truth for all Riverpod providers. Adding another scope here would create
    // a child container that shadows providers in the parent, causing
    // inconsistent provider state between the auth gate and the app.
    return MaterialApp(
        title: 'Mix & Mingle',
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: NeonTheme.darkTheme,
        // Use the app routing system
        onGenerateRoute: AppRoutes.generateRoute,
        initialRoute: AppRoutes.splash,
        // Handle unknown routes
        onUnknownRoute: (settings) {
          debugPrint('âš ï¸ Unknown route: ${settings.name}');
          return MaterialPageRoute(
            builder: (ctx) => Scaffold(
              appBar: AppBar(title: const Text('Page Not Found')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Route not found',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.of(ctx).pushNamedAndRemoveUntil(
                        AppRoutes.splash,
                        (route) => false,
                      ),
                      child: const Text('Go to Home'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
  }
}

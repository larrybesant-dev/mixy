import 'package:flutter/material.dart';
import 'package:mixvy/core/providers/connectivity_provider.dart';

/// Displays a banner when the app is offline
/// Automatically shows/hides based on connectivity state
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: connectivityNotifier.state,
      builder: (context, connectivityState, child) {
        if (connectivityState.isOnline) {
          return const SizedBox.shrink();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Material(
            color: Colors.red.shade800,
            elevation: 4,
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_off,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'No Internet Connection',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (connectivityState.errorMessage != null)
                            Text(
                              connectivityState.errorMessage!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        connectivityNotifier.reportOnline();
                      },
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Wrapper widget that adds offline banner to any screen
class OfflineAwareScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  const OfflineAwareScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.drawer,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          const OfflineBanner(),
          if (body != null) Expanded(child: body!),
        ],
      ),
    );
  }
}


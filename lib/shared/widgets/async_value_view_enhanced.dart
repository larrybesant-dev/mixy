import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mixvy/core/errors/app_error.dart';
import 'package:mixvy/core/providers/connectivity_provider.dart';
import 'package:mixvy/services/analytics/analytics_tracking.dart';
import 'package:mixvy/shared/providers/providers.dart';
import 'loading_widgets.dart';

/// Enhanced AsyncValue view with skeleton loaders, retry intelligence, and built-in P2F analytics
class AsyncValueViewEnhanced<T> extends ConsumerStatefulWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? skeleton;
  final VoidCallback? onRetry;
  final int? maxRetries;
  final bool enableBackoff;
  final Duration? backoffDuration;
  final String? emptyMessage;
  // P2F Analytics params
  final String? screenName;
  final String? providerName;
  final bool trackAnalytics;

  const AsyncValueViewEnhanced({
    super.key,
    required this.value,
    required this.data,
    this.skeleton,
    this.onRetry,
    this.maxRetries = 3,
    this.enableBackoff = false,
    this.backoffDuration,
    this.emptyMessage,
    this.screenName,
    this.providerName,
    this.trackAnalytics = true,
  });

  @override
  ConsumerState<AsyncValueViewEnhanced<T>> createState() =>
      _AsyncValueViewEnhancedState<T>();
}

class _AsyncValueViewEnhancedState<T>
    extends ConsumerState<AsyncValueViewEnhanced<T>> {
  int _retryCount = 0;
  DateTime? _lastRetryTime;
  bool _isRetrying = false;
  SkeletonTracker? _skeletonTracker;

  @override
  void initState() {
    super.initState();

    // Initialize skeleton tracker if both screenName and skeleton are present
    if (widget.trackAnalytics &&
        widget.screenName != null &&
        widget.skeleton != null) {
      final analytics = ref.read(analyticsServiceProvider);
      _skeletonTracker = SkeletonTracker(
        analytics: analytics,
        screenName: widget.screenName!,
        skeletonType: widget.skeleton.runtimeType.toString(),
      );
    }
  }

  @override
  void didUpdateWidget(AsyncValueViewEnhanced<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset retry count when new data arrives
    if (oldWidget.value.isLoading && widget.value.hasValue) {
      _retryCount = 0;
      _lastRetryTime = null;

      // Track successful load with analytics
      if (widget.trackAnalytics &&
          widget.screenName != null &&
          widget.providerName != null) {
        final analytics = ref.read(analyticsServiceProvider);
        analytics.trackAsyncValueLoad(
          widget.providerName!,
          'success',
        );

        // Record skeleton duration if tracker exists
        _skeletonTracker?.recordDataArrival();
      }
    }
  }

  Future<void> _handleRetry() async {
    if (widget.maxRetries != null && _retryCount >= widget.maxRetries!) {
      // Track max retries reached
      if (widget.trackAnalytics &&
          widget.screenName != null &&
          widget.providerName != null) {
        final analytics = ref.read(analyticsServiceProvider);
        analytics.trackErrorUnderLoad(
          screenName: widget.screenName!,
          errorType: 'max_retries_reached',
          errorMessage: 'Maximum retry attempts (${widget.maxRetries}) reached',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Maximum retry attempts reached. Please try again later.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Exponential backoff if enabled
    if (widget.enableBackoff && _lastRetryTime != null) {
      final elapsed = DateTime.now().difference(_lastRetryTime!);
      final backoffDuration = widget.backoffDuration ??
          Duration(seconds: 1 << _retryCount.clamp(0, 3));

      if (elapsed < backoffDuration) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please wait before retrying... (${(backoffDuration.inSeconds - elapsed.inSeconds)}s)',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
        return;
      }
    }

    setState(() {
      _retryCount++;
      _lastRetryTime = DateTime.now();
      _isRetrying = true;
    });

    // Track retry attempt with analytics
    if (widget.trackAnalytics &&
        widget.screenName != null &&
        widget.providerName != null) {
      final analytics = ref.read(analyticsServiceProvider);
      final backoffMs = widget.backoffDuration?.inMilliseconds ??
          (1000 << (_retryCount - 1).clamp(0, 3));

      analytics.trackRetryAttempt(
        screenName: widget.screenName!,
        providerName: widget.providerName!,
        retryCount: _retryCount,
        backoffMs: backoffMs,
      );
    }

    widget.onRetry?.call();

    // Stop showing retry indicator after 500ms
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.value.when(
      data: (d) {
        // Report online when data loads successfully
        connectivityNotifier.reportOnline();
        return widget.data(d);
      },
      loading: () =>
          widget.skeleton ??
          const Center(
            child: LoadingSpinner(),
          ),
      error: (err, stack) {
        final appErr = AppError.from(err);

        // Track error with analytics
        if (widget.trackAnalytics &&
            widget.screenName != null &&
            widget.providerName != null) {
          final analytics = ref.read(analyticsServiceProvider);

          analytics.trackAsyncValueLoad(
            widget.providerName!,
            'error',
            error: appErr.message,
          );

          analytics.trackErrorUnderLoad(
            screenName: widget.screenName!,
            errorType: runtimeType.toString(),
            errorMessage: appErr.message,
          );
        }

        // Report offline if network error
        if (ConnectivityNotifier.isNetworkError(err)) {
          connectivityNotifier.reportOffline(appErr.message);
        }

        // Show error view with retry intelligence
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  appErr.message,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                // Retry counter (if max retries set)
                if (widget.maxRetries != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Retry attempts: $_retryCount/${widget.maxRetries}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ),
                if (widget.onRetry != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isRetrying ? null : _handleRetry,
                    icon: _isRetrying
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(
                      _isRetrying ? 'Retrying...' : 'Retry',
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Simpler version: original AsyncValueView for backwards compatibility
class AsyncValueView<T> extends ConsumerWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return value.when(
      data: (d) {
        connectivityNotifier.reportOnline();
        return data(d);
      },
      loading: () => const Center(child: LoadingSpinner()),
      error: (err, stack) {
        final appErr = AppError.from(err);

        if (ConnectivityNotifier.isNetworkError(err)) {
          connectivityNotifier.reportOffline(appErr.message);
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  appErr.message,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}


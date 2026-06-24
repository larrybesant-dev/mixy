import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mixvy/core/errors/app_error.dart';
import 'package:mixvy/core/providers/connectivity_provider.dart';
import 'loading_widgets.dart';

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
        // Report online when data loads successfully
        connectivityNotifier.reportOnline();
        return data(d);
      },
      loading: () => const Center(child: LoadingSpinner()),
      error: (err, stack) {
        final appErr = AppError.from(err);

        // Report offline if network error
        if (ConnectivityNotifier.isNetworkError(err)) {
          connectivityNotifier.reportOffline(appErr.message);
        }

        // Show error view
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


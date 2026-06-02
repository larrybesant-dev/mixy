import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firestore/firestore_error_utils.dart';
import '../../core/layout/app_layout.dart';

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          if (label != null) ...[
            SizedBox(height: context.sectionSpacing),
            Text(label!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: context.pagePadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: theme.colorScheme.primary),
              SizedBox(height: context.sectionSpacing),
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                SizedBox(height: context.sectionSpacing),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.error,
    required this.fallbackContext,
    this.onRetry,
  });

  final Object error;
  final String fallbackContext;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = parseFirestoreError(error);
    return Center(
      child: Padding(
        padding: context.pagePadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 52,
                color: theme.colorScheme.error,
              ),
              SizedBox(height: context.sectionSpacing),
              Text(
                friendlyFirestoreMessage(
                  error,
                  fallbackContext: fallbackContext,
                ),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text(
                  '[${info.code}] ${info.message}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (onRetry != null) ...[
                SizedBox(height: context.sectionSpacing),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppAsyncValueView<T> extends StatelessWidget {
  const AppAsyncValueView({
    super.key,
    required this.value,
    required this.data,
    required this.fallbackContext,
    this.isEmpty,
    this.empty,
    this.loadingLabel,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final bool Function(T value)? isEmpty;
  final Widget? empty;
  final String fallbackContext;
  final String? loadingLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (resolved) {
        if (isEmpty != null && isEmpty!(resolved)) {
          return empty ?? const SizedBox.shrink();
        }
        return data(resolved);
      },
      loading: () => AppLoadingView(label: loadingLabel),
      error: (error, _) => AppErrorView(
        error: error,
        fallbackContext: fallbackContext,
        onRetry: onRetry,
      ),
    );
  }
}

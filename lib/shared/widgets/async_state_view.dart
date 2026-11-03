import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firestore/firestore_error_utils.dart';
import '../../core/layout/app_layout.dart';
import '../../core/telemetry/app_telemetry.dart';

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = constraints.biggest.shortestSide;
        final compact = shortestSide.isFinite && shortestSide < 48;
        final indicatorSize =
            compact ? shortestSide.clamp(16.0, 28.0).toDouble() : 36.0;

        final child = compact && label == null
            ? SizedBox(
                width: indicatorSize,
                height: indicatorSize,
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                  strokeWidth: 2.2,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: indicatorSize,
                    height: indicatorSize,
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (label != null) ...[
                    SizedBox(height: context.sectionSpacing),
                    Text(label!, style: theme.textTheme.bodyMedium),
                  ],
                ],
              );

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: child,
          ),
        );
      },
    );
  }
}

class AppBoundedLoadingView extends StatefulWidget {
  const AppBoundedLoadingView({
    super.key,
    required this.fallbackContext,
    this.label,
    this.onRetry,
    this.timeout = const Duration(seconds: 12),
  });

  final String fallbackContext;
  final String? label;
  final VoidCallback? onRetry;
  final Duration timeout;

  @override
  State<AppBoundedLoadingView> createState() => _AppBoundedLoadingViewState();
}

class _AppBoundedLoadingViewState extends State<AppBoundedLoadingView> {
  Timer? _timer;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant AppBoundedLoadingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fallbackContext != widget.fallbackContext ||
        oldWidget.timeout != widget.timeout) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timedOut = false;
    _timer = Timer(widget.timeout, () {
      if (!mounted) return;
      setState(() => _timedOut = true);
      AppTelemetry.logAction(
        level: 'warn',
        domain: 'loading',
        action: 'loading_timeout',
        message: 'A loading state exceeded its time limit.',
        result: 'timeout',
        metadata: <String, Object?>{
          'context': widget.fallbackContext,
          'timeout_ms': widget.timeout.inMilliseconds,
        },
      );
    });
  }

  void _retry() {
    _startTimer();
    setState(() {});
    widget.onRetry?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_timedOut) {
      return AppLoadingView(label: widget.label);
    }

    return AppEmptyView(
      icon: Icons.cloud_off_outlined,
      title: 'Taking longer than expected',
      message:
          'MixVy could not finish loading ${widget.fallbackContext}. Check your connection and try again.',
      action: widget.onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
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
      child: SingleChildScrollView(
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
      loading: () => AppBoundedLoadingView(
        fallbackContext: fallbackContext,
        label: loadingLabel,
        onRetry: onRetry,
      ),
      error: (error, _) => AppErrorView(
        error: error,
        fallbackContext: fallbackContext,
        onRetry: onRetry,
      ),
    );
  }
}

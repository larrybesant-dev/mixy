import 'dart:async';

import 'package:flutter/foundation.dart';

/// Reference: docs/governance/async-query-controller-no-regression-guide.md
///
/// Base controller for feature-local async query flows.
class AsyncSearchController {
  AsyncSearchController({
    required this.minChars,
    required this.debounceDuration,
  });

  final int minChars;
  final Duration debounceDuration;

  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _debounce = null;
    _requestId++;
  }

  void search<T>({
    required String query,
    required Future<List<T>> Function(String query) fetch,
    required VoidCallback onThresholdNotMet,
    required VoidCallback onSearchStart,
    required void Function(List<T> results) onSearchSuccess,
    required void Function(Object error) onSearchError,
  }) {
    if (_disposed) {
      return;
    }

    _debounce?.cancel();
    final normalized = query.trim();
    if (normalized.length < minChars) {
      _requestId++;
      onThresholdNotMet();
      return;
    }

    _debounce = Timer(debounceDuration, () async {
      final requestId = ++_requestId;
      onSearchStart();

      try {
        final results = await fetch(normalized);
        if (_disposed || requestId != _requestId) {
          return;
        }
        onSearchSuccess(results);
      } catch (error) {
        if (_disposed || requestId != _requestId) {
          return;
        }
        onSearchError(error);
      }
    });
  }
}




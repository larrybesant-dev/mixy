import 'package:flutter/foundation.dart';

import '../../../shared/controllers/async_search_controller.dart';

typedef MessagingSearchFetcher<T> = Future<List<T>> Function(String query);
typedef MessagingSearchResultHandler<T> = void Function(List<T> results);
typedef MessagingSearchErrorHandler = void Function(Object error);

class MessagingSearchController extends AsyncSearchController {
  MessagingSearchController({
    super.minChars = 3,
    super.debounceDuration = const Duration(milliseconds: 300),
  });

  @override
  void search<T>({
    required String query,
    required MessagingSearchFetcher<T> fetch,
    required VoidCallback onThresholdNotMet,
    required VoidCallback onSearchStart,
    required MessagingSearchResultHandler<T> onSearchSuccess,
    required MessagingSearchErrorHandler onSearchError,
  }) {
    super.search<T>(
      query: query,
      fetch: fetch,
      onThresholdNotMet: onThresholdNotMet,
      onSearchStart: onSearchStart,
      onSearchSuccess: onSearchSuccess,
      onSearchError: onSearchError,
    );
  }
}

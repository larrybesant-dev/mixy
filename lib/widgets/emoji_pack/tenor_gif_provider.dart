import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/tenor_service.dart';

/// Fetches and caches one GIF URL per [query] string.
///
/// Usage:
/// ```dart
/// final gifAsync = ref.watch(tenorGifProvider('laugh cry emoji funny'));
/// ```
final tenorGifProvider = FutureProvider.family<String?, String>((
  ref,
  query,
) async {
  return GifService.fetchGifUrl(query);
});

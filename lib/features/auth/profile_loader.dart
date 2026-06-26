import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder provider for future profile loading integration.
/// Profile loading will be triggered manually when needed via
/// profileControllerProvider.notifier.loadCurrentProfile() calls.
/// This avoids Riverpod provider dependency cycle issues.
final profileLoaderProvider = FutureProvider<void>((ref) async {
  return Future.value();
});



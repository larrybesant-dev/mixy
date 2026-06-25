import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/presence_service.dart';

/// Cache the PresenceService as a singleton to prevent creating new instances
final presenceServiceProvider = Provider<PresenceService>((ref) {
  return PresenceService();
});

/// Stream user presence via cached service
final presenceProvider = StreamProvider.family<bool, String>((ref, userId) {
  final presenceService = ref.watch(presenceServiceProvider);
  return presenceService.streamPresence(userId);
});

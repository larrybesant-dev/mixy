import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/services/messaging_service.dart';
import 'package:mixmingle/services/events/speed_dating_service.dart';

// ── Messaging Service Provider ────────────────────────────────────────────────

final messagingServiceProvider = Provider<MessagingService>((ref) {
  return MessagingService();
});

// ── Speed Dating Service Provider ─────────────────────────────────────────────

final speedDatingServiceProvider = Provider<SpeedDatingService>((ref) {
  return SpeedDatingService();
});

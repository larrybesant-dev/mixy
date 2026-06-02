import 'dart:async';
import 'production_alerts.dart';

class AlertScheduler {
  static Timer? _timer;

  static void start() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      ProductionAlertSystem.runHealthCheck();
    });
  }

  static void stop() {
    _timer?.cancel();
  }
}

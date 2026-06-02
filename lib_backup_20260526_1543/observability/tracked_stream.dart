import 'dart:async';
import 'runtime_telemetry.dart';

class TrackedStream<T> {
  final String key;
  final Stream<T> stream;

  StreamSubscription<T>? _sub;

  TrackedStream(this.key, this.stream);

  Stream<T> start(void Function(T event) onData) {
    RuntimeTelemetry.registerListener(key);

    _sub = stream.listen((event) {
      onData(event);
    });

    return stream;
  }

  void dispose() {
    RuntimeTelemetry.unregisterListener(key);
    _sub?.cancel();
  }
}

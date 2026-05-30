import 'dart:async';

class SystemEvent {
  const SystemEvent({required this.type, required this.timestamp, this.meta});

  final String type;
  final DateTime timestamp;
  final Map<String, dynamic>? meta;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'meta': meta,
    };
  }
}

class SystemEventBus {
  SystemEventBus._();

  static final SystemEventBus instance = SystemEventBus._();

  final StreamController<SystemEvent> _controller =
      StreamController<SystemEvent>.broadcast();
  final List<SystemEvent> _events = <SystemEvent>[];

  Stream<SystemEvent> get stream => _controller.stream;

  List<SystemEvent> snapshot() => List<SystemEvent>.unmodifiable(_events);

  void clear() {
    _events.clear();
  }

  void emit(SystemEvent event) {
    _events.add(event);
    _controller.add(event);
  }

  void emitNow(String type, {Map<String, dynamic>? meta}) {
    emit(SystemEvent(type: type, timestamp: DateTime.now(), meta: meta));
  }
}




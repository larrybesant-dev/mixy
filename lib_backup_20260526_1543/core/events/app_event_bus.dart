import 'dart:async';

import 'app_event.dart';
import 'event_inspector.dart';

class AppEventBus {
  AppEventBus._internal()
      : _controller = StreamController<AppEvent>.broadcast();

  AppEventBus._test() : _controller = StreamController<AppEvent>.broadcast();

  static final AppEventBus instance = AppEventBus._internal();

  final StreamController<AppEvent> _controller;

  Stream<AppEvent> get stream => _controller.stream;

  void emit(AppEvent event, {bool isReplay = false}) {
    if (_controller.isClosed) {
      return;
    }
    AppEventInspector.instance.recordEmission(event, isReplay: isReplay);
    _controller.add(event);
  }

  static AppEventBus testInstance() => AppEventBus._test();

  Future<void> dispose() async {
    if (identical(this, instance)) {
      return;
    }
    await _controller.close();
  }
}

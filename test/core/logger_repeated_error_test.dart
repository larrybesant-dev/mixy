import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/logger.dart';

void main() {
  group('Logger repeated-error escalation', () {
    tearDown(() {
      Logger.resetForTests();
    });

    test('escalates once when the same error repeats five times in window', () {
      for (var i = 0; i < 5; i += 1) {
        Logger.error('Room stream failure', error: StateError('stream closed'));
      }

      expect(Logger.escalationCountForTests, 1);
    });

    test('does not escalate repeatedly for the same burst window', () {
      for (var i = 0; i < 8; i += 1) {
        Logger.error('Room stream failure', error: StateError('stream closed'));
      }

      expect(Logger.escalationCountForTests, 1);
    });
  });
}

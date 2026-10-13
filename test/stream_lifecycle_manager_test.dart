import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/streams/stream_lifecycle_manager.dart';

void main() {
  test('bind replays the latest value to a late subscriber', () async {
    final manager = StreamLifecycleManager();
    final source = StreamController<List<int>>();
    final stream = manager.bind<List<int>>(
      key: 'friends',
      create: () => source.stream,
      routePrefixes: const <String>['*'],
    );
    final firstValues = <List<int>>[];
    final firstSubscription = stream.listen(firstValues.add);

    source.add(const <int>[]);
    await Future<void>.delayed(Duration.zero);

    expect(firstValues, <List<int>>[const <int>[]]);
    await expectLater(
      stream.first.timeout(const Duration(seconds: 1)),
      completion(const <int>[]),
    );

    await firstSubscription.cancel();
    await source.close();
    manager.dispose();
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android launcher activity matches the application namespace', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final namespace = RegExp(
      r'namespace\s*=\s*"([^"]+)"',
    ).firstMatch(gradle)?.group(1);

    expect(namespace, isNotNull);

    final activityPath =
        'android/app/src/main/kotlin/${namespace!.replaceAll('.', '/')}/MainActivity.kt';
    final activity = File(activityPath);

    expect(activity.existsSync(), isTrue, reason: 'Missing $activityPath');
    expect(activity.readAsStringSync(), contains('package $namespace'));
  });
}
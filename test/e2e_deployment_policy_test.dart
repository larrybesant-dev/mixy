import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only unmarked main and develop pushes can deploy', () {
    final workflow = File('.github/workflows/e2e-tests.yml').readAsStringSync();
    final deployStart =
        RegExp(r'^  deploy:[ \t]*\r?$', multiLine: true).firstMatch(workflow);
    expect(deployStart, isNotNull);

    final remaining = workflow.substring(deployStart!.end);
    final nextJob = RegExp(r'^  [a-zA-Z0-9_-]+:[ \t]*\r?$', multiLine: true)
        .firstMatch(remaining);
    final deployJob =
        nextJob == null ? remaining : remaining.substring(0, nextJob.start);
    final condition = RegExp(
      r'^    if: \|\r?\n((?: {6}[^\r\n]*\r?\n)+)',
      multiLine: true,
    ).firstMatch(deployJob);
    expect(condition, isNotNull);
    expect(
      condition!.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim(),
      "success() && github.event_name == 'push' && "
      "!contains(github.event.head_commit.message, '[skip deploy]') && "
      "(github.ref == 'refs/heads/main' || "
      "github.ref == 'refs/heads/develop')",
    );
    expect(
      RegExp(r'^  schedule:[ \t]*\r?$', multiLine: true).hasMatch(workflow),
      isTrue,
    );
  });
}

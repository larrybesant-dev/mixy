import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _jobBody(String workflow, String jobName) {
  final jobStart = RegExp(
    '^  ${RegExp.escape(jobName)}:' r'[ \t]*\r?$',
    multiLine: true,
  ).firstMatch(workflow);
  expect(jobStart, isNotNull, reason: jobName);

  final remaining = workflow.substring(jobStart!.end);
  final nextJob = RegExp(r'^  [a-zA-Z0-9_-]+:[ \t]*\r?$', multiLine: true)
      .firstMatch(remaining);
  return nextJob == null ? remaining : remaining.substring(0, nextJob.start);
}

String _jobCondition(String job) {
  final condition = RegExp(
    r'^    if: \|\r?\n((?: {6}[^\r\n]*\r?\n)+)',
    multiLine: true,
  ).firstMatch(job);
  expect(condition, isNotNull);
  return condition!.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
}

void main() {
  test('only unmarked main and develop pushes can deploy', () {
    final workflow = File('.github/workflows/e2e-tests.yml').readAsStringSync();
    expect(
      _jobCondition(_jobBody(workflow, 'deploy')),
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

  test('production deploy uses the validated main revision', () {
    final workflow = File('.github/workflows/deploy_firebase_hosting.yaml')
        .readAsStringSync();
    final productionJob = _jobBody(workflow, 'build_and_deploy_production');
    expect(
      _jobCondition(productionJob),
      "(github.event_name == 'workflow_dispatch' && inputs.target == 'production') || "
      "(github.event_name == 'workflow_run' && "
      "github.event.workflow_run.conclusion == 'success' && "
      "github.event.workflow_run.head_branch == 'main' && "
      "(github.event.workflow_run.event == 'push' || "
      "github.event.workflow_run.event == 'workflow_dispatch'))",
    );

    final validationStart =
        productionJob.indexOf('name: Require validated revision');
    final checkoutStart = productionJob.indexOf('name: Checkout Code');
    expect(validationStart, greaterThanOrEqualTo(0));
    expect(checkoutStart, greaterThan(validationStart));
    final validationStep =
        productionJob.substring(validationStart, checkoutStart);
    expect(
      validationStep,
      contains(r'VALIDATED_SHA: ${{ github.event.workflow_run.head_sha }}'),
    );
    expect(
      validationStep,
      contains(r'if [[ ! "$VALIDATED_SHA" =~ ^[0-9a-f]{40}$ ]]; then'),
    );
    expect(validationStep, contains('exit 1'));
    expect(
      productionJob,
      contains(
        r"ref: ${{ github.event_name == 'workflow_run' && "
        r"github.event.workflow_run.head_sha || github.sha }}",
      ),
    );
  });
}

import 'startup_pipeline_models.dart';

class StartupRunSchemaValidator {
  const StartupRunSchemaValidator();

  List<String> validateEntries(List<Map<String, Object?>> entries) {
    final List<String> failures = <String>[];

    for (int i = 0; i < entries.length; i++) {
      final Map<String, Object?> entry = entries[i];
      final int row = i + 1;

      final Object? timestamp = entry['timestamp'];
      if (timestamp is! num) {
        failures.add(
          'history schema error row $row: missing numeric timestamp',
        );
      }

      final Object? commit = entry['commit'];
      if (commit is! String || commit.isEmpty) {
        failures.add('history schema error row $row: missing commit');
      }

      final Object? pipelineVersion = entry['pipeline_version'];
      if (pipelineVersion is! String ||
          pipelineVersion != startupPipelineVersion) {
        failures.add(
          'history schema error row $row: pipeline_version must be $startupPipelineVersion',
        );
      }

      final Object? decision = entry['decision'];
      if (decision is! String ||
          (decision != 'PASS' && decision != 'WARN' && decision != 'FAIL')) {
        failures.add('history schema error row $row: invalid decision');
      }

      final Object? metricsRaw = entry['metrics'];
      if (metricsRaw is! Map<String, Object?>) {
        failures.add('history schema error row $row: missing metrics object');
        continue;
      }

      for (final StartupCheckpoint checkpoint in gateCheckpoints) {
        final Object? value = metricsRaw[checkpoint.name];
        if (value is! num) {
          failures.add(
            'history schema error row $row: missing metric ${checkpoint.name}',
          );
        }
      }
    }

    return failures;
  }
}

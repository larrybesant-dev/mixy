import 'dart:convert';
import 'dart:math';

import 'startup_pipeline_models.dart';

class StartupMetricEngine {
  const StartupMetricEngine();

  static final RegExp _lineRegex = RegExp(
    r'\+(\d+)ms\s+startup\.([a-zA-Z]+)\b',
  );

  ParseResult parseRuns(String input) {
    final List<String> failures = <String>[];
    final List<RunSample> runs = <RunSample>[];

    final List<String> lines = const LineSplitter().convert(input);
    RunSample? current;
    int runCounter = 0;

    for (final String line in lines) {
      if (!line.contains('startup.')) {
        continue;
      }

      final Match? match = _lineRegex.firstMatch(line);
      if (match == null) {
        failures.add('malformed log data: $line');
        continue;
      }

      final String rawDelta = match.group(1)!;
      final int? delta = int.tryParse(rawDelta);
      if (delta == null) {
        failures.add('non-numeric delta: $line');
        continue;
      }

      final String checkpointName = match.group(2)!;
      final StartupCheckpoint? checkpoint = startupCheckpointFromName(
        checkpointName,
      );
      if (checkpoint == null) {
        failures.add(
          'malformed log data: unknown checkpoint startup.$checkpointName',
        );
        continue;
      }

      if (checkpoint == StartupCheckpoint.mainStart) {
        if (current != null && current.values.isNotEmpty) {
          runs.add(current);
        }
        runCounter += 1;
        current = RunSample(runCounter);
      }

      if (current == null) {
        failures.add(
          'malformed log data: checkpoint startup.${checkpoint.name} before startup.mainStart',
        );
        continue;
      }

      if (current.values.containsKey(checkpoint)) {
        failures.add(
          'malformed log data: duplicate checkpoint startup.${checkpoint.name} in run ${current.id}',
        );
        continue;
      }

      current.values[checkpoint] = delta;
    }

    if (current != null && current.values.isNotEmpty) {
      runs.add(current);
    }

    if (runs.isEmpty) {
      failures.add('missing checkpoint data: no startup runs found');
    }

    for (final RunSample run in runs) {
      for (final StartupCheckpoint checkpoint in requiredCheckpoints) {
        if (!run.values.containsKey(checkpoint)) {
          failures.add(
            'missing checkpoint: startup.${checkpoint.name} in run ${run.id}',
          );
        }
      }
    }

    return ParseResult(runs: runs, failures: failures);
  }

  Map<StartupCheckpoint, CheckpointStats> computeStats(List<RunSample> runs) {
    final Map<StartupCheckpoint, CheckpointStats> result =
        <StartupCheckpoint, CheckpointStats>{};

    for (final StartupCheckpoint checkpoint in StartupCheckpoint.values) {
      final List<int> values = runs
          .map((RunSample run) => run.values[checkpoint])
          .whereType<int>()
          .toList();

      if (values.isEmpty) continue;
      values.sort();
      result[checkpoint] = CheckpointStats(
        p50: _nearestRank(values, 0.50),
        p95: _nearestRank(values, 0.95),
        worst: values.last,
      );
    }

    return result;
  }

  int _nearestRank(List<int> sorted, double percentile) {
    if (sorted.isEmpty) return 0;
    final int rank = max(1, (percentile * sorted.length).ceil());
    final int index = min(sorted.length - 1, rank - 1);
    return sorted[index];
  }
}

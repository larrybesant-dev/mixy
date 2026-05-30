import 'dart:convert';
import 'dart:io';

import 'run_history_store.dart';
import 'startup_baseline_engine.dart';
import 'startup_pipeline_models.dart';
import 'startup_run_schema_validator.dart';
import 'startup_scoring_engine.dart';
import 'startup_trend_engine.dart';

class ArgConfig {
  const ArgConfig({
    required this.inputPath,
    required this.slaPath,
    required this.weightsPath,
    required this.policyPath,
    required this.historyPath,
    required this.historyWindow,
    required this.historyWrite,
    required this.jsonOutput,
    required this.showHelp,
  });

  final String? inputPath;
  final String slaPath;
  final String weightsPath;
  final String policyPath;
  final String historyPath;
  final int historyWindow;
  final bool historyWrite;
  final bool jsonOutput;
  final bool showHelp;
}

Future<void> main(List<String> args) async {
  late final ArgConfig config;
  try {
    config = _parseArgs(args);
  } catch (error) {
    _fail('invalid arguments: $error');
    return;
  }

  if (config.showHelp) {
    _printUsage();
    exitCode = 0;
    return;
  }

  final String inputText;
  try {
    inputText = await _readInput(config.inputPath);
  } catch (error) {
    _fail('unable to read input: $error');
    return;
  }

  final Map<StartupCheckpoint, int> sla;
  try {
    sla = _loadSla(config.slaPath);
  } catch (error) {
    _fail('invalid SLA config: $error');
    return;
  }

  final WeightsConfig weights;
  try {
    weights = _loadWeights(config.weightsPath);
  } catch (error) {
    _fail('invalid weights config: $error');
    return;
  }

  final GatePolicyConfig policy;
  try {
    policy = _loadPolicy(config.policyPath);
  } catch (error) {
    _fail('invalid policy config: $error');
    return;
  }

  final RunHistoryStore historyStore = RunHistoryStore(config.historyPath);
  final List<Map<String, Object?>> historyEntries = await historyStore
      .loadEntries();

  final StartupRunSchemaValidator schemaValidator =
      const StartupRunSchemaValidator();
  final List<String> historySchemaFailures = schemaValidator.validateEntries(
    historyEntries,
  );
  if (historySchemaFailures.isNotEmpty) {
    _fail(historySchemaFailures.first);
    return;
  }

  final StartupBaselineEngine baselineEngine = const StartupBaselineEngine();
  final StartupTrendEngine trendEngine = const StartupTrendEngine();

  final Map<StartupCheckpoint, int> baseline = baselineEngine
      .computeFromHistory(
        entries: historyEntries,
        window: config.historyWindow,
      );
  final Map<StartupCheckpoint, int> lastGreen = baselineEngine.lastGreenMetrics(
    entries: historyEntries,
  );

  final TrendAnalysis trend = trendEngine.analyze(
    entries: historyEntries,
    window: config.historyWindow,
  );

  final StartupScoringEngine scoringEngine = StartupScoringEngine(
    sla: sla,
    weights: weights.weights,
    passThreshold: weights.passThreshold,
    warnThreshold: weights.warnThreshold,
  );

  final ParseResult parsed = scoringEngine.parseRuns(inputText);
  final ScoringResult scoring = scoringEngine.evaluate(
    parsed: parsed,
    baseline: baseline,
    trend: trend,
  );

  final Map<String, Object?> output = _buildOutput(
    scoring: scoring,
    policy: policy,
    trend: trend,
    baseline: baseline,
    lastGreen: lastGreen,
    sla: sla,
    runCount: parsed.runs.length,
  );

  if (config.historyWrite) {
    await historyStore.appendEntry(
      _buildHistoryEntry(
        scoring: scoring,
        trend: trend,
        runCount: parsed.runs.length,
      ),
    );
  }

  if (config.jsonOutput) {
    stdout.writeln(jsonEncode(output));
  } else {
    _printHuman(output);
  }

  final bool shouldFail =
      scoring.decision == GateDecision.fail ||
      (scoring.decision == GateDecision.warn && policy.blockOnWarn);
  exitCode = shouldFail ? 1 : 0;
}

ArgConfig _parseArgs(List<String> args) {
  String? inputPath;
  String slaPath = 'STARTUP_SLA.json';
  String weightsPath = 'STARTUP_WEIGHTS.json';
  String policyPath = 'STARTUP_GATE_POLICY.json';
  String historyPath = 'tools/run_history.jsonl';
  int historyWindow = 10;
  bool historyWrite = true;
  bool jsonOutput = false;
  bool showHelp = false;

  for (int i = 0; i < args.length; i++) {
    final String arg = args[i];
    switch (arg) {
      case '--input':
        if (i + 1 >= args.length) {
          throw ArgumentError('Missing value for --input');
        }
        inputPath = args[++i];
        break;
      case '--sla':
        if (i + 1 >= args.length) {
          throw ArgumentError('Missing value for --sla');
        }
        slaPath = args[++i];
        break;
      case '--weights':
        if (i + 1 >= args.length) {
          throw ArgumentError('Missing value for --weights');
        }
        weightsPath = args[++i];
        break;
      case '--policy':
        if (i + 1 >= args.length) {
          throw ArgumentError('Missing value for --policy');
        }
        policyPath = args[++i];
        break;
      case '--history':
        if (i + 1 >= args.length) {
          throw ArgumentError('Missing value for --history');
        }
        historyPath = args[++i];
        break;
      case '--history-window':
        if (i + 1 >= args.length) {
          throw ArgumentError('Missing value for --history-window');
        }
        historyWindow = int.parse(args[++i]);
        if (historyWindow <= 1) {
          throw ArgumentError('--history-window must be > 1');
        }
        break;
      case '--no-history-write':
        historyWrite = false;
        break;
      case '--json':
        jsonOutput = true;
        break;
      case '--help':
      case '-h':
        showHelp = true;
        break;
      default:
        if (arg.startsWith('--')) {
          throw ArgumentError('Unknown argument: $arg');
        }
        if (inputPath != null) {
          throw ArgumentError('Only one positional input path is supported');
        }
        inputPath = arg;
    }
  }

  return ArgConfig(
    inputPath: inputPath,
    slaPath: slaPath,
    weightsPath: weightsPath,
    policyPath: policyPath,
    historyPath: historyPath,
    historyWindow: historyWindow,
    historyWrite: historyWrite,
    jsonOutput: jsonOutput,
    showHelp: showHelp,
  );
}

Future<String> _readInput(String? inputPath) async {
  if (inputPath != null && inputPath.isNotEmpty) {
    return File(inputPath).readAsString();
  }
  if (stdin.hasTerminal) {
    throw StateError('No --input file provided and stdin is empty/interactive');
  }
  return stdin.transform(utf8.decoder).join();
}

Map<StartupCheckpoint, int> _loadSla(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    throw StateError('SLA file not found: $path');
  }

  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw FormatException('SLA file must be a JSON object');
  }

  final Object? version = decoded['pipeline_version'];
  if (version is! String || version != startupPipelineVersion) {
    throw FormatException(
      'SLA pipeline_version must be "$startupPipelineVersion"',
    );
  }

  final Map<StartupCheckpoint, int> result = <StartupCheckpoint, int>{};
  for (final StartupCheckpoint checkpoint in gateCheckpoints) {
    final Object? raw = decoded[checkpoint.name];
    if (raw is! num) {
      throw FormatException(
        'Missing numeric SLA for checkpoint: ${checkpoint.name}',
      );
    }
    final int value = raw.round();
    if (value <= 0) {
      throw FormatException('SLA value for ${checkpoint.name} must be > 0');
    }
    result[checkpoint] = value;
  }

  return result;
}

WeightsConfig _loadWeights(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    throw StateError('Weights file not found: $path');
  }

  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw FormatException('Weights file must be a JSON object');
  }

  final Object? version = decoded['pipeline_version'];
  if (version is! String || version != startupPipelineVersion) {
    throw FormatException(
      'Weights pipeline_version must be "$startupPipelineVersion"',
    );
  }

  final Map<StartupCheckpoint, double> weights = <StartupCheckpoint, double>{};
  for (final StartupCheckpoint checkpoint in gateCheckpoints) {
    final Object? raw = decoded[checkpoint.name];
    if (raw is! num) {
      throw FormatException(
        'Missing numeric weight for checkpoint: ${checkpoint.name}',
      );
    }
    weights[checkpoint] = raw.toDouble();
  }

  final double sum = weights.values.fold<double>(
    0,
    (double a, double b) => a + b,
  );
  if ((sum - 1.0).abs() > 0.001) {
    throw FormatException('Checkpoint weights must sum to 1.0');
  }

  final Object? passThresholdRaw = decoded['passThreshold'];
  final Object? warnThresholdRaw = decoded['warnThreshold'];
  if (passThresholdRaw is! num || warnThresholdRaw is! num) {
    throw FormatException('passThreshold and warnThreshold must be numeric');
  }

  final double passThreshold = passThresholdRaw.toDouble();
  final double warnThreshold = warnThresholdRaw.toDouble();
  if (!(passThreshold > 0 && warnThreshold > passThreshold)) {
    throw FormatException(
      'Expected thresholds: 0 < passThreshold < warnThreshold',
    );
  }

  return WeightsConfig(
    weights: weights,
    passThreshold: passThreshold,
    warnThreshold: warnThreshold,
  );
}

GatePolicyConfig _loadPolicy(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    throw StateError('Policy file not found: $path');
  }

  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw FormatException('Policy file must be a JSON object');
  }

  final Object? version = decoded['pipeline_version'];
  if (version is! String || version != startupPipelineVersion) {
    throw FormatException(
      'Policy pipeline_version must be "$startupPipelineVersion"',
    );
  }

  final Object? blockOnWarn = decoded['blockOnWarn'];
  if (blockOnWarn is! bool) {
    throw FormatException('Policy blockOnWarn must be boolean');
  }

  final Object? policyMode = decoded['policyMode'];
  if (policyMode is! String || policyMode.isEmpty) {
    throw FormatException('Policy policyMode must be non-empty string');
  }

  return GatePolicyConfig(
    pipelineVersion: version,
    blockOnWarn: blockOnWarn,
    policyMode: policyMode,
  );
}

Map<String, Object?> _buildOutput({
  required ScoringResult scoring,
  required GatePolicyConfig policy,
  required TrendAnalysis trend,
  required Map<StartupCheckpoint, int> baseline,
  required Map<StartupCheckpoint, int> lastGreen,
  required Map<StartupCheckpoint, int> sla,
  required int runCount,
}) {
  final Map<String, Object?> checkpointOutput = <String, Object?>{};

  scoring.statsByCheckpoint.forEach((
    StartupCheckpoint cp,
    CheckpointStats stats,
  ) {
    checkpointOutput[cp.name] = <String, Object?>{
      'p50Ms': stats.p50,
      'p95Ms': stats.p95,
      'worstMs': stats.worst,
      'slaMs': sla[cp],
      'p95CeilingMs': sla[cp] == null ? null : (sla[cp]! * 1.2).ceil(),
      'baselineP95Ms': baseline[cp],
      'baselineP95CeilingMs': baseline[cp] == null
          ? null
          : (baseline[cp]! * 1.2).ceil(),
      'lastGreenP95Ms': lastGreen[cp],
      'regressionDiffVsLastGreenMs': lastGreen[cp] == null
          ? null
          : (stats.p95 - lastGreen[cp]!),
    };
  });

  return <String, Object?>{
    'gate': scoring.decision.name.toUpperCase(),
    'pipeline_version': startupPipelineVersion,
    'policy': <String, Object?>{
      'policyMode': policy.policyMode,
      'blockOnWarn': policy.blockOnWarn,
      'pipelineVersion': policy.pipelineVersion,
    },
    'pass': scoring.decision != GateDecision.fail,
    'runCount': runCount,
    'score': scoring.score,
    'trend': <String, Object?>{
      'status': trend.status.name,
      'slopePct': trend.slopePct,
      'driftPct': trend.driftPct,
      'variance': trend.variance,
      'sampleCount': trend.sampleCount,
    },
    'failures': scoring.failures,
    'explainability': <String, Object?>{
      'violation_count': scoring.violations.length,
      'violations': scoring.violations
          .map((PolicyViolation violation) => violation.toJson())
          .toList(),
    },
    'startup': <String, Object?>{
      'p50Ms': scoring.startupStats.p50,
      'p95Ms': scoring.startupStats.p95,
      'worstMs': scoring.startupStats.worst,
    },
    'checkpoints': checkpointOutput,
  };
}

Map<String, Object?> _buildHistoryEntry({
  required ScoringResult scoring,
  required TrendAnalysis trend,
  required int runCount,
}) {
  final String commit =
      Platform.environment['GITHUB_SHA'] ??
      Platform.environment['CI_COMMIT_SHA'] ??
      Platform.environment['BUILD_SOURCEVERSION'] ??
      'unknown';
  final String runId =
      Platform.environment['GITHUB_RUN_ID'] ??
      Platform.environment['CI_PIPELINE_ID'] ??
      Platform.environment['BUILD_BUILDID'] ??
      DateTime.now().millisecondsSinceEpoch.toString();

  final Map<String, Object?> metrics = <String, Object?>{};
  for (final StartupCheckpoint cp in gateCheckpoints) {
    final CheckpointStats? stats = scoring.statsByCheckpoint[cp];
    if (stats == null) continue;
    metrics[cp.name] = stats.p95;
  }

  return <String, Object?>{
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'commit': commit,
    'run_id': runId,
    'pipeline_version': startupPipelineVersion,
    'decision': scoring.decision.name.toUpperCase(),
    'score': scoring.score,
    'runCount': runCount,
    'trend': trend.status.name,
    'metrics': metrics,
  };
}

void _printHuman(Map<String, Object?> output) {
  stdout.writeln('STARTUP GATE: ${output['gate']}');

  final Object? checkpointsRaw = output['checkpoints'];
  if (checkpointsRaw is Map<String, Object?>) {
    for (final StartupCheckpoint cp in gateCheckpoints) {
      final Object? entryRaw = checkpointsRaw[cp.name];
      if (entryRaw is! Map<String, Object?>) continue;
      stdout.writeln('');
      stdout.writeln('${cp.name}:');
      stdout.writeln('- p50: ${entryRaw['p50Ms']}ms');
      stdout.writeln('- p95: ${entryRaw['p95Ms']}ms');
      stdout.writeln('- worst: ${entryRaw['worstMs']}ms');
    }
  }

  final Object? trendRaw = output['trend'];
  if (trendRaw is Map<String, Object?>) {
    stdout.writeln('');
    stdout.writeln(
      '- trend: ${trendRaw['status']} (slope ${((((trendRaw['slopePct'] as num?) ?? 0) * 100)).toStringAsFixed(2)}%)',
    );
  }

  final Object? failuresRaw = output['failures'];
  if (failuresRaw is List && failuresRaw.isNotEmpty) {
    stdout.writeln('');
    for (final Object failure in failuresRaw) {
      stdout.writeln('- $failure');
    }
    if (output['gate'] == 'FAIL') {
      stdout.writeln('');
      stdout.writeln('RELEASE BLOCKED');
    }
  }
}

void _printUsage() {
  stdout.writeln(
    'Usage: dart run tools/startup_gate_validator.dart [logs.txt] [options]',
  );
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln(
    '  --input <path>        Read logs from file path (default: positional path or stdin)',
  );
  stdout.writeln(
    '  --sla <path>          SLA config JSON path (default: STARTUP_SLA.json)',
  );
  stdout.writeln(
    '  --weights <path>      Weights config JSON path (default: STARTUP_WEIGHTS.json)',
  );
  stdout.writeln(
    '  --policy <path>       Policy config JSON path (default: STARTUP_GATE_POLICY.json)',
  );
  stdout.writeln(
    '  --history <path>      Run history JSONL path (default: tools/run_history.jsonl)',
  );
  stdout.writeln(
    '  --history-window <n>  Rolling history window size (default: 10)',
  );
  stdout.writeln(
    '  --no-history-write    Do not append this run to history store',
  );
  stdout.writeln('  --json                Emit JSON output for CI dashboards');
  stdout.writeln('  --help, -h            Show this help message');
}

void _fail(String message) {
  stderr.writeln('STARTUP GATE: FAIL');
  stderr.writeln('- $message');
  exitCode = 1;
}




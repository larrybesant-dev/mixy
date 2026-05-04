#!/usr/bin/env dart
// ignore_for_file: avoid_print
//
// Pre-commit stream architecture check
// =====================================
// Blocks a git commit when new Firestore stream violations are introduced.
//
// SETUP (one-time, run from project root):
//
//   # Option A — symlink (recommended)
//   ln -sf ../../tooling/pre_commit_stream_check.dart .git/hooks/pre-commit
//   chmod +x .git/hooks/pre-commit
//
//   # Option B — git config
//   git config core.hooksPath tooling/git-hooks
//   # Then place this script at tooling/git-hooks/pre-commit
//
//   # Option C — lefthook / husky
//   # See tooling/lefthook.yml or tooling/.huskyrc
//
// HOW IT WORKS
//   1. Gets the list of staged Dart files via `git diff --cached --name-only`
//   2. For each staged file runs the pattern checks inline (fast, no subprocess)
//   3. If violations exist, prints a summary and exits 1 (blocking the commit)
//   4. Clean → exits 0 (commit proceeds)
//
// BYPASS (use sparingly, document why):
//   git commit --no-verify -m "..."

import 'dart:io';

// ── Inline rule set (subset of CI linter — fast patterns only) ───────────────

const _highRiskPatterns = <String, String>{
  r'\.snapshots\(':
      'FCI-001: Direct .snapshots() — use a canonical StreamProvider',
  r'FirebaseFirestore\.instance':
      'FCI-002: FirebaseFirestore.instance — use ref.watch(firestoreProvider)',
  r'StreamController\s*[<(]':
      'FCI-005: StreamController in feature/UI — use Riverpod StreamProvider',
};

const _exemptPrefixes = <String>[
  'lib/services/',
  'lib/core/',
  'lib/dev_tools/',
  'tool/',
  'tooling/',
  'test/',
];

// ── Entry point ───────────────────────────────────────────────────────────────

void main(List<String> args) {
  // Allow bypassing individual rules via args for edge cases.
  final skipRules = <String>{};
  for (final arg in args) {
    if (arg.startsWith('--skip=')) skipRules.add(arg.substring(7));
  }

  final stagedFiles = _getStagedDartFiles();
  if (stagedFiles.isEmpty) {
    // No Dart files staged → nothing to check.
    exit(0);
  }

  stdout.writeln(
    '\n🔍 Stream architecture pre-commit check (${stagedFiles.length} Dart file(s))…',
  );

  final violations = <({String file, int line, String rule, String code})>[];

  for (final filePath in stagedFiles) {
    _checkFile(filePath, skipRules, violations);
  }

  if (violations.isEmpty) {
    stdout.writeln('✅  No stream architecture violations found.\n');
    exit(0);
  }

  // ── Print violations ────────────────────────────────────────────────────────
  stderr.writeln();
  stderr.writeln(
    '╔══════════════════════════════════════════════════════════╗',
  );
  stderr.writeln('║  ❌  COMMIT BLOCKED — STREAM ARCHITECTURE VIOLATIONS     ║');
  stderr.writeln(
    '╚══════════════════════════════════════════════════════════╝',
  );
  stderr.writeln();

  for (final v in violations) {
    stderr.writeln('  📍 ${v.file}:${v.line}');
    stderr.writeln('     ${v.rule}');
    stderr.writeln('     Code: ${v.code.trim()}');
    stderr.writeln();
  }

  stderr.writeln(
    '─────────────────────────────────────────────────────────────',
  );
  stderr.writeln('  ${violations.length} violation(s) found.');
  stderr.writeln();
  stderr.writeln('  Fix options:');
  stderr.writeln('    1. Replace with a canonical StreamProvider from:');
  stderr.writeln('       lib/core/architecture/stream_registry.dart');
  stderr.writeln(
    '    2. Move logic into lib/services/ (service layer is exempt)',
  );
  stderr.writeln('    3. If genuinely new canonical stream: register it in');
  stderr.writeln(
    '       kCanonicalStreamProviderNames in stream_registry.dart',
  );
  stderr.writeln();
  stderr.writeln(
    '  Full linter: dart run tool/firestore_stream_ci_linter.dart',
  );
  stderr.writeln('  Bypass (justify in PR): git commit --no-verify');
  stderr.writeln(
    '─────────────────────────────────────────────────────────────\n',
  );

  exit(1);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

List<String> _getStagedDartFiles() {
  try {
    final result = Process.runSync('git', ['diff', '--cached', '--name-only']);
    if (result.exitCode != 0) return const [];
    return (result.stdout as String)
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.endsWith('.dart') && p.isNotEmpty)
        .toList();
  } catch (_) {
    // git not available or not a git repo — skip check.
    return const [];
  }
}

void _checkFile(
  String filePath,
  Set<String> skipRules,
  List<({String file, int line, String rule, String code})> out,
) {
  // Check global exemptions.
  for (final prefix in _exemptPrefixes) {
    if (filePath.startsWith(prefix)) return;
  }

  final file = File(filePath);
  if (!file.existsSync()) return;

  late List<String> lines;
  try {
    lines = file.readAsLinesSync();
  } catch (_) {
    return;
  }

  for (var i = 0; i < lines.length; i++) {
    final rawLine = lines[i];
    final trimmed = rawLine.trim();

    // Skip comments and imports.
    if (trimmed.startsWith('//') ||
        trimmed.startsWith('*') ||
        trimmed.startsWith('import ') ||
        trimmed.startsWith('export ')) {
      continue;
    }

    for (final entry in _highRiskPatterns.entries) {
      final ruleId = entry.value.split(':').first;
      if (skipRules.contains(ruleId)) continue;
      if (RegExp(entry.key).hasMatch(rawLine)) {
        out.add((
          file: filePath,
          line: i + 1,
          rule: entry.value,
          code: rawLine,
        ));
      }
    }
  }
}

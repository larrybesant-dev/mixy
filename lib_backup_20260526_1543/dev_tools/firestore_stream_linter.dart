// ignore_for_file: avoid_print
//
// # Firestore Stream Linter
//
// A dev-only, zero-crash utility that scans the lib/features source tree for
// direct Firestore stream usage patterns that violate the ONE-STREAM-PER-DOMAIN
// rule enforced by the stream registry.
//
// ## What it catches
//
//   • `.snapshots()` calls in feature-layer files
//   • `FirebaseFirestore.instance` references outside core/services
//   • `StreamProvider` declarations not in the canonical allow-list
//
// ## What it does NOT do
//
//   • It never throws or crashes production
//   • It never touches real Firestore at runtime
//   • It only runs when `kDebugMode == true`
//
// Call `FirestoreStreamLinter.runAsync()` once at app startup (debug builds
// only) — it is intentionally fire-and-forget so it cannot block the UI.

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Describes a single policy violation found by the linter.
final class StreamLintViolation {
  const StreamLintViolation({
    required this.file,
    required this.line,
    required this.lineContent,
    required this.rule,
  });

  /// Workspace-relative file path, e.g. `lib/features/auth/auth_controller.dart`.
  final String file;

  /// 1-based line number inside [file].
  final int line;

  /// The raw source line that triggered the violation (trimmed).
  final String lineContent;

  /// Human-readable rule that was violated.
  final String rule;

  @override
  String toString() => '  [$file:$line] $rule\n    → ${lineContent.trim()}';
}

/// Lightweight static analyser that runs purely on in-memory source strings.
///
/// In production this class is a no-op: every public method is guarded by
/// `if (!kDebugMode) return`.
abstract final class FirestoreStreamLinter {
  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Run the full linter asynchronously (fire-and-forget).
  ///
  /// Results are emitted via [developer.log] under the `StreamLinter` name so
  /// they appear in the VS Code output panel and `flutter logs` without
  /// cluttering release builds.
  ///
  /// **Never awaited by callers** — the linter must never block app startup.
  static void runAsync(Map<String, String> sourceMap) {
    if (!kDebugMode) return;
    Future<void>(() => _run(sourceMap)).ignore();
  }

  // ─── Rules ──────────────────────────────────────────────────────────────────

  static const _rules = <_Rule>[
    _Rule(
      id: 'FSL001',
      description: 'Direct .snapshots() call in feature layer. '
          'Use a canonical stream provider instead.',
      pattern: r'\.snapshots\(',
      // Allowed in: services, core providers, stream_registry itself
      allowedPathPrefixes: <String>[
        'lib/services/',
        'lib/core/',
        'lib/dev_tools/',
      ],
    ),
    _Rule(
      id: 'FSL002',
      description: 'FirebaseFirestore.instance used directly. '
          'Use ref.watch(firestoreProvider) instead.',
      pattern: r'FirebaseFirestore\.instance',
      allowedPathPrefixes: <String>[
        'lib/services/',
        'lib/core/',
        'lib/dev_tools/',
      ],
    ),
    _Rule(
      id: 'FSL003',
      description:
          'StreamProvider declared in feature layer without delegation. '
          'Derive from a canonical provider or register a new canonical entry '
          'in lib/core/architecture/stream_registry.dart.',
      pattern: r'StreamProvider(?!\.autoDispose\.family|\.family|\.autoDispose)'
          r'\s*[<(]',
      allowedPathPrefixes: <String>[
        'lib/services/',
        'lib/core/',
        'lib/dev_tools/',
        // Canonical provider files — these are the only places new
        // StreamProviders may be declared.
        'lib/features/messaging/providers/messaging_provider.dart',
        'lib/features/follow/providers/follow_provider.dart',
        'lib/features/room/providers/participant_providers.dart',
        'lib/features/friends/providers/friends_providers.dart',
        'lib/features/notifications/',
        'lib/features/verification/providers/verification_provider.dart',
        'lib/features/feed/providers/feed_providers.dart',
        'lib/features/schema_messenger/',
        'lib/presentation/providers/',
      ],
    ),
  ];

  // ─── Internal ───────────────────────────────────────────────────────────────

  static void _run(Map<String, String> sourceMap) {
    final violations = <StreamLintViolation>[];

    for (final entry in sourceMap.entries) {
      final path = entry.key;
      final source = entry.value;
      _lintFile(path, source, violations);
    }

    if (violations.isEmpty) {
      developer.log(
        '✅ No stream architecture violations found.',
        name: 'StreamLinter',
      );
      return;
    }

    final buffer = StringBuffer()
      ..writeln()
      ..writeln(
        '┌─────────────────────────────────────────────────────────────',
      )
      ..writeln('│  ⚠️  STREAM ARCHITECTURE VIOLATIONS DETECTED')
      ..writeln(
        '│  These patterns will cause Firestore cost inflation at scale.',
      )
      ..writeln(
        '│  Fix before merging — see stream_registry.dart for guidance.',
      )
      ..writeln(
        '├─────────────────────────────────────────────────────────────',
      );

    for (final v in violations) {
      buffer
        ..writeln('│')
        ..writeln('│  [${v.file}:${v.line}]')
        ..writeln('│  Rule: ${v.rule}')
        ..writeln('│  Code: ${v.lineContent.trim()}');
    }

    buffer
      ..writeln('│')
      ..writeln(
        '└─────────────────────────────────────────────────────────────',
      );

    developer.log(buffer.toString(), name: 'StreamLinter', level: 900);

    // Also print to console for visibility in `flutter run` output.
    if (kDebugMode) {
      print(buffer.toString());
    }
  }

  static void _lintFile(
    String path,
    String source,
    List<StreamLintViolation> violations,
  ) {
    // Only lint feature + presentation + widget layers.
    if (!path.startsWith('lib/features/') &&
        !path.startsWith('lib/presentation/') &&
        !path.startsWith('lib/widgets/')) {
      return;
    }

    // Only check Dart files.
    if (!path.endsWith('.dart')) return;

    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final rawLine = lines[i];

      // Skip comment-only lines and import/export lines — imports are
      // expected to reference canonical symbols by name.
      final trimmed = rawLine.trim();
      if (trimmed.startsWith('//') ||
          trimmed.startsWith('*') ||
          trimmed.startsWith('import ') ||
          trimmed.startsWith('export ')) {
        continue;
      }

      for (final rule in _rules) {
        if (!rule.matches(path, rawLine)) continue;
        violations.add(
          StreamLintViolation(
            file: path,
            line: i + 1,
            lineContent: rawLine,
            rule: '[${rule.id}] ${rule.description}',
          ),
        );
      }
    }
  }
}

// ─── Internal rule model ─────────────────────────────────────────────────────

final class _Rule {
  const _Rule({
    required this.id,
    required this.description,
    required this.pattern,
    this.allowedPathPrefixes = const <String>[],
  });

  final String id;
  final String description;
  final String pattern;
  final List<String> allowedPathPrefixes;

  bool matches(String filePath, String line) {
    // If the file is in an allowed prefix, don't flag it.
    for (final prefix in allowedPathPrefixes) {
      if (filePath.startsWith(prefix) || filePath.contains(prefix)) {
        return false;
      }
    }
    return RegExp(pattern).hasMatch(line);
  }
}

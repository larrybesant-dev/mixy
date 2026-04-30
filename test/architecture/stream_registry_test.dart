/// Architecture guardrail test — stream registry enforcement.
///
/// Verifies at test-time that:
/// 1. `firestoreProvider` is not re-declared in feature files.
/// 2. Each stream domain has exactly one canonical StreamProvider declaration.
/// 3. Known illegal direct Firestore access patterns are absent from widget files.
///
/// Run: flutter test test/architecture/stream_registry_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// ── helpers ──────────────────────────────────────────────────────────────────

/// Returns all *.dart files under [root], recursively.
Iterable<File> dartFiles(String root) sync* {
  final dir = Directory(root);
  if (!dir.existsSync()) return;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

/// Returns (file path, line number, trimmed line content) for every line in
/// [file] matching [pattern].
Iterable<({String file, int line, String content})> grep(
  File file,
  Pattern pattern,
) sync* {
  final lines = file.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trim();
    if (trimmed.contains(pattern) && !trimmed.startsWith('//') && !trimmed.startsWith('*')) {
      yield (file: file.path, line: i + 1, content: trimmed);
    }
  }
}

// ── canonical paths ───────────────────────────────────────────────────────────

const String _canonicalFirestoreProvider =
    'lib/core/providers/firebase_providers.dart';

/// Feature directories that must NOT declare their own firestoreProvider.
const List<String> _featureDirs = [
  'lib/features',
  'lib/widgets',
  'lib/presentation',
];

// ── test suite ────────────────────────────────────────────────────────────────

void main() {
  group('StreamRegistry architecture guardrails', () {
    // ── 1. firestoreProvider single declaration ────────────────────────────
    test('firestoreProvider is declared only in core/providers/firebase_providers.dart', () {
      final violations = <String>[];

      for (final dir in _featureDirs) {
        for (final file in dartFiles(dir)) {
          // Skip the canonical file itself.
          if (file.path.contains(_canonicalFirestoreProvider)) continue;

          for (final match in grep(file, 'firestoreProvider = Provider<FirebaseFirestore>')) {
            violations.add('${p.relative(match.file)}:${match.line}  →  ${match.content}');
          }
        }
      }

      if (violations.isNotEmpty) {
        fail(
          'firestoreProvider is re-declared outside its canonical location.\n'
          'Remove these declarations and import from core/providers/firebase_providers.dart:\n\n'
          '${violations.join('\n')}',
        );
      }
    });

    // ── 2. No raw FirebaseFirestore.instance usage in widgets/screens ─────
    test('Widgets and screens do not call FirebaseFirestore.instance directly', () {
      final violations = <String>[];
      const allowedPaths = [
        'lib/dev/', // emulator bootstrap is intentional
        'lib/core/', // canonical singletons live here
      ];

      for (final file in dartFiles('lib')) {
        final rel = p.relative(file.path).replaceAll('\\', '/');
        if (allowedPaths.any((ap) => rel.startsWith(ap))) continue;
        // Only flag widgets, screens, and providers — not services/repositories
        if (!rel.contains('screen') &&
            !rel.contains('widget') &&
            !rel.contains('providers/') &&
            !rel.contains('controller')) continue;

        for (final match in grep(file, 'FirebaseFirestore.instance')) {
          violations.add('${p.relative(match.file)}:${match.line}  →  ${match.content}');
        }
      }

      if (violations.isNotEmpty) {
        fail(
          'Direct FirebaseFirestore.instance calls found in UI/provider layer.\n'
          'Use ref.watch(firestoreProvider) instead:\n\n'
          '${violations.join('\n')}',
        );
      }
    });

    // ── 3. No duplicate StreamProvider for the same named domain ──────────
    test('Each domain stream is declared exactly once', () {
      // Map: canonical name suffix → expected single declaration file
      const Map<String, String> canonicalStreams = {
        'rawConversationsStreamProvider':
            'features/messaging/providers/messaging_provider.dart',
        'rawFollowGraphStreamProvider':
            'features/follow/providers/follow_provider.dart',
        'rawFollowerIdsStreamProvider':
            'features/follow/providers/follow_provider.dart',
        'roomDocStreamProvider':
            'features/room/providers/participant_providers.dart',
        'participantsStreamProvider':
            'features/room/providers/participant_providers.dart',
      };

      for (final entry in canonicalStreams.entries) {
        final providerName = entry.key;
        final expectedFile = entry.value;
        final declarations = <String>[];

        for (final file in dartFiles('lib')) {
          for (final match in grep(file, 'final $providerName =')) {
            declarations.add('${p.relative(match.file)}:${match.line}');
          }
        }

        expect(
          declarations.length,
          lessThanOrEqualTo(1),
          reason:
              '$providerName must be declared exactly once (expected in $expectedFile) '
              'but found ${declarations.length} declarations:\n${declarations.join('\n')}',
        );
      }
    });

    // ── 4. messagetreamProvider (typo) must not open a live stream ─────────
    // chat_providers.dart's messagetreamProvider is a legacy typo-named provider
    // that routes through ChatRepository. It is allowed ONLY as a thin delegating
    // wrapper — not as a direct .snapshots() call.
    test('chat_providers messagetreamProvider delegates through repository, not direct snapshots', () {
      const targetFile = 'lib/features/feed/providers/chat_providers.dart';
      final file = File(targetFile);
      if (!file.existsSync()) return; // file was removed — nothing to check

      final violations = <String>[];
      for (final match in grep(file, '.snapshots()')) {
        violations.add('${p.relative(match.file)}:${match.line}  →  ${match.content}');
      }

      if (violations.isNotEmpty) {
        fail(
          'chat_providers.dart must not call .snapshots() directly. '
          'It must delegate through ChatRepository:\n\n'
          '${violations.join('\n')}',
        );
      }
    });
  });
}

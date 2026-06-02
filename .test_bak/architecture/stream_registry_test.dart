// Architecture guardrail test — stream registry enforcement.
//
// Verifies at test-time that:
// 1. `firestoreProvider` is not re-declared in feature files.
// 2. Each stream domain has exactly one canonical StreamProvider declaration.
// 3. Known illegal direct Firestore access patterns are absent from widget files.
//
// Run: flutter test test/architecture/stream_registry_test.dart
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
    if (trimmed.contains(pattern) &&
        !trimmed.startsWith('//') &&
        !trimmed.startsWith('*')) {
      yield (file: file.path, line: i + 1, content: trimmed);
    }
  }
}

const _roomsCollectionPattern = ".collection('rooms')";
const _roomsCollectionPatternDouble = '.collection("rooms")';

bool _containsIllegalTopLevelRoomsRead(List<String> lines, int anchorLine) {
  final start = (anchorLine - 4).clamp(0, anchorLine);
  final end = (anchorLine + 8).clamp(anchorLine + 1, lines.length);
  final context = lines.sublist(start, end).join(' ');

    final collectionIndex = context.contains(_roomsCollectionPattern)
      ? context.indexOf(_roomsCollectionPattern)
      : context.indexOf(_roomsCollectionPatternDouble);
  if (collectionIndex == -1) {
    return false;
  }

  final suffix = context.substring(collectionIndex);
  final firstDoc = suffix.indexOf('.doc(');
  final indices = <int>[
    suffix.indexOf('.where('),
    suffix.indexOf('.orderBy('),
    suffix.indexOf('.limit('),
    suffix.indexOf('.count('),
    suffix.indexOf('.get('),
    suffix.indexOf('.snapshots('),
  ].where((index) => index >= 0).toList(growable: false)
    ..sort();

  if (indices.isEmpty) {
    return false;
  }

  final firstQueryOrRead = indices.first;
  return firstDoc == -1 || firstQueryOrRead < firstDoc;
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
    test(
      'firestoreProvider is declared only in core/providers/firebase_providers.dart',
      () {
        final violations = <String>[];

        for (final dir in _featureDirs) {
          for (final file in dartFiles(dir)) {
            // Skip the canonical file itself.
            if (file.path.contains(_canonicalFirestoreProvider)) continue;

            for (final match in grep(
              file,
              'firestoreProvider = Provider<FirebaseFirestore>',
            )) {
              violations.add(
                '${p.relative(match.file)}:${match.line}  →  ${match.content}',
              );
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
      },
    );

    test('Top-level rooms collection reads are owned only by RoomService', () {
      final violations = <String>[];
      const canonicalRoomReadFile = 'lib/services/room_service.dart';

      for (final file in dartFiles('lib')) {
        final rel = p.relative(file.path).replaceAll('\\', '/');
        if (rel == canonicalRoomReadFile || rel.startsWith('lib/dev/')) {
          continue;
        }

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final trimmed = lines[i].trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('*')) {
            continue;
          }

          final touchesRoomsCollection =
              trimmed.contains(_roomsCollectionPattern) ||
              trimmed.contains(_roomsCollectionPatternDouble) ||
              trimmed.contains(".where('isLive'") ||
              trimmed.contains('.where("isLive"');
          if (!touchesRoomsCollection) {
            continue;
          }

          if (_containsIllegalTopLevelRoomsRead(lines, i)) {
            violations.add('$rel:${i + 1}  →  $trimmed');
          }
        }
      }

      if (violations.isNotEmpty) {
        fail(
          'Top-level rooms collection reads were found outside RoomService.\n'
          'Discovery and visibility queries must route through '
          'RoomService.watchRoomsWithVisibility() or a RoomService-owned helper:\n\n'
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
      const allowedDirectFirestoreFiles = <String>{
        'lib/features/after_dark/screens/after_dark_create_lounge_screen.dart',
        'lib/features/after_dark/screens/after_dark_profile_screen.dart',
        'lib/features/auth/controllers/auth_controller.dart',
        'lib/features/feed/controllers/feed_controller.dart',
        'lib/features/feed/controllers/paginated_following_feed_controller.dart',
        'lib/features/feed/controllers/paginated_posts_controller.dart',
        'lib/features/feed/screens/discovery_feed_screen.dart',
        'lib/features/messaging/screens/create_group_chat_screen.dart',
        'lib/features/messaging/screens/new_message_screen.dart',
        'lib/features/onboarding/onboarding_screen.dart',
        'lib/features/posts/screens/create_post_screen.dart',
        'lib/features/profile/profile_controller.dart',
        'lib/features/room/providers/room_firestore_provider.dart',
        'lib/features/room/screens/cam_popout_screen.dart',
        'lib/presentation/providers/wallet_provider.dart',
        'lib/widgets/user_profile_popup.dart',
      };

      for (final file in dartFiles('lib')) {
        final rel = p.relative(file.path).replaceAll('\\', '/');
        if (allowedPaths.any((ap) => rel.startsWith(ap))) continue;
        if (allowedDirectFirestoreFiles.contains(rel)) continue;
        // Only flag widgets, screens, and providers — not services/repositories
        if (!rel.contains('screen') &&
            !rel.contains('widget') &&
            !rel.contains('providers/') &&
            !rel.contains('controller')) {
          continue;
        }

        for (final match in grep(file, 'FirebaseFirestore.instance')) {
          violations.add(
            '${p.relative(match.file)}:${match.line}  →  ${match.content}',
          );
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
    test(
      'chat_providers messagetreamProvider delegates through repository, not direct snapshots',
      () {
        const targetFile = 'lib/features/feed/providers/chat_providers.dart';
        final file = File(targetFile);
        if (!file.existsSync()) return; // file was removed — nothing to check

        final violations = <String>[];
        for (final match in grep(file, '.snapshots()')) {
          violations.add(
            '${p.relative(match.file)}:${match.line}  →  ${match.content}',
          );
        }

        if (violations.isNotEmpty) {
          fail(
            'chat_providers.dart must not call .snapshots() directly. '
            'It must delegate through ChatRepository:\n\n'
            '${violations.join('\n')}',
          );
        }
      },
    );
  });
}




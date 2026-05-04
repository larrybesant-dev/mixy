#!/usr/bin/env dart
// ignore_for_file: avoid_print
//
// Firestore Stream Architecture CI Hard-Lock Linter
// =================================================
// Enforces the ONE-STREAM-PER-DOMAIN production architecture rule.
//
// CRITICAL rules (FSL) always exit 1 — no exceptions, no path exclusions.
// Inspection rules (FCI) fail based on file path and --strict flag.
//
// RULES
//   FSL-001  StreamProvider.family missing autoDispose           [CRITICAL]
//   FSL-002  Unbounded .snapshots() — no .limit() in query      [CRITICAL]
//   FSL-003  Friend domain snapshot outside canonical file       [CRITICAL]
//   FSL-004  Room domain snapshot outside canonical file         [CRITICAL]
//   FSL-005  Messaging domain snapshot outside canonical file    [CRITICAL]
//   FSL-006  Duplicate Firestore collection subscription         [CRITICAL]
//   FSL-007  Top-level rooms query/read outside RoomService      [CRITICAL]
//   FCI-001  Direct .snapshots() in feature layer               [HIGH]
//   FCI-002  FirebaseFirestore.instance used directly            [HIGH]
//   FCI-003  Raw .listen() on Firestore stream                  [MEDIUM]
//   FCI-004  StreamProvider outside canonical files             [MEDIUM]
//   FCI-005  StreamController in feature/UI layer               [MEDIUM]
//   FCI-006  Direct collection()/doc() in feature layer         [LOW]
//
// EXIT CODES
//   0  clean
//   1  violations found
//   2  tool error
//
// INTEGRATION
//   Pre-commit : tooling/pre_commit_stream_check.dart
//   GitHub CI  : .github/workflows/stream_architecture_check.yml
//   Local      : dart run tool/firestore_stream_ci_linter.dart

import 'dart:io';

// ─── Severity ─────────────────────────────────────────────────────────────────

enum _Severity {
  /// Always fails CI regardless of path, --strict, or any flag.
  critical,

  /// Fails CI when file is in an _errorPath.
  high,

  /// Fails CI only in --strict mode.
  medium,

  /// Never fails CI — informational only.
  low,
}

// ─── Path configuration ───────────────────────────────────────────────────────

/// Paths FULLY exempt from every rule — not scanned at all.
const _globalExemptions = <String>{
  'lib/dev_tools/',
  'tool/',
  'tooling/',
  'test/',
};

/// Service/core paths: exempt from FCI rules but NOT from FSL critical rules.
const _serviceCorePaths = <String>{
  'lib/services/',
  'lib/core/',
  'lib/observability/',
  'lib/dev/',
};

/// Paths where non-critical rule violations are treated as errors.
const _errorPaths = <String>[
  'lib/features/',
  'lib/presentation/',
  'lib/widgets/',
  'lib/shared/',
];

/// Canonical provider files — allowed to declare StreamProviders and open
/// Firestore streams. Exempt from FCI-001 and FCI-004.
const _canonicalProviderFiles = <String>[
  'lib/features/messaging/providers/messaging_provider.dart',
  'lib/features/follow/providers/follow_provider.dart',
  'lib/features/room/providers/participant_providers.dart',
  'lib/features/friends/providers/friends_providers.dart',
  'lib/features/feed/providers/feed_providers.dart',
  'lib/features/feed/providers/typing_providers.dart',
  'lib/features/feed/providers/reaction_providers.dart',
  'lib/features/verification/providers/verification_provider.dart',
  'lib/features/schema_messenger/messages/providers/schema_conversations_providers.dart',
  'lib/features/groups/providers/groups_provider.dart',
  'lib/features/schema_messenger/friends/providers/schema_friend_links_providers.dart',
  'lib/presentation/providers/notification_provider.dart',
  // Domain-specific stream authority files — each owns a single Firestore domain.
  'lib/features/auth/providers/admin_provider.dart',
  'lib/features/room/providers/host_provider.dart',
  'lib/features/room/providers/room_gift_provider.dart',
  'lib/presentation/providers/wallet_provider.dart',
  'lib/features/payments/admin_entitlement_providers.dart',
];

const _roomReadAuthorityFile = 'lib/services/room_service.dart';

// ─── Domain lock configuration ────────────────────────────────────────────────

class _DomainLock {
  const _DomainLock({
    required this.rule,
    required this.domain,
    required this.canonicalFile,
    required this.fix,
  });
  final String rule;
  final String domain;
  final String canonicalFile;
  final String fix;
}

/// Collection keyword → domain lock spec.
/// If .snapshots() is found near this keyword in any file other than
/// canonicalFile, it is a CRITICAL domain-lock violation.
const _domainLocks = <String, _DomainLock>{
  'friendships': _DomainLock(
    rule: 'FSL-003',
    domain: 'Friend',
    canonicalFile: 'lib/features/friends/providers/friends_providers.dart',
    fix:
        'All friendship streams MUST originate from rawAllFriendshipsStreamProvider '
        'or rawAcceptedFriendshipsStreamProvider in friends_providers.dart. '
        'Delete this .snapshots() call and derive from the canonical provider. '
        'See FRIEND_SYSTEM_LOCK rule.',
  ),
  'friend_links': _DomainLock(
    rule: 'FSL-003',
    domain: 'Friend',
    canonicalFile:
        'lib/features/schema_messenger/friends/providers/schema_friend_links_providers.dart',
    fix:
        'friend_links streams must derive from rawAllFriendshipsStreamProvider.',
  ),
  'participants': _DomainLock(
    rule: 'FSL-004',
    domain: 'Room',
    canonicalFile: 'lib/features/room/providers/participant_providers.dart',
    fix:
        'All participant streams MUST come from participantsStreamProvider '
        'in participant_providers.dart. Derive — do not re-subscribe.',
  ),
  'conversations': _DomainLock(
    rule: 'FSL-005',
    domain: 'Messaging',
    canonicalFile: 'lib/features/messaging/providers/messaging_provider.dart',
    fix:
        'All conversation streams MUST come from rawConversationsStreamProvider '
        'in messaging_provider.dart. Schema layers must derive, not re-subscribe.',
  ),
};

// ─── Violation model ──────────────────────────────────────────────────────────

class _Violation {
  const _Violation({
    required this.ruleId,
    required this.severity,
    required this.file,
    required this.line,
    required this.lineContent,
    required this.issue,
    required this.fix,
    this.isError = false,
  });

  final String ruleId;
  final _Severity severity;
  final String file;
  final int line;
  final String lineContent;
  final String issue;
  final String fix;
  final bool isError;

  bool get alwaysFails =>
      severity == _Severity.critical || (severity == _Severity.high && isError);

  String formatted(bool noColor) {
    if (severity == _Severity.critical) {
      return [
        '╔══════════════════════════════════════════════════════════════════',
        '║  🔴 CRITICAL VIOLATION',
        '║  Rule  : $ruleId',
        '║  File  : $file:$line',
        '║  Issue : $issue',
        '║  Code  : ${lineContent.trim()}',
        '║  Fix   : $fix',
        '╚══════════════════════════════════════════════════════════════════',
      ].join('\n');
    }

    final label = switch (severity) {
      _Severity.critical => '🔴 CRITICAL',
      _Severity.high => '🚨 HIGH',
      _Severity.medium => '⚠️  MEDIUM',
      _Severity.low => '📝 LOW',
    };

    return [
      '┌── STREAM ARCHITECTURE VIOLATION ────────────────────────────────',
      '│  File     : $file:$line',
      '│  Rule     : $ruleId',
      '│  Severity : $label',
      '│  Issue    : $issue',
      '│  Code     : ${lineContent.trim()}',
      '│  Fix      : $fix',
      '└─────────────────────────────────────────────────────────────────',
    ].join('\n');
  }

  String compact() {
    final label = severity == _Severity.critical
        ? 'CRITICAL'
        : severity.name.toUpperCase();
    return '[$label] $ruleId $file:$line — $issue';
  }
}

// ─── Per-line rules (FSL-001 + FCI-001..006) ──────────────────────────────────

class _LineRule {
  const _LineRule({
    required this.id,
    required this.severity,
    required this.description,
    required this.fix,
    required this.pattern,
    this.extraCheck,
    this.pathExemptions = const [],
  });

  final String id;
  final _Severity severity;
  final String description;
  final String fix;
  final Pattern pattern;
  final bool Function(String line, String filePath)? extraCheck;
  final List<String> pathExemptions;

  bool matchesLine(String line, String filePath) {
    final trimmed = line.trim();
    if (trimmed.startsWith('//') ||
        trimmed.startsWith('*') ||
        trimmed.startsWith('import ') ||
        trimmed.startsWith('export ')) {
      return false;
    }
    for (final exempt in pathExemptions) {
      if (filePath.contains(exempt)) return false;
    }
    final hasPattern = pattern is RegExp
        ? (pattern as RegExp).hasMatch(line)
        : line.contains(pattern as String);
    if (!hasPattern) return false;
    if (extraCheck != null) return extraCheck!(line, filePath);
    return true;
  }
}

final _lineRules = <_LineRule>[
  // ── FSL-001: StreamProvider.family without autoDispose ────────────────────
  _LineRule(
    id: 'FSL-001',
    severity: _Severity.critical,
    description: 'StreamProvider.family declared without autoDispose',
    fix:
        'Change to StreamProvider.autoDispose.family<...>. '
        'Per-user/per-id StreamProviders MUST autoDispose — without it, '
        'stale listeners accumulate as users navigate between rooms/profiles. '
        'Exceptions: auth, presence heartbeat, notification badge (explicitly documented).',
    pattern: RegExp(r'StreamProvider\.family\s*[<(]'),
    extraCheck: (line, _) => !line.contains('autoDispose'),
    pathExemptions: const ['_test.dart'],
  ),

  // ── FCI-001: .snapshots() in feature layer ────────────────────────────────
  _LineRule(
    id: 'FCI-001',
    severity: _Severity.high,
    description: 'Direct Firestore .snapshots() call in feature layer',
    fix:
        'Replace with a canonical StreamProvider from stream_registry.dart. '
        'Never open .snapshots() outside lib/services/ or lib/core/.',
    pattern: RegExp(r'\.snapshots\('),
    pathExemptions: const ['_test.dart'],
  ),

  // ── FCI-002: FirebaseFirestore.instance ───────────────────────────────────
  _LineRule(
    id: 'FCI-002',
    severity: _Severity.high,
    description: 'FirebaseFirestore.instance used directly',
    fix:
        'Use ref.watch(firestoreProvider) from lib/core/providers/firebase_providers.dart. '
        'Direct .instance bypasses test overrides and makes deduplication impossible.',
    pattern: RegExp(r'FirebaseFirestore\.instance'),
  ),

  // ── FCI-003: raw .listen() on Firestore stream ────────────────────────────
  _LineRule(
    id: 'FCI-003',
    severity: _Severity.medium,
    description: 'Raw .listen() on a Firestore stream in feature layer',
    fix:
        'Replace with a canonical StreamProvider. '
        '.listen() creates an unmanaged subscription that leaks across navigation.',
    pattern: RegExp(
      r'\.collection\([^)]+\).*\.listen\(|\.doc\([^)]+\).*\.listen\(',
    ),
  ),

  // ── FCI-004: StreamProvider outside canonical files ───────────────────────
  _LineRule(
    id: 'FCI-004',
    severity: _Severity.medium,
    description: 'StreamProvider declared outside canonical provider files',
    fix:
        'StreamProviders that open Firestore streams must be declared in a '
        'canonical file and registered in kCanonicalStreamProviderNames. '
        'Derived providers (no .snapshots()) are always permitted.',
    pattern: RegExp(r'StreamProvider(?:\.autoDispose)?(?:\.family)?[<(]'),
    extraCheck: (line, filePath) {
      final normalized = filePath.replaceAll('\\', '/');
      for (final canonical in _canonicalProviderFiles) {
        if (normalized.endsWith(canonical) || normalized.contains(canonical)) {
          return false;
        }
      }
      return true;
    },
  ),

  // ── FCI-005: StreamController in feature/UI layer ─────────────────────────
  _LineRule(
    id: 'FCI-005',
    severity: _Severity.medium,
    description: 'StreamController instantiated in feature/UI layer',
    fix:
        'StreamControllers in widgets/controllers create leaked subscriptions. '
        'Use Riverpod StreamProvider instead.',
    pattern: RegExp(r'StreamController\s*[<(]'),
  ),

  // ── FCI-006: direct collection()/doc() in feature layer ───────────────────
  _LineRule(
    id: 'FCI-006',
    severity: _Severity.low,
    description: 'Direct Firestore collection()/doc() access in feature layer',
    fix:
        'Firestore access must go through the service layer (lib/services/) '
        'or canonical stream providers.',
    pattern: RegExp(
      r'(?:_firestore|firestore|FirebaseFirestore\.instance)\s*\.\s*(?:collection|doc)\(',
    ),
    pathExemptions: const ['_test.dart'],
  ),
];

// ─── Per-file multi-line analysis (FSL-002, FSL-003/004/005) ─────────────────

List<_Violation> _analyzeFileCritical(List<String> lines, String relativePath) {
  final violations = <_Violation>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    // Skip comment lines.
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

    if (!line.contains('.snapshots(')) continue;

    // ── FSL-002: Unbounded query — no .limit() in preceding 10 lines ─────────
    final windowStart = (i - 10).clamp(0, i);
    final window = lines.sublist(windowStart, i + 1).join('\n');
    if (!window.contains('.limit(')) {
      violations.add(
        _Violation(
          ruleId: 'FSL-002',
          severity: _Severity.critical,
          file: relativePath,
          line: i + 1,
          lineContent: line,
          issue:
              'Unbounded .snapshots() — no .limit() within 10 lines. '
              'Unbounded queries cause runaway Firestore read costs at scale.',
          fix:
              'Add .limit(N) before .snapshots(): '
              'feeds/messages/notifications → .limit(50), '
              'social graphs/friend lists → .limit(100). '
              'QUERY_BOUNDS_RULE: no unbounded .snapshots() permitted.',
          isError: true,
        ),
      );
    }

    // ── FSL-003/004/005: Domain lock checks ────────────────────────────────
    // Search context window for known locked collection keywords.
    final ctxStart = (i - 5).clamp(0, i);
    final ctx = lines.sublist(ctxStart, i + 1).join(' ');
    final normalized = relativePath.replaceAll('\\', '/');

    for (final entry in _domainLocks.entries) {
      final keyword = entry.key;
      final lock = entry.value;

      if (!ctx.contains("'$keyword'") &&
          !ctx.contains('"$keyword"') &&
          !ctx.contains('/$keyword')) {
        continue;
      }

      // Is this file the canonical owner for this domain keyword?
      if (normalized.endsWith(lock.canonicalFile) ||
          normalized.contains(lock.canonicalFile)) {
        continue; // Canonical owner — permitted.
      }
      // Service layer is the backing implementation — also permitted.
      if (_serviceCorePaths.any((p) => normalized.startsWith(p))) {
        continue;
      }

      violations.add(
        _Violation(
          ruleId: lock.rule,
          severity: _Severity.critical,
          file: relativePath,
          line: i + 1,
          lineContent: line,
          issue:
              '${lock.domain} domain .snapshots() on "$keyword" collection '
              'outside canonical file. '
              'Canonical: ${lock.canonicalFile}',
          fix: lock.fix,
          isError: true,
        ),
      );
      break; // One domain-lock violation per line is sufficient.
    }
  }

  return violations;
}

// ─── Cross-file duplicate stream detection (FSL-006) ─────────────────────────

class _StreamRef {
  const _StreamRef(this.collection, this.file, this.line, this.lineContent);
  final String collection;
  final String file;
  final int line;
  final String lineContent;
}

final _collectionRe = RegExp(r'''\.collection\(\s*['"]([^'"]+)['"]\s*\)''');
final _roomsCollectionRe = RegExp(r'''\.collection\(\s*['"]rooms['"]\s*\)''');

int _firstIndexOfAny(String source, List<String> needles) {
  var result = -1;
  for (final needle in needles) {
    final index = source.indexOf(needle);
    if (index == -1) continue;
    if (result == -1 || index < result) {
      result = index;
    }
  }
  return result;
}

bool _containsIllegalTopLevelRoomsRead(String context) {
  final match = _roomsCollectionRe.firstMatch(context);
  if (match == null) {
    return false;
  }

  final suffix = context.substring(match.start);
  final firstDoc = suffix.indexOf('.doc(');
  final firstQueryOp = _firstIndexOfAny(suffix, const <String>[
    '.where(',
    '.orderBy(',
    '.limit(',
    '.count(',
  ]);
  if (firstQueryOp != -1 && (firstDoc == -1 || firstQueryOp < firstDoc)) {
    return true;
  }

  final firstReadOp = _firstIndexOfAny(suffix, const <String>[
    '.get(',
    '.snapshots(',
  ]);
  if (firstReadOp != -1 && (firstDoc == -1 || firstReadOp < firstDoc)) {
    return true;
  }

  final firstIsLiveFilter = _firstIndexOfAny(suffix, const <String>[
    ".where('isLive'",
    '.where("isLive"',
  ]);
  return firstIsLiveFilter != -1 &&
      (firstDoc == -1 || firstIsLiveFilter < firstDoc);
}

List<_Violation> _detectIllegalRoomCollectionReads(
  Map<String, List<String>> allFiles,
) {
  final violations = <_Violation>[];

  for (final entry in allFiles.entries) {
    final file = entry.key.replaceAll('\\', '/');
    if (file == _roomReadAuthorityFile) {
      continue;
    }

    final lines = entry.value;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.startsWith('//') || trimmed.startsWith('*')) {
        continue;
      }

      final touchesRoomsCollection =
          _roomsCollectionRe.hasMatch(line) ||
          line.contains(".where('isLive'") ||
          line.contains('.where("isLive"');
      if (!touchesRoomsCollection) {
        continue;
      }

      final ctxStart = (i - 4).clamp(0, i);
      final ctxEnd = (i + 8).clamp(i + 1, lines.length);
      final context = lines.sublist(ctxStart, ctxEnd).join(' ');
      if (!_containsIllegalTopLevelRoomsRead(context)) {
        continue;
      }

      violations.add(
        _Violation(
          ruleId: 'FSL-007',
          severity: _Severity.critical,
          file: file,
          line: i + 1,
          lineContent: line,
          issue:
              'Top-level rooms collection query/read found outside RoomService. '
              'Discovery and visibility reads must be owned by $_roomReadAuthorityFile.',
          fix:
              'Delete this rooms collection read and route through '
              'RoomService.watchRoomsWithVisibility() or a RoomService-owned '
              'classified helper. Do not query the rooms collection directly '
              'from providers, UI, or non-RoomService services.',
          isError: true,
        ),
      );
    }
  }

  return violations;
}

List<_Violation> _detectDuplicateStreams(Map<String, List<String>> allFiles) {
  // collection → list of stream refs (file + line).
  final refs = <String, List<_StreamRef>>{};

  for (final entry in allFiles.entries) {
    final file = entry.key;
    final lines = entry.value;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('//')) continue;
      if (!line.contains('.snapshots(')) continue;

      // Capture .collection('X') within 5 lines before the .snapshots() call.
      final ctxStart = (i - 5).clamp(0, i);
      final ctx = lines.sublist(ctxStart, i + 1).join(' ');
      final matches = _collectionRe.allMatches(ctx);
      if (matches.isEmpty) continue;

      // Take the LAST (innermost) collection name in chained calls.
      final collectionName = matches.last.group(1)!;
      refs
          .putIfAbsent(collectionName, () => [])
          .add(_StreamRef(collectionName, file, i + 1, line));
    }
  }

  final violations = <_Violation>[];

  for (final entry in refs.entries) {
    final collectionName = entry.key;
    final streamRefs = entry.value;
    if (streamRefs.length <= 1) continue;

    // Determine which files are non-canonical (not allowed to open this stream).
    final nonCanonical = streamRefs.where((ref) {
      final n = ref.file.replaceAll('\\', '/');
      // Canonical provider files may legitimately open streams.
      for (final c in _canonicalProviderFiles) {
        if (n.endsWith(c) || n.contains(c)) return false;
      }
      // Service/core layer is the backing implementation.
      if (_serviceCorePaths.any((p) => n.startsWith(p))) return false;
      return true;
    }).toList();

    if (nonCanonical.length <= 1) continue;

    // Multiple non-canonical files subscribe to the same collection.
    final allFiles2 = streamRefs.map((r) => r.file).toSet().join(', ');
    for (final ref in nonCanonical) {
      violations.add(
        _Violation(
          ruleId: 'FSL-006',
          severity: _Severity.critical,
          file: ref.file,
          line: ref.line,
          lineContent: ref.lineContent,
          issue:
              'Duplicate Firestore subscription to "$collectionName" collection '
              'found in ${streamRefs.length} files. SINGLE_STREAM_RULE violated. '
              'Files: $allFiles2',
          fix:
              'Remove this .snapshots() and derive state from the single canonical '
              'StreamProvider for "$collectionName". '
              'See lib/core/architecture/stream_registry.dart for the registered provider.',
          isError: true,
        ),
      );
    }
  }

  return violations;
}

// ─── Per-file line scanner ────────────────────────────────────────────────────

List<_Violation> _scanFileLines(List<String> lines, String relativePath) {
  final violations = <_Violation>[];
  final isErrorPath = _errorPaths.any((p) => relativePath.startsWith(p));
  final isServiceCore = _serviceCorePaths.any(
    (p) => relativePath.startsWith(p),
  );

  for (var i = 0; i < lines.length; i++) {
    final rawLine = lines[i];

    for (final rule in _lineRules) {
      // FSL-001 is CRITICAL — runs everywhere except globally exempt paths.
      // FCI rules skip service/core paths (those layers own Firestore).
      if (rule.severity != _Severity.critical && isServiceCore) continue;

      if (rule.matchesLine(rawLine, relativePath)) {
        violations.add(
          _Violation(
            ruleId: rule.id,
            severity: rule.severity,
            file: relativePath,
            line: i + 1,
            lineContent: rawLine,
            issue: rule.description,
            fix: rule.fix,
            isError: isErrorPath,
          ),
        );
      }
    }
  }

  return violations;
}

// ─── Entry point ──────────────────────────────────────────────────────────────

void main(List<String> args) {
  final strict = args.contains('--strict') || args.contains('-s');
  final compact = args.contains('--compact') || args.contains('-c');
  final noColor = args.contains('--no-color');

  if (args.contains('--help') || args.contains('-h')) {
    _printHelp();
    exit(0);
  }

  final projectRoot = _findProjectRoot();
  if (projectRoot == null) {
    stderr.writeln(
      'ERROR: Could not find project root (no pubspec.yaml). '
      'Run from the MixVy project root.',
    );
    exit(2);
  }

  final libDir = Directory('${projectRoot.path}/lib');
  if (!libDir.existsSync()) {
    stderr.writeln('ERROR: lib/ directory not found at ${libDir.path}');
    exit(2);
  }

  stdout.writeln(
    '\n🔍 MixVy Stream Architecture Linter — scanning ${libDir.path}…\n',
  );

  // ── Phase 1: Collect all Dart file contents ─────────────────────────────

  final allFileLines = <String, List<String>>{};
  var filesScanned = 0;

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final normalized = entity.path.replaceAll('\\', '/');
    final libIdx = normalized.lastIndexOf('/lib/');
    final relativePath = libIdx >= 0
        ? normalized.substring(libIdx + 1)
        : normalized;

    if (!relativePath.endsWith('.dart')) continue;

    // Skip globally exempted paths.
    if (_globalExemptions.any((p) => relativePath.startsWith(p))) continue;

    late List<String> fileLines;
    try {
      fileLines = entity.readAsLinesSync();
    } catch (_) {
      continue;
    }

    filesScanned++;
    allFileLines[relativePath] = fileLines;
  }

  // ── Phase 2: Per-file analysis ──────────────────────────────────────────

  final allViolations = <_Violation>[];

  for (final entry in allFileLines.entries) {
    final relativePath = entry.key;
    final lines = entry.value;

    // Per-line rules (FSL-001, FCI-001..006).
    allViolations.addAll(_scanFileLines(lines, relativePath));

    // Multi-line critical rules (FSL-002, FSL-003/004/005).
    // Service/core are the legitimate Firestore owners; skip them for domain locks
    // but FSL-002 (no .limit) DOES apply to canonical provider files too.
    final isServiceCore = _serviceCorePaths.any(
      (p) => relativePath.startsWith(p),
    );

    if (!isServiceCore) {
      allViolations.addAll(_analyzeFileCritical(lines, relativePath));
    }
  }

  // ── Phase 3: Cross-file duplicate stream detection (FSL-006) ────────────

  allViolations.addAll(_detectDuplicateStreams(allFileLines));

  // ── Phase 4: Room authority hard lock (FSL-007) ─────────────────────────

  allViolations.addAll(_detectIllegalRoomCollectionReads(allFileLines));

  // ── Output ───────────────────────────────────────────────────────────────

  if (allViolations.isEmpty) {
    stdout.writeln(
      '✅  No violations. ($filesScanned files scanned)\n'
      '    SINGLE_STREAM_RULE satisfied — stream architecture is clean.\n',
    );
    exit(0);
  }

  // Sort: critical first, then by file path for deterministic output.
  allViolations.sort((a, b) {
    final aCrit = a.severity == _Severity.critical ? 0 : 1;
    final bCrit = b.severity == _Severity.critical ? 0 : 1;
    if (aCrit != bCrit) return aCrit.compareTo(bCrit);
    final fc = a.file.compareTo(b.file);
    if (fc != 0) return fc;
    return a.line.compareTo(b.line);
  });

  for (final v in allViolations) {
    if (compact) {
      stdout.writeln(v.compact());
    } else {
      stdout.writeln(v.formatted(noColor));
      stdout.writeln();
    }
  }

  // ── Summary ──────────────────────────────────────────────────────────────

  final criticals = allViolations
      .where((v) => v.severity == _Severity.critical)
      .toList();
  final errors = allViolations
      .where((v) => v.severity != _Severity.critical && v.isError)
      .toList();
  final warnings = allViolations
      .where((v) => v.severity != _Severity.critical && !v.isError)
      .toList();

  stdout.writeln(
    '─────────────────────────────────────────────────────────────────',
  );
  stdout.writeln('  SCAN SUMMARY  [PRODUCTION CI HARD LOCK]');
  stdout.writeln('  Files scanned  : $filesScanned');
  stdout.writeln(
    '  🔴 Critical    : ${criticals.length}  ← ALWAYS FAILS CI (FSL)',
  );
  stdout.writeln(
    '  🚨 Errors      : ${errors.length}  ← Fails on error-path files (FCI)',
  );
  stdout.writeln(
    '  ⚠️  Warnings    : ${warnings.length}  ← Fails with --strict (FCI)',
  );
  stdout.writeln();
  stdout.writeln('  By rule:');

  final byRule = <String, int>{};
  for (final v in allViolations) {
    byRule[v.ruleId] = (byRule[v.ruleId] ?? 0) + 1;
  }
  for (final entry
      in byRule.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    final isCrit = allViolations.any(
      (v) => v.ruleId == entry.key && v.severity == _Severity.critical,
    );
    stdout.writeln(
      '    ${entry.key} — ${entry.value} occurrence(s)'
      '${isCrit ? "  🔴 CRITICAL" : ""}',
    );
  }
  stdout.writeln(
    '─────────────────────────────────────────────────────────────────\n',
  );

  // ── Exit logic ────────────────────────────────────────────────────────────

  if (criticals.isNotEmpty) {
    stderr.writeln(
      '🔴  ${criticals.length} CRITICAL violation(s) — CI HARD FAIL.\n'
      '    CRITICAL violations cannot be suppressed. Fix before merging.\n',
    );
    exit(1);
  }

  if (errors.isEmpty && !strict) {
    stdout.writeln(
      '⚠️  Warnings found but no errors. '
      'Exiting 0 (use --strict to fail on warnings).\n',
    );
    exit(0);
  }

  stderr.writeln(
    '❌  ${errors.length} violation(s) must be fixed before merging.\n'
    '    Run: dart run tool/firestore_stream_ci_linter.dart --help\n',
  );
  exit(1);
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

void _printHelp() {
  print(r'''
MixVy Firestore Stream Architecture CI Hard-Lock Linter
=======================================================
Usage: dart run tool/firestore_stream_ci_linter.dart [options]

Options:
  --strict, -s    Treat FCI warnings as errors (recommended for CI)
  --compact, -c   One-line output per violation (for grep/scripts)
  --no-color      Disable color output
  --help, -h      Show this help

CRITICAL Rules (FSL) — always fail CI, no exceptions:
  FSL-001  StreamProvider.family missing autoDispose
  FSL-002  Unbounded .snapshots() without .limit() in query chain
  FSL-003  Friend domain snapshot outside canonical file
           → Canonical: lib/features/friends/providers/friends_providers.dart
  FSL-004  Room domain snapshot outside canonical file
           → Canonical: lib/features/room/providers/participant_providers.dart
  FSL-005  Messaging domain snapshot outside canonical file
           → Canonical: lib/features/messaging/providers/messaging_provider.dart
  FSL-006  Duplicate Firestore collection subscription (cross-file analysis)
  FSL-007  Top-level rooms collection query/read outside RoomService
           → Canonical: lib/services/room_service.dart

Inspection Rules (FCI) — fail by path and --strict:
  FCI-001  Direct .snapshots() in feature layer          [HIGH]
  FCI-002  FirebaseFirestore.instance used directly      [HIGH]
  FCI-003  Raw .listen() on Firestore stream            [MEDIUM]
  FCI-004  StreamProvider outside canonical files       [MEDIUM]
  FCI-005  StreamController in feature/UI layer         [MEDIUM]
  FCI-006  Direct collection()/doc() in feature layer   [LOW]

Exit codes:
  0  Clean
  1  Violations found (CRITICAL or errors; or warnings with --strict)
  2  Tool error

Documentation: lib/core/architecture/stream_registry.dart
''');
}

Directory? _findProjectRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

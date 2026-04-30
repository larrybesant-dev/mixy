import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presence collection access is restricted to approved files', () {
    final root = Directory.current;
    final libDir = Directory('${root.path}${Platform.pathSeparator}lib');
    final allowed = <String>{
      'lib/services/presence_controller.dart',
      'lib/services/presence_repository.dart',
      'lib/services/presence_service.dart',
      'lib/shared/widgets/app_debug_overlay.dart',
      'lib/presentation/providers/presence_provider.dart',
    };

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final normalizedPath = entity.path
          .replaceAll('\\', '/')
          .split('/lib/')
          .last;
      final relativePath = 'lib/$normalizedPath';
      final content = entity.readAsStringSync();

      if (content.contains("collection('presence')") && !allowed.contains(relativePath)) {
        violations.add(relativePath);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Only PresenceController/PresenceRepository/PresenceService may access the presence collection directly. Violations: ${violations.join(', ')}',
    );
  });

  test('presence service is not used directly in production features', () {
    final root = Directory.current;
    final libDir = Directory('${root.path}${Platform.pathSeparator}lib');
    final allowed = <String>{
      'lib/services/presence_service.dart',
      'lib/services/presence_repository.dart',
      'lib/services/presence_controller.dart',
      'lib/core/providers/firebase_providers.dart',
      'lib/services/rtdb_presence_service.dart',
    };

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final normalizedPath = entity.path
          .replaceAll('\\', '/')
          .split('/lib/')
          .last;
      final relativePath = 'lib/$normalizedPath';
      final content = entity.readAsStringSync();

        final importsPresenceService = content.contains("/presence_service.dart") ||
          content.contains("'presence_service.dart'") ||
          content.contains('"presence_service.dart"');
      final constructsPresenceService = content.contains('PresenceService(');
      if ((importsPresenceService || constructsPresenceService) && !allowed.contains(relativePath)) {
        violations.add(relativePath);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Production code must read presence through PresenceRepository and write through PresenceController. Violations: ${violations.join(', ')}',
    );
  });
}

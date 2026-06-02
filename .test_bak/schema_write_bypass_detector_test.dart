import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detect direct users writes outside mutation boundary', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);

    const allowlistedFiles = <String>{
      'lib/features/after_dark/providers/after_dark_provider.dart',
      'lib/features/after_dark/screens/after_dark_profile_screen.dart',
      'lib/features/onboarding/onboarding_screen.dart',
      'lib/features/profile/profile_background.dart',
      'lib/features/profile/profile_music.dart',
      'lib/services/daily_checkin_service.dart',
      'lib/services/schema_mutation_service.dart',
    };

    final directUsersWritePattern = RegExp(
      r"collection\('users'\)\s*\.doc\([^\)]*\)\s*\.(set|update)\(",
      multiLine: true,
      dotAll: true);

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final normalizedPath = entity.path.replaceAll('\\', '/');
      final content = entity.readAsStringSync();
      if (!directUsersWritePattern.hasMatch(content)) {
        continue;
      }

      if (!allowlistedFiles.contains(normalizedPath)) {
        violations.add(normalizedPath);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Found direct users writes outside SchemaMutationService boundary: $violations');
  });
}











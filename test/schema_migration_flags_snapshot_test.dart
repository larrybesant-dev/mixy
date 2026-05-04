import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema migration flags are stable and referenced', () {
    final configPath = 'lib/config/schema_migration_flags.dart';
    final configFile = File(configPath);
    expect(configFile.existsSync(), isTrue);

    final content = configFile.readAsStringSync();

    final expectedEnvKeys = <String>{
      'MIXVY_STRICT_WRITE_AUTHORITY',
      'MIXVY_ENABLE_PROFILE_LEGACY_WRITE',
      'MIXVY_ENABLE_FRIEND_LEGACY_WRITE',
      'MIXVY_ENABLE_VERIFICATION_LEGACY_READ',
      'MIXVY_ENABLE_USERS_SHADOW_MERGE',
      'MIXVY_ENABLE_AVATAR_LEGACY_WRITE',
    };

    final envRegex = RegExp(
      r"bool\.fromEnvironment\(\s*'([^']+)'",
      multiLine: true,
    );
    final actualEnvKeys = envRegex
        .allMatches(content)
        .map((m) => m.group(1)!)
        .toSet();

    expect(
      actualEnvKeys,
      equals(expectedEnvKeys),
      reason: 'Unexpected schema migration env flag drift.',
    );

    final fieldRegex = RegExp(
      r'static const bool\s+(\w+)\s*=\s*bool\.fromEnvironment\(',
      multiLine: true,
    );
    final flagFields = fieldRegex
        .allMatches(content)
        .map((m) => m.group(1)!)
        .toList(growable: false);

    expect(flagFields, isNotEmpty);

    final dartFiles = Directory('lib')
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList(growable: false);

    final directSchemaEnvOutsideConfig = <String>[];
    for (final file in dartFiles) {
      final normalized = file.path.replaceAll('\\', '/');
      if (normalized == configPath) {
        continue;
      }
      final fileContent = file.readAsStringSync();
      final hasSchemaEnv = RegExp(
        r"bool\.fromEnvironment\(\s*'MIXVY_",
      ).hasMatch(fileContent);
      if (hasSchemaEnv) {
        directSchemaEnvOutsideConfig.add(normalized);
      }
    }

    expect(
      directSchemaEnvOutsideConfig,
      isEmpty,
      reason: 'Schema flags must be centralized in $configPath only.',
    );

    final libContentByPath = <String, String>{
      for (final file in dartFiles)
        file.path.replaceAll('\\', '/'): file.readAsStringSync(),
    };

    final missingUsages = <String>[];
    for (final field in flagFields) {
      var references = 0;
      for (final entry in libContentByPath.entries) {
        if (entry.key == configPath) {
          continue;
        }
        if (entry.value.contains('SchemaMigrationFlags.$field')) {
          references += 1;
        }
      }
      if (references == 0) {
        missingUsages.add(field);
      }
    }

    expect(
      missingUsages,
      isEmpty,
      reason:
          'Found orphan schema flags not used in runtime code: $missingUsages',
    );
  });
}

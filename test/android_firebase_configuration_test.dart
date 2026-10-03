import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Firebase config matches Dart and has Google OAuth', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final packageName = RegExp(
      r'applicationId\s*=\s*"([^"]+)"',
    ).firstMatch(gradle)?.group(1);
    expect(packageName, isNotNull);

    final config = jsonDecode(
      File('android/app/google-services.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final projectInfo = config['project_info'] as Map<String, dynamic>;
    final clients = config['client'] as List<dynamic>;
    final androidClient = clients.cast<Map<String, dynamic>>().singleWhere(
      (client) =>
          (client['client_info'] as Map<String, dynamic>)['android_client_info']
              ['package_name'] ==
          packageName,
    );

    final firebaseOptions = File('lib/firebase_options.dart').readAsStringSync();
    final androidOptions = RegExp(
      r'static const FirebaseOptions android = FirebaseOptions\((.*?)\);',
      dotAll: true,
    ).firstMatch(firebaseOptions)?.group(1);
    final dartProjectId = RegExp(
      r"projectId:\s*'([^']+)'",
    ).firstMatch(androidOptions ?? '')?.group(1);

    expect(projectInfo['project_id'], dartProjectId);

    final oauthClients = androidClient['oauth_client'] as List<dynamic>;
    expect(
      oauthClients.cast<Map<String, dynamic>>().any(
        (client) =>
            client['client_type'] == 1 &&
            (client['android_info'] as Map<String, dynamic>?)?['package_name'] ==
                packageName &&
            ((client['android_info'] as Map<String, dynamic>?)?['certificate_hash']
                        as String?)
                    ?.isNotEmpty ==
                true,
      ),
      isTrue,
      reason: 'Missing certificate-bound Android OAuth client for $packageName',
    );
  });
}
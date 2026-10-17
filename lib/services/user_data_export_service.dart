import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class UserDataExportService {
  Future<bool> requestExport({required String userId, String? email});
}

class EmailUserDataExportService implements UserDataExportService {
  EmailUserDataExportService({Future<bool> Function(Uri)? launcher})
      : _launcher = launcher ??
            ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

  static const _privacyEmail = 'larrybesant@gmail.com';

  final Future<bool> Function(Uri) _launcher;

  @override
  Future<bool> requestExport({required String userId, String? email}) {
    final accountEmail = email?.trim();
    final body = StringBuffer()
      ..writeln('Please provide an export of my MixVy account data.')
      ..writeln()
      ..writeln('User ID: $userId');
    if (accountEmail != null && accountEmail.isNotEmpty) {
      body.writeln('Account email: $accountEmail');
    }

    return _launcher(
      Uri(
        scheme: 'mailto',
        path: _privacyEmail,
        queryParameters: {
          'subject': 'MixVy data export request',
          'body': body.toString(),
        },
      ),
    );
  }
}

final userDataExportServiceProvider = Provider<UserDataExportService>((ref) {
  return EmailUserDataExportService();
});

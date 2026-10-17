import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/services/user_data_export_service.dart';

void main() {
  test('data export request contains the authenticated account details',
      () async {
    Uri? launchedUri;
    final service = EmailUserDataExportService(
      launcher: (uri) async {
        launchedUri = uri;
        return true;
      },
    );

    final opened = await service.requestExport(
      userId: 'user-123',
      email: 'member@example.com',
    );

    expect(opened, isTrue);
    expect(launchedUri?.scheme, 'mailto');
    expect(launchedUri?.path, 'larrybesant@gmail.com');
    expect(
        launchedUri?.queryParameters['subject'], 'MixVy data export request');
    expect(launchedUri?.queryParameters['body'], contains('User ID: user-123'));
    expect(
      launchedUri?.queryParameters['body'],
      contains('Account email: member@example.com'),
    );
  });
}

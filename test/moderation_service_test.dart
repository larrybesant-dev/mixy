import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/models/moderation_model.dart';
import 'package:mixvy/services/moderation_service.dart';

void main() {
  group('ModerationService', () {
    test(
      'watchRecentReports returns reports ordered by createdAt descending',
      () async {
        final firestore = FakeFirebaseFirestore();

        await firestore.collection('reports').doc('r1').set({
          'id': 'r1',
          'reporterUserId': 'user-1',
          'targetId': 'room-1',
          'targetType': 'room',
          'reason': 'Spam room',
          'status': 'open',
          'createdAt': '2026-03-29T09:00:00.000Z',
        });
        await firestore.collection('reports').doc('r2').set({
          'id': 'r2',
          'reporterUserId': 'user-2',
          'targetId': 'user-3',
          'targetType': 'user',
          'reason': 'Abusive language',
          'status': 'open',
          'createdAt': '2026-03-29T10:00:00.000Z',
        });

        final service = ModerationService(firestore: firestore);
        final reports = await service.watchRecentReports().first;

        expect(reports, hasLength(2));
        expect(reports.first.id, 'r2');
        expect(reports.last.id, 'r1');
      },
    );

    test('updateReportStatus writes status and updatedAt', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('reports').doc('r10').set({
        'id': 'r10',
        'reporterUserId': 'user-1',
        'targetId': 'user-2',
        'targetType': 'user',
        'reason': 'Threats in chat',
        'status': 'open',
        'createdAt': '2026-03-29T09:00:00.000Z',
      });

      final service = ModerationService(firestore: firestore);
      await service.updateReportStatus(
        reportId: 'r10',
        status: ModerationStatus.reviewing,
      );

      final snapshot = await firestore.collection('reports').doc('r10').get();
      final data = snapshot.data()!;
      expect(data['status'], 'reviewing');
      expect(data['updatedAt'], isNotNull);
    });
  });
}

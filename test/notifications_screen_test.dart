import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/services/app_settings_service.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/presentation/providers/app_settings_provider.dart';
import 'package:mixvy/presentation/providers/notification_provider.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'package:mixvy/presentation/screens/notifications_screen.dart';

void main() {
  testWidgets(
    'NotificationsScreen shows current user notifications and settings banner',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('notifications').doc('n1').set({
        'userId': 'user-1',
        'type': 'payment',
        'content': 'Payment received',
        'isRead': false,
        'createdAt': DateTime(2026, 1, 1),
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationFirestoreProvider.overrideWithValue(firestore),
            appSettingsControllerProvider.overrideWith(
              (ref) =>
                  AppSettingsController(AppSettingsService())
                    ..state = const AsyncValue.data(
                      AppSettings(
                        themeMode: ThemeMode.system,
                        notificationsEnabled: false,
                        analyticsEnabled: true,
                        legalAccepted: true,
                        legalAcceptedVersion: AppSettings.currentLegalVersion,
                        legalAcceptedAt: null,
                        localeCode: 'en',
                      ),
                    ),
            ),
            userProvider.overrideWithValue(
              UserModel(
                id: 'user-1',
                email: 'user1@mixvy.dev',
                username: 'User One',
                createdAt: DateTime(2026, 1, 1),
              ),
            ),
          ],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Push notifications are disabled.'), findsOneWidget);
      expect(find.text('Payment received'), findsOneWidget);
      expect(find.byTooltip('Mark all as read'), findsOneWidget);
      expect(find.byTooltip('Notification settings'), findsOneWidget);
    },
  );
}

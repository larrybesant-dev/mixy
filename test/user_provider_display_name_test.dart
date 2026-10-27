import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'package:mixvy/router/app_router.dart';

void main() {
  group('getDisplayName', () {
    test('rejects a generated RTDB placeholder in favor of profile username',
        () {
      expect(
        getDisplayName(
          uid: 'EL9KnmDMZGhES8yNYThQdjg3ya03',
          resolvedDisplayName: 'Member EL9K',
          profileUsername: 'CURVE',
        ),
        'CURVE',
      );
    });

    test('keeps a non-placeholder RTDB display name as the priority', () {
      expect(
        getDisplayName(
          uid: 'EL9KnmDMZGhES8yNYThQdjg3ya03',
          resolvedDisplayName: 'Curve Live',
          profileUsername: 'CURVE',
        ),
        'Curve Live',
      );
    });
  });

  group('hasCoreUserIdentityChanged', () {
    UserModel user({required String username, String? avatarUrl}) => UserModel(
          id: 'user-1',
          email: '',
          username: username,
          avatarUrl: avatarUrl,
          createdAt: DateTime(2026, 1, 1),
        );

    test('detects a resolved username replacing a generated placeholder', () {
      expect(
        hasCoreUserIdentityChanged(
          user(username: 'Member USER'),
          user(username: 'CURVE'),
        ),
        isTrue,
      );
    });

    test('ignores unchanged core identity', () {
      expect(
        hasCoreUserIdentityChanged(
          user(username: 'CURVE', avatarUrl: 'https://example.test/a.jpg'),
          user(username: 'CURVE', avatarUrl: 'https://example.test/a.jpg'),
        ),
        isFalse,
      );
    });
  });
}

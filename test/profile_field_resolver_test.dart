import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/profile/profile_field_resolver.dart';

void main() {
  group('resolveProfileAvatarUrl', () {
    test('prefers avatarUrl when both fields are populated', () {
      expect(
        resolveProfileAvatarUrl(const {
          'avatarUrl': 'https://cdn.mixvy.test/avatar.jpg',
          'photoUrl': 'https://cdn.mixvy.test/legacy.jpg',
        }),
        'https://cdn.mixvy.test/avatar.jpg',
      );
    });

    test('falls back to photoUrl when avatarUrl is absent or empty', () {
      expect(
        resolveProfileAvatarUrl(const {
          'avatarUrl': '  ',
          'photoUrl': ' https://cdn.mixvy.test/google-avatar.jpg ',
        }),
        'https://cdn.mixvy.test/google-avatar.jpg',
      );
    });

    test('returns null when neither field is usable', () {
      expect(
        resolveProfileAvatarUrl(const {'avatarUrl': null, 'photoUrl': ''}),
        isNull,
      );
    });
  });
}
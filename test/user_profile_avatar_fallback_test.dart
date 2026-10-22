import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/models/user_profile.dart';

const _photo = 'https://lh3.googleusercontent.com/a/ACg8ocExample=s96-c';

void main() {
  group('UserProfile.fromJson avatar fallback', () {
    test('uses photoUrl when avatarUrl is an empty string', () {
      final profile = UserProfile.fromJson({
        'username': 'curve',
        'avatarUrl': '',
        'photoUrl': _photo,
      }, 'u1');

      expect(profile.avatarUrl, _photo);
    });

    test('uses photoUrl when avatarUrl is whitespace', () {
      final profile = UserProfile.fromJson({
        'username': 'curve',
        'avatarUrl': '   ',
        'photoUrl': _photo,
      }, 'u1');

      expect(profile.avatarUrl, _photo);
    });

    test('uses photoUrl when avatarUrl is missing', () {
      final profile = UserProfile.fromJson({
        'username': 'curve',
        'photoUrl': _photo,
      }, 'u1');

      expect(profile.avatarUrl, _photo);
    });

    test('prefers avatarUrl when it is set', () {
      const avatar = 'https://example.com/avatar.png';
      final profile = UserProfile.fromJson({
        'username': 'curve',
        'avatarUrl': avatar,
        'photoUrl': _photo,
      }, 'u1');

      expect(profile.avatarUrl, avatar);
    });

    test('is null when both avatar fields are empty', () {
      final profile = UserProfile.fromJson({
        'username': 'curve',
        'avatarUrl': '',
        'photoUrl': '  ',
      }, 'u1');

      expect(profile.avatarUrl, isNull);
    });
  });
}

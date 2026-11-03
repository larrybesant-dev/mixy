import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/utils/network_image_url.dart';
import 'package:mixvy/models/user_model.dart';

const _photo =
    'https://lh3.googleusercontent.com/a/ACg8ocExample=s96-c';

void main() {
  group('UserModel.fromJson avatar fallback', () {
    test('uses photoUrl when avatarUrl is an empty string', () {
      final user = UserModel.fromJson({
        'id': 'u1',
        'avatarUrl': '',
        'photoUrl': _photo,
      });

      expect(user.avatarUrl, sanitizeNetworkImageUrl(_photo));
    });

    test('uses photoUrl when avatarUrl is missing', () {
      final user = UserModel.fromJson({'id': 'u1', 'photoUrl': _photo});

      expect(user.avatarUrl, sanitizeNetworkImageUrl(_photo));
    });

    test('prefers avatarUrl when it is set', () {
      const avatar = 'https://example.com/avatar.png';
      final user = UserModel.fromJson({
        'id': 'u1',
        'avatarUrl': avatar,
        'photoUrl': _photo,
      });

      expect(user.avatarUrl, sanitizeNetworkImageUrl(avatar));
    });

    test('is null when both fields are empty', () {
      final user = UserModel.fromJson({
        'id': 'u1',
        'avatarUrl': '',
        'photoUrl': '  ',
      });

      expect(user.avatarUrl, isNull);
    });
  });
}

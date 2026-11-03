import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/utils/avatar_url_resolver.dart';

void main() {
  test('avatar resolver uses the first valid source', () {
    expect(
      resolveAvatarUrl(
        directAvatarUrl: 'not-a-url',
        persistedProfileAvatarUrl: 'https://example.com/profile.jpg',
        authPhotoUrl: 'https://example.com/auth.jpg',
      ),
      'https://example.com/profile.jpg',
    );
  });

  test('avatar resolver returns null when every source is invalid', () {
    expect(
      resolveAvatarUrl(
        directAvatarUrl: '',
        persistedProfileAvatarUrl: 'not-a-url',
      ),
      isNull,
    );
  });

  test('avatar resolver requests the preferred Google image size', () {
    expect(
      resolveAvatarUrl(
        directAvatarUrl: 'https://lh3.googleusercontent.com/avatar=s96-c',
        preferredSize: 256,
      ),
      'https://lh3.googleusercontent.com/avatar=s256-c',
    );
  });
}
